/*-------------------------------------------------------------------------
 *
 * _bigint_selfuncs.c
 *	  Functions for selectivity estimation of bigintarray operators
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "_bigint.h"
#include "access/htup_details.h"
#include "catalog/pg_operator.h"
#include "catalog/pg_statistic.h"
#include "catalog/pg_type.h"
#include "catalog/namespace.h"
#include "miscadmin.h"
#include "utils/lsyscache.h"
#include "utils/selfuncs.h"

#if PG_VERSION_NUM >= 110000
#include "utils/fmgrprotos.h"
#else
/* PG10 doesn't have fmgrprotos.h; declare needed functions */
extern Datum arraycontsel(PG_FUNCTION_ARGS);
extern Datum arraycontjoinsel(PG_FUNCTION_ARGS);
#endif

PG_FUNCTION_INFO_V1(_bigint_overlap_sel);
PG_FUNCTION_INFO_V1(_bigint_contains_sel);
PG_FUNCTION_INFO_V1(_bigint_contained_sel);
PG_FUNCTION_INFO_V1(_bigint_overlap_joinsel);
PG_FUNCTION_INFO_V1(_bigint_contains_joinsel);
PG_FUNCTION_INFO_V1(_bigint_contained_joinsel);
PG_FUNCTION_INFO_V1(_bigint_matchsel);


static Selectivity int_query_opr_selec(ITEM *item, Datum *mcelems, float4 *mcefreqs,
									   int nmcelems, float4 minfreq);
static int	compare_val_int8(const void *a, const void *b);

/*
 * Wrappers around the default array selectivity estimation functions.
 */

Datum
_bigint_overlap_sel(PG_FUNCTION_ARGS)
{
	PG_RETURN_DATUM(DirectFunctionCall4(arraycontsel,
										PG_GETARG_DATUM(0),
										ObjectIdGetDatum(OID_ARRAY_OVERLAP_OP),
										PG_GETARG_DATUM(2),
										PG_GETARG_DATUM(3)));
}

Datum
_bigint_contains_sel(PG_FUNCTION_ARGS)
{
	PG_RETURN_DATUM(DirectFunctionCall4(arraycontsel,
										PG_GETARG_DATUM(0),
										ObjectIdGetDatum(OID_ARRAY_CONTAINS_OP),
										PG_GETARG_DATUM(2),
										PG_GETARG_DATUM(3)));
}

Datum
_bigint_contained_sel(PG_FUNCTION_ARGS)
{
	PG_RETURN_DATUM(DirectFunctionCall4(arraycontsel,
										PG_GETARG_DATUM(0),
										ObjectIdGetDatum(OID_ARRAY_CONTAINED_OP),
										PG_GETARG_DATUM(2),
										PG_GETARG_DATUM(3)));
}

Datum
_bigint_overlap_joinsel(PG_FUNCTION_ARGS)
{
	PG_RETURN_DATUM(DirectFunctionCall5(arraycontjoinsel,
										PG_GETARG_DATUM(0),
										ObjectIdGetDatum(OID_ARRAY_OVERLAP_OP),
										PG_GETARG_DATUM(2),
										PG_GETARG_DATUM(3),
										PG_GETARG_DATUM(4)));
}

Datum
_bigint_contains_joinsel(PG_FUNCTION_ARGS)
{
	PG_RETURN_DATUM(DirectFunctionCall5(arraycontjoinsel,
										PG_GETARG_DATUM(0),
										ObjectIdGetDatum(OID_ARRAY_CONTAINS_OP),
										PG_GETARG_DATUM(2),
										PG_GETARG_DATUM(3),
										PG_GETARG_DATUM(4)));
}

Datum
_bigint_contained_joinsel(PG_FUNCTION_ARGS)
{
	PG_RETURN_DATUM(DirectFunctionCall5(arraycontjoinsel,
										PG_GETARG_DATUM(0),
										ObjectIdGetDatum(OID_ARRAY_CONTAINED_OP),
										PG_GETARG_DATUM(2),
										PG_GETARG_DATUM(3),
										PG_GETARG_DATUM(4)));
}


/*
 * _bigint_matchsel -- restriction selectivity function for bigintarray @@ query_bigint
 */
