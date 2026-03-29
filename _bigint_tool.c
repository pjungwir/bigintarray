/*
 * bigintarray/_bigint_tool.c
 */
#include "postgres.h"

#include <limits.h>

#include "_bigint.h"
#include "catalog/pg_type.h"

/* arguments are assumed sorted & unique-ified */
bool
inner_int_contains(ArrayType *a, ArrayType *b)
{
	int			na,
				nb;
	int			i,
				j,
				n;
	int64	   *da,
			   *db;

	na = ARRNELEMS(a);
	nb = ARRNELEMS(b);
	da = ARRPTR(a);
	db = ARRPTR(b);

	i = j = n = 0;
	while (i < na && j < nb)
	{
		if (da[i] < db[j])
			i++;
		else if (da[i] == db[j])
		{
			n++;
			i++;
			j++;
		}
		else
			break;				/* db[j] is not in da */
	}

	return (n == nb);
}

/* arguments are assumed sorted */
bool
inner_int_overlap(ArrayType *a, ArrayType *b)
{
	int			na,
				nb;
	int			i,
				j;
	int64	   *da,
			   *db;

	na = ARRNELEMS(a);
	nb = ARRNELEMS(b);
	da = ARRPTR(a);
	db = ARRPTR(b);

	i = j = 0;
	while (i < na && j < nb)
	{
		if (da[i] < db[j])
			i++;
		else if (da[i] == db[j])
			return true;
		else
			j++;
	}

	return false;
}

ArrayType *
inner_int_union(ArrayType *a, ArrayType *b)
{
	ArrayType  *r = NULL;

	CHECKARRVALID(a);
	CHECKARRVALID(b);

	if (ARRISEMPTY(a) && ARRISEMPTY(b))
		return new_intArrayType(0);
	if (ARRISEMPTY(a))
		r = copy_intArrayType(b);
	if (ARRISEMPTY(b))
		r = copy_intArrayType(a);

	if (!r)
	{
		int			na = ARRNELEMS(a),
					nb = ARRNELEMS(b);
		int64	   *da = ARRPTR(a),
				   *db = ARRPTR(b);
		int			i,
					j;
		int64	   *dr;

		r = new_intArrayType(na + nb);
		dr = ARRPTR(r);

		/* union */
		i = j = 0;
		while (i < na && j < nb)
		{
			if (da[i] == db[j])
			{
				*dr++ = da[i++];
				j++;
			}
			else if (da[i] < db[j])
				*dr++ = da[i++];
			else
				*dr++ = db[j++];
		}

		while (i < na)
			*dr++ = da[i++];
		while (j < nb)
			*dr++ = db[j++];

		r = resize_intArrayType(r, dr - ARRPTR(r));
	}

	if (ARRNELEMS(r) > 1)
		r = _int_unique(r);

	return r;
}

ArrayType *
inner_int_inter(ArrayType *a, ArrayType *b)
{
	ArrayType  *r;
	int			na,
				nb;
	int64	   *da,
			   *db,
			   *dr;
	int			i,
				j,
				k;

	if (ARRISEMPTY(a) || ARRISEMPTY(b))
		return new_intArrayType(0);

	na = ARRNELEMS(a);
	nb = ARRNELEMS(b);
	da = ARRPTR(a);
	db = ARRPTR(b);
	r = new_intArrayType(Min(na, nb));
	dr = ARRPTR(r);

	i = j = k = 0;
	while (i < na && j < nb)
	{
		if (da[i] < db[j])
			i++;
		else if (da[i] == db[j])
		{
			if (k == 0 || dr[k - 1] != db[j])
				dr[k++] = db[j];
			i++;
			j++;
		}
		else
			j++;
	}

	if (k == 0)
	{
		pfree(r);
		return new_intArrayType(0);
	}
	else
		return resize_intArrayType(r, k);
}

void
rt__int_size(ArrayType *a, float *size)
{
	*size = (float) ARRNELEMS(a);
}

/* comparison function for isort() and _int_unique() */
static int
isort_cmp(const void *a, const void *b, void *arg)
{
	int64		aval = *((const int64 *) a);
	int64		bval = *((const int64 *) b);

	if (*((bool *) arg))
	{
		/* compare for ascending order */
		if (aval < bval)
			return -1;
		if (aval > bval)
			return 1;
	}
	else
	{
		if (aval > bval)
			return -1;
		if (aval < bval)
			return 1;
	}
	return 0;
}

/* Sort int64 array */
void
isort(int64 *a, size_t len, bool ascending)
{
	qsort_arg(a, len, sizeof(int64), isort_cmp, &ascending);
}

