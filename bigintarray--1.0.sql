/* bigintarray/bigintarray--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION bigintarray" to load this file. \quit

--
-- Create the user-defined type for the 1-D bigint arrays (_int8)
--

-- Query type
CREATE FUNCTION bqarr_in(cstring)
RETURNS query_bigint
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION bqarr_out(query_bigint)
RETURNS cstring
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE TYPE query_bigint (
	INTERNALLENGTH = -1,
	INPUT = bqarr_in,
	OUTPUT = bqarr_out
);

--only for debug
CREATE FUNCTION querytree(query_bigint)
RETURNS text
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;


CREATE FUNCTION boolop(_int8, query_bigint)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION boolop(_int8, query_bigint) IS 'boolean operation with array';

CREATE FUNCTION rboolop(query_bigint, _int8)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION rboolop(query_bigint, _int8) IS 'boolean operation with array';

CREATE FUNCTION _bigint_matchsel(internal, oid, internal, integer)
RETURNS float8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE PARALLEL SAFE;

CREATE OPERATOR @@ (
	LEFTARG = _int8,
	RIGHTARG = query_bigint,
	PROCEDURE = boolop,
	COMMUTATOR = '~~',
	RESTRICT = _bigint_matchsel,
	JOIN = contjoinsel
);

CREATE OPERATOR ~~ (
	LEFTARG = query_bigint,
	RIGHTARG = _int8,
	PROCEDURE = rboolop,
	COMMUTATOR = '@@',
	RESTRICT = _bigint_matchsel,
	JOIN = contjoinsel
);


--
-- External C-functions for R-tree methods
--

-- Comparison methods

CREATE FUNCTION _bigint_contains(_int8, _int8)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION _bigint_contains(_int8, _int8) IS 'contains';

CREATE FUNCTION _bigint_contained(_int8, _int8)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION _bigint_contained(_int8, _int8) IS 'contained in';

CREATE FUNCTION _bigint_overlap(_int8, _int8)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION _bigint_overlap(_int8, _int8) IS 'overlaps';

CREATE FUNCTION _bigint_same(_int8, _int8)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION _bigint_same(_int8, _int8) IS 'same as';

CREATE FUNCTION _bigint_different(_int8, _int8)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION _bigint_different(_int8, _int8) IS 'different';

-- support routines for indexing

CREATE FUNCTION _bigint_union(_int8, _int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION _bigint_inter(_int8, _int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION _bigint_overlap_sel(internal, oid, internal, integer)
RETURNS float8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE PARALLEL SAFE;

CREATE FUNCTION _bigint_contains_sel(internal, oid, internal, integer)
RETURNS float8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE PARALLEL SAFE;

CREATE FUNCTION _bigint_contained_sel(internal, oid, internal, integer)
RETURNS float8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE PARALLEL SAFE;

CREATE FUNCTION _bigint_overlap_joinsel(internal, oid, internal, smallint, internal)
RETURNS float8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE PARALLEL SAFE;

CREATE FUNCTION _bigint_contains_joinsel(internal, oid, internal, smallint, internal)
RETURNS float8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE PARALLEL SAFE;

CREATE FUNCTION _bigint_contained_joinsel(internal, oid, internal, smallint, internal)
RETURNS float8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE PARALLEL SAFE;

--
-- OPERATORS
--

CREATE OPERATOR && (
	LEFTARG = _int8,
	RIGHTARG = _int8,
	PROCEDURE = _bigint_overlap,
	COMMUTATOR = '&&',
	RESTRICT = _bigint_overlap_sel,
	JOIN = _bigint_overlap_joinsel
);

CREATE OPERATOR @> (
	LEFTARG = _int8,
	RIGHTARG = _int8,
	PROCEDURE = _bigint_contains,
	COMMUTATOR = '<@',
	RESTRICT = _bigint_contains_sel,
	JOIN = _bigint_contains_joinsel
);

CREATE OPERATOR <@ (
	LEFTARG = _int8,
	RIGHTARG = _int8,
	PROCEDURE = _bigint_contained,
	COMMUTATOR = '@>',
	RESTRICT = _bigint_contained_sel,
	JOIN = _bigint_contained_joinsel
);

--------------
CREATE FUNCTION bigintset(int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION icount(_int8)
RETURNS int4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE OPERATOR # (
	RIGHTARG = _int8,
	PROCEDURE = icount
);

CREATE FUNCTION sort(_int8, text)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION sort(_int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION sort_asc(_int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION sort_desc(_int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION uniq(_int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION idx(_int8, int8)
RETURNS int4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE OPERATOR # (
	LEFTARG = _int8,
	RIGHTARG = int8,
	PROCEDURE = idx
);

CREATE FUNCTION subarray(_int8, int4, int4)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION subarray(_int8, int4)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION bigintarray_push_elem(_int8, int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE OPERATOR + (
	LEFTARG = _int8,
	RIGHTARG = int8,
	PROCEDURE = bigintarray_push_elem
);

CREATE FUNCTION bigintarray_push_array(_int8, _int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE OPERATOR + (
	LEFTARG = _int8,
	RIGHTARG = _int8,
	COMMUTATOR = +,
	PROCEDURE = bigintarray_push_array
);

CREATE FUNCTION bigintarray_del_elem(_int8, int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE OPERATOR - (
	LEFTARG = _int8,
	RIGHTARG = int8,
	PROCEDURE = bigintarray_del_elem
);

CREATE FUNCTION bigintset_union_elem(_int8, int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE OPERATOR | (
	LEFTARG = _int8,
	RIGHTARG = int8,
	PROCEDURE = bigintset_union_elem
);

CREATE OPERATOR | (
	LEFTARG = _int8,
	RIGHTARG = _int8,
	COMMUTATOR = |,
	PROCEDURE = _bigint_union
);

CREATE FUNCTION bigintset_subtract(_int8, _int8)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE OPERATOR - (
	LEFTARG = _int8,
	RIGHTARG = _int8,
	PROCEDURE = bigintset_subtract
);

CREATE OPERATOR & (
	LEFTARG = _int8,
	RIGHTARG = _int8,
	COMMUTATOR = &,
	PROCEDURE = _bigint_inter
);
--------------

-- define the GiST support methods
CREATE FUNCTION g_bigint_consistent(internal,_int8,smallint,oid,internal)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigint_compress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigint_decompress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigint_penalty(internal,internal,internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigint_picksplit(internal, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigint_union(internal, internal)
RETURNS _int8
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigint_same(_int8, _int8, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;


-- Create the operator class for indexing

CREATE OPERATOR CLASS gist__bigint_ops
DEFAULT FOR TYPE _int8 USING gist AS
	OPERATOR	3	&&,
	OPERATOR	6	= (anyarray, anyarray),
	OPERATOR	7	@>,
	OPERATOR	20	@@ (_int8, query_bigint),
	FUNCTION	1	g_bigint_consistent (internal, _int8, smallint, oid, internal),
	FUNCTION	2	g_bigint_union (internal, internal),
	FUNCTION	3	g_bigint_compress (internal),
	FUNCTION	4	g_bigint_decompress (internal),
	FUNCTION	5	g_bigint_penalty (internal, internal, internal),
	FUNCTION	6	g_bigint_picksplit (internal, internal),
	FUNCTION	7	g_bigint_same (_int8, _int8, internal);


---------------------------------------------
-- bigintbig
---------------------------------------------
-- define the GiST support methods

CREATE FUNCTION _bigintbig_in(cstring)
RETURNS bigintbig_gkey
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION _bigintbig_out(bigintbig_gkey)
RETURNS cstring
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE TYPE bigintbig_gkey (
        INTERNALLENGTH = -1,
        INPUT = _bigintbig_in,
        OUTPUT = _bigintbig_out
);

CREATE FUNCTION g_bigintbig_consistent(internal,_int8,smallint,oid,internal)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigintbig_compress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigintbig_decompress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigintbig_penalty(internal,internal,internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigintbig_picksplit(internal, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigintbig_union(internal, internal)
RETURNS bigintbig_gkey
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION g_bigintbig_same(bigintbig_gkey, bigintbig_gkey, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

-- register the opclass for indexing (not as default)

CREATE OPERATOR CLASS gist__bigintbig_ops
FOR TYPE _int8 USING gist
AS
	OPERATOR	3	&&,
	OPERATOR	6	= (anyarray, anyarray),
	OPERATOR	7	@>,
	OPERATOR	20	@@ (_int8, query_bigint),
	FUNCTION	1	g_bigintbig_consistent (internal, _int8, smallint, oid, internal),
	FUNCTION	2	g_bigintbig_union (internal, internal),
	FUNCTION	3	g_bigintbig_compress (internal),
	FUNCTION	4	g_bigintbig_decompress (internal),
	FUNCTION	5	g_bigintbig_penalty (internal, internal, internal),
	FUNCTION	6	g_bigintbig_picksplit (internal, internal),
	FUNCTION	7	g_bigintbig_same (bigintbig_gkey, bigintbig_gkey, internal),
	STORAGE		bigintbig_gkey;

--GIN

CREATE FUNCTION ginint8_queryextract(_int8, internal, int2, internal, internal, internal, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION ginint8_consistent(internal, int2, _int8, int4, internal, internal, internal, internal)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR CLASS gin__bigint_ops
FOR TYPE _int8 USING gin
AS
	OPERATOR	3	&&,
	OPERATOR	6	= (anyarray, anyarray),
	OPERATOR	7	@>,
	OPERATOR	8	<@,
	OPERATOR	20	@@ (_int8, query_bigint),
	FUNCTION	1	btint8cmp (int8, int8),
	FUNCTION	2	ginarrayextract (anyarray, internal, internal),
	FUNCTION	3	ginint8_queryextract (_int8, internal, int2, internal, internal, internal, internal),
	FUNCTION	4	ginint8_consistent (internal, int2, _int8, int4, internal, internal, internal, internal),
	STORAGE		int8;

-- Conditionally add opclass options if PG >= 13
DO $d$
DECLARE
	modpath text;
BEGIN
	IF current_setting('server_version_num')::integer >= 130000 THEN
		SELECT probin INTO modpath FROM pg_proc
			WHERE proname = '_bigint_contains' LIMIT 1;

		EXECUTE format($e$
			CREATE FUNCTION g_bigint_options(internal)
			RETURNS void
			AS %L, 'g_bigint_options'
			LANGUAGE C IMMUTABLE PARALLEL SAFE
		$e$, modpath);

		EXECUTE format($e$
			CREATE FUNCTION g_bigintbig_options(internal)
			RETURNS void
			AS %L, 'g_bigintbig_options'
			LANGUAGE C IMMUTABLE PARALLEL SAFE
		$e$, modpath);

		EXECUTE $e$
			ALTER OPERATOR FAMILY gist__bigint_ops USING gist
			ADD FUNCTION 10 (_int8) g_bigint_options (internal)
		$e$;

		EXECUTE $e$
			ALTER OPERATOR FAMILY gist__bigintbig_ops USING gist
			ADD FUNCTION 10 (_int8) g_bigintbig_options (internal)
		$e$;
	END IF;
END $d$;