Datum
_bigint_matchsel(PG_FUNCTION_ARGS)
{
	PlannerInfo *root = (PlannerInfo *) PG_GETARG_POINTER(0);

	List	   *args = (List *) PG_GETARG_POINTER(2);
	int			varRelid = PG_GETARG_INT32(3);
	VariableStatData vardata;
	Node	   *other;
	bool		varonleft;
	Selectivity selec;
	QUERYTYPE  *query;
	Datum	   *mcelems = NULL;
	float4	   *mcefreqs = NULL;
	int			nmcelems = 0;
	float4		minfreq = 0.0;
	float4		nullfrac = 0.0;
	AttStatsSlot sslot;

	/*
	 * If expression is not "variable @@ something" or "something @@ variable"
	 * then punt and return a default estimate.
	 */
	if (!get_restriction_variable(root, args, varRelid,
								  &vardata, &other, &varonleft))
		PG_RETURN_FLOAT8(DEFAULT_EQ_SEL);

	/*
	 * Variable should be bigint[].
	 */
	if (vardata.vartype != INT8ARRAYOID)
		PG_RETURN_FLOAT8(DEFAULT_EQ_SEL);

	/*
	 * Can't do anything useful if the something is not a constant, either.
	 */
	if (!IsA(other, Const))
	{
		ReleaseVariableStats(vardata);
		PG_RETURN_FLOAT8(DEFAULT_EQ_SEL);
	}

	/*
	 * The "@@" operator is strict, so we can cope with NULL right away.
	 */
	if (((Const *) other)->constisnull)
	{
		ReleaseVariableStats(vardata);
		PG_RETURN_FLOAT8(0.0);
	}

	/*
	 * Verify that the Const is a query_bigint type. Look it up by name
	 * for portability across PG versions.
	 */
	{
		Oid query_bigint_oid = TypenameGetTypid("query_bigint");
		if (!OidIsValid(query_bigint_oid) ||
			((Const *) other)->consttype != query_bigint_oid)
		{
			ReleaseVariableStats(vardata);
			PG_RETURN_FLOAT8(DEFAULT_EQ_SEL);
		}
	}

	query = DatumGetQueryTypeP(((Const *) other)->constvalue);

	/* Empty query matches nothing */
	if (query->size == 0)
	{
		ReleaseVariableStats(vardata);
		PG_RETURN_FLOAT8(0.0);
	}

	/*
	 * Get the statistics for the bigintarray column.
	 */
	if (HeapTupleIsValid(vardata.statsTuple))
	{
		Form_pg_statistic stats;

		stats = (Form_pg_statistic) GETSTRUCT(vardata.statsTuple);
		nullfrac = stats->stanullfrac;

		if (get_attstatsslot(&sslot, vardata.statsTuple,
							 STATISTIC_KIND_MCELEM, InvalidOid,
							 ATTSTATSSLOT_VALUES | ATTSTATSSLOT_NUMBERS))
		{
			/*
			 * There should be three more Numbers than Values, because the
			 * last three cells are taken for minimal, maximal and nulls
			 * frequency. Punt if not.
			 */
			if (sslot.nnumbers == sslot.nvalues + 3)
			{
				/* Grab the minimal MCE frequency. */
				minfreq = sslot.numbers[sslot.nvalues];

				mcelems = sslot.values;
				mcefreqs = sslot.numbers;
				nmcelems = sslot.nvalues;
			}
		}
	}
	else
		memset(&sslot, 0, sizeof(sslot));

	/* Process the logical expression in the query, using the stats */
	selec = int_query_opr_selec(GETQUERY(query) + query->size - 1,
								mcelems, mcefreqs, nmcelems, minfreq);

	/* MCE stats count only non-null rows, so adjust for null rows. */
	selec *= (1.0 - nullfrac);

	free_attstatsslot(&sslot);
	ReleaseVariableStats(vardata);

	CLAMP_PROBABILITY(selec);

	PG_RETURN_FLOAT8((float8) selec);
}

/*
 * Estimate selectivity of single intquery operator
 */
static Selectivity
int_query_opr_selec(ITEM *item, Datum *mcelems, float4 *mcefreqs,
					int nmcelems, float4 minfreq)
{
	Selectivity selec;

	/* since this function recurses, it could be driven to stack overflow */
	check_stack_depth();

	if (item->type == VAL)
	{
		Datum	   *searchres;

		if (mcelems == NULL)
			return (Selectivity) DEFAULT_EQ_SEL;

		searchres = (Datum *) bsearch(&item->val, mcelems, nmcelems,
									  sizeof(Datum), compare_val_int8);
		if (searchres)
		{
			/*
			 * The element is in MCELEM.  Return precise selectivity (or at
			 * least as precise as ANALYZE could find out).
			 */
			selec = mcefreqs[searchres - mcelems];
		}
		else
		{
			/*
			 * The element is not in MCELEM.  Estimate its frequency as half
			 * that of the least-frequent MCE.
			 */
			selec = Min(DEFAULT_EQ_SEL, minfreq / 2);
		}
	}
	else if (item->type == OPR)
	{
		/* Current query node is an operator */
		Selectivity s1,
					s2;

		s1 = int_query_opr_selec(item - 1, mcelems, mcefreqs, nmcelems,
								 minfreq);
		switch (item->val)
		{
			case (int64) '!':
				selec = 1.0 - s1;
				break;

			case (int64) '&':
				s2 = int_query_opr_selec(item + item->left, mcelems, mcefreqs,
										 nmcelems, minfreq);
				selec = s1 * s2;
				break;

			case (int64) '|':
				s2 = int_query_opr_selec(item + item->left, mcelems, mcefreqs,
										 nmcelems, minfreq);
				selec = s1 + s2 - s1 * s2;
				break;

			default:
				elog(ERROR, "unrecognized operator: %d", (int) item->val);
				selec = 0;		/* keep compiler quiet */
				break;
		}
	}
	else
	{
		elog(ERROR, "unrecognized int query item type: %u", item->type);
		selec = 0;				/* keep compiler quiet */
	}

	/* Clamp intermediate results to stay sane despite roundoff error */
	CLAMP_PROBABILITY(selec);

	return selec;
}

/*
 * Comparison function for binary search in mcelem array.
 */
static int
compare_val_int8(const void *a, const void *b)
{
	int64		key = *(const int64 *) a;
	int64		value = DatumGetInt64(*(const Datum *) b);

	if (key < value)
		return -1;
	else if (key > value)
		return 1;
	else
		return 0;
}