/* Create a new int8 array with room for "num" elements */
ArrayType *
new_intArrayType(int num)
{
	ArrayType  *r;
	int			nbytes;

	/* if no elements, return a zero-dimensional array */
	if (num <= 0)
	{
		Assert(num == 0);
		r = construct_empty_array(INT8OID);
		return r;
	}

	nbytes = ARR_OVERHEAD_NONULLS(1) + sizeof(int64) * num;

	r = (ArrayType *) palloc0(nbytes);

	SET_VARSIZE(r, nbytes);
	ARR_NDIM(r) = 1;
	r->dataoffset = 0;			/* marker for no null bitmap */
	ARR_ELEMTYPE(r) = INT8OID;
	ARR_DIMS(r)[0] = num;
	ARR_LBOUND(r)[0] = 1;

	return r;
}

ArrayType *
resize_intArrayType(ArrayType *a, int num)
{
	int			nbytes;
	int			i;

	/* if no elements, return a zero-dimensional array */
	if (num <= 0)
	{
		Assert(num == 0);
		a = construct_empty_array(INT8OID);
		return a;
	}

	if (num == ARRNELEMS(a))
		return a;

	nbytes = ARR_DATA_OFFSET(a) + sizeof(int64) * num;

	a = (ArrayType *) repalloc(a, nbytes);

	SET_VARSIZE(a, nbytes);
	/* usually the array should be 1-D already, but just in case ... */
	for (i = 0; i < ARR_NDIM(a); i++)
	{
		ARR_DIMS(a)[i] = num;
		num = 1;
	}
	return a;
}

ArrayType *
copy_intArrayType(ArrayType *a)
{
	ArrayType  *r;
	int			n = ARRNELEMS(a);

	r = new_intArrayType(n);
	memcpy(ARRPTR(r), ARRPTR(a), n * sizeof(int64));
	return r;
}

/* num for compressed key */
int
internal_size(int64 *a, int len)
{
	int			i;
	int64		size = 0;

	for (i = 0; i < len; i += 2)
	{
		if (!i || a[i] != a[i - 1]) /* do not count repeated range */
			size += (int64) (a[i + 1]) - (int64) (a[i]) + 1;
	}

	if (size > (int64) INT_MAX || size < (int64) INT_MIN)
		return -1;				/* overflow */
	return (int) size;
}

/* unique-ify elements of r in-place ... r must be sorted already */
ArrayType *
_int_unique(ArrayType *r)
{
	int			num = ARRNELEMS(r);
	int64	   *data = ARRPTR(r);
	int			i,
				j;

	if (num <= 1)
		return r;

	j = 0;
	for (i = 1; i < num; i++)
	{
		if (data[i] != data[j])
			data[++j] = data[i];
	}

	return resize_intArrayType(r, j + 1);
}

void
gensign(BITVECP sign, int64 *a, int len, int siglen)
{
	int			i;

	/* we assume that the sign vector is previously zeroed */
	for (i = 0; i < len; i++)
	{
		HASH(sign, *a, siglen);
		a++;
	}
}

int32
intarray_match_first(ArrayType *a, int64 elem)
{
	int64	   *aa;
	int32		c,
				i;

	CHECKARRVALID(a);
	c = ARRNELEMS(a);
	aa = ARRPTR(a);
	for (i = 0; i < c; i++)
		if (aa[i] == elem)
			return (i + 1);
	return 0;
}

ArrayType *
intarray_add_elem(ArrayType *a, int64 elem)
{
	ArrayType  *result;
	int64	   *r;
	int32		c;

	CHECKARRVALID(a);
	c = ARRNELEMS(a);
	result = new_intArrayType(c + 1);
	r = ARRPTR(result);
	if (c > 0)
		memcpy(r, ARRPTR(a), c * sizeof(int64));
	r[c] = elem;
	return result;
}

ArrayType *
intarray_concat_arrays(ArrayType *a, ArrayType *b)
{
	ArrayType  *result;
	int32		ac = ARRNELEMS(a);
	int32		bc = ARRNELEMS(b);

	CHECKARRVALID(a);
	CHECKARRVALID(b);
	result = new_intArrayType(ac + bc);
	if (ac)
		memcpy(ARRPTR(result), ARRPTR(a), ac * sizeof(int64));
	if (bc)
		memcpy(ARRPTR(result) + ac, ARRPTR(b), bc * sizeof(int64));
	return result;
}

ArrayType *
int_to_intset(int64 elem)
{
	ArrayType  *result;
	int64	   *aa;

	result = new_intArrayType(1);
	aa = ARRPTR(result);
	aa[0] = elem;
	return result;
}
