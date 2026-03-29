CREATE EXTENSION bigintarray;

-- Check whether any of our opclasses fail amvalidate
SELECT amname, opcname
FROM pg_opclass opc LEFT JOIN pg_am am ON am.oid = opcmethod
WHERE opc.oid >= 16384 AND NOT amvalidate(opc.oid);

SELECT bigintset(1234);
SELECT icount('{1234234,234234}'::bigint[]);
SELECT sort('{1234234,-30,234234}'::bigint[]);
SELECT sort('{1234234,-30,234234}'::bigint[],'asc');
SELECT sort('{1234234,-30,234234}'::bigint[],'desc');
SELECT sort_asc('{1234234,-30,234234}'::bigint[]);
SELECT sort_desc('{1234234,-30,234234}'::bigint[]);
SELECT uniq('{1234234,-30,-30,234234,-30}'::bigint[]);
SELECT uniq(sort_asc('{1234234,-30,-30,234234,-30}'::bigint[]));
SELECT idx('{1234234,-30,-30,234234,-30}'::bigint[],-30::bigint);
SELECT subarray('{1234234,-30,-30,234234,-30}'::bigint[],2,3);
SELECT subarray('{1234234,-30,-30,234234,-30}'::bigint[],-1,1);
SELECT subarray('{1234234,-30,-30,234234,-30}'::bigint[],0,-1);

SELECT #'{1234234,234234}'::bigint[];
SELECT '{123,623,445}'::bigint[] + 1245::bigint;
SELECT '{123,623,445}'::bigint[] + 445::bigint;
SELECT '{123,623,445}'::bigint[] + '{1245,87,445}'::bigint[];
SELECT '{123,623,445}'::bigint[] - 623::bigint;
SELECT '{123,623,445}'::bigint[] - '{1623,623}'::bigint[];
SELECT '{123,623,445}'::bigint[] | 623::bigint;
SELECT '{123,623,445}'::bigint[] | 1623::bigint;
SELECT '{123,623,445}'::bigint[] | '{1623,623}'::bigint[];
SELECT '{123,623,445}'::bigint[] & '{1623,623}'::bigint[];
SELECT '{-1,3,1}'::bigint[] & '{1,2}'::bigint[];
SELECT '{1}'::bigint[] & '{2}'::bigint[];
SELECT array_dims('{1}'::bigint[] & '{2}'::bigint[]);
SELECT ('{1}'::bigint[] & '{2}'::bigint[]) = '{}'::bigint[];
SELECT ('{}'::bigint[] & '{}'::bigint[]) = '{}'::bigint[];

-- test with values larger than int4 range
SELECT bigintset(5000000000);
SELECT sort('{5000000000,-30,234234}'::bigint[]);
SELECT '{5000000000,623,445}'::bigint[] + 9999999999::bigint;
SELECT idx('{5000000000,-30,234234}'::bigint[], 5000000000::bigint);

--test query_bigint
SELECT '1'::query_bigint;
SELECT ' 1'::query_bigint;
SELECT '1 '::query_bigint;
SELECT ' 1 '::query_bigint;
SELECT ' ! 1 '::query_bigint;
SELECT '!1'::query_bigint;
SELECT '1|2'::query_bigint;
SELECT '1|!2'::query_bigint;
SELECT '!1|2'::query_bigint;
SELECT '!1|!2'::query_bigint;
SELECT '!(!1|!2)'::query_bigint;
SELECT '!(!1|2)'::query_bigint;
SELECT '!(1|!2)'::query_bigint;
SELECT '!(1|2)'::query_bigint;
SELECT '1&2'::query_bigint;
SELECT '!1&2'::query_bigint;
SELECT '1&!2'::query_bigint;
SELECT '!1&!2'::query_bigint;
SELECT '(1&2)'::query_bigint;
SELECT '1&(2)'::query_bigint;
SELECT '!(1)&2'::query_bigint;
SELECT '!(1&2)'::query_bigint;
SELECT '1|2&3'::query_bigint;
SELECT '1|(2&3)'::query_bigint;
SELECT '(1|2)&3'::query_bigint;
SELECT '1|2&!3'::query_bigint;
SELECT '1|!2&3'::query_bigint;
SELECT '!1|2&3'::query_bigint;
SELECT '!1|(2&3)'::query_bigint;
SELECT '!(1|2)&3'::query_bigint;
SELECT '(!1|2)&3'::query_bigint;
SELECT '1|(2|(4|(5|6)))'::query_bigint;
SELECT '1|2|4|5|6'::query_bigint;
SELECT '1&(2&(4&(5&6)))'::query_bigint;
SELECT '1&2&4&5&6'::query_bigint;
SELECT '1&(2&(4&(5|6)))'::query_bigint;
SELECT '1&(2&(4&(5|!6)))'::query_bigint;


CREATE TABLE test__int( a bigint[] );
\copy test__int from 'data/test__int.data'
ANALYZE test__int;

SELECT count(*) from test__int WHERE a && '{23,50}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '23|50';
SELECT count(*) from test__int WHERE a @> '{23,50}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '23&50';
SELECT count(*) from test__int WHERE a @> '{20,23}'::bigint[];
SELECT count(*) from test__int WHERE a <@ '{73,23,20}'::bigint[];
SELECT count(*) from test__int WHERE a = '{73,23,20}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '50&68';
SELECT count(*) from test__int WHERE a @> '{20,23}'::bigint[] or a @> '{50,68}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '(20&23)|(50&68)';
SELECT count(*) from test__int WHERE a @@ '20 | !21';
SELECT count(*) from test__int WHERE a @@ '!20 & !21';
SELECT count(*) from test__int WHERE a @@ '!2733 & (2738 | 254)';

SET enable_seqscan = off;  -- not all of these would use index by default

CREATE INDEX text_idx on test__int using gist ( a gist__bigint_ops );

SELECT count(*) from test__int WHERE a && '{23,50}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '23|50';
SELECT count(*) from test__int WHERE a @> '{23,50}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '23&50';
SELECT count(*) from test__int WHERE a @> '{20,23}'::bigint[];
SELECT count(*) from test__int WHERE a <@ '{73,23,20}'::bigint[];
SELECT count(*) from test__int WHERE a = '{73,23,20}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '50&68';
SELECT count(*) from test__int WHERE a @> '{20,23}'::bigint[] or a @> '{50,68}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '(20&23)|(50&68)';
SELECT count(*) from test__int WHERE a @@ '20 | !21';
SELECT count(*) from test__int WHERE a @@ '!20 & !21';
SELECT count(*) from test__int WHERE a @@ '!2733 & (2738 | 254)';

INSERT INTO test__int SELECT array(SELECT x::bigint FROM generate_series(1, 1001) x); -- should fail

DROP INDEX text_idx;
CREATE INDEX text_idx on test__int using gist ( a gist__bigintbig_ops );

SELECT count(*) from test__int WHERE a && '{23,50}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '23|50';
SELECT count(*) from test__int WHERE a @> '{23,50}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '23&50';
SELECT count(*) from test__int WHERE a @> '{20,23}'::bigint[];
SELECT count(*) from test__int WHERE a <@ '{73,23,20}'::bigint[];
SELECT count(*) from test__int WHERE a = '{73,23,20}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '50&68';
SELECT count(*) from test__int WHERE a @> '{20,23}'::bigint[] or a @> '{50,68}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '(20&23)|(50&68)';
SELECT count(*) from test__int WHERE a @@ '20 | !21';
SELECT count(*) from test__int WHERE a @@ '!20 & !21';
SELECT count(*) from test__int WHERE a @@ '!2733 & (2738 | 254)';

DROP INDEX text_idx;
CREATE INDEX text_idx on test__int using gin ( a gin__bigint_ops );

SELECT count(*) from test__int WHERE a && '{23,50}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '23|50';
SELECT count(*) from test__int WHERE a @> '{23,50}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '23&50';
SELECT count(*) from test__int WHERE a @> '{20,23}'::bigint[];
SELECT count(*) from test__int WHERE a <@ '{73,23,20}'::bigint[];
SELECT count(*) from test__int WHERE a = '{73,23,20}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '50&68';
SELECT count(*) from test__int WHERE a @> '{20,23}'::bigint[] or a @> '{50,68}'::bigint[];
SELECT count(*) from test__int WHERE a @@ '(20&23)|(50&68)';
SELECT count(*) from test__int WHERE a @@ '20 | !21';
SELECT count(*) from test__int WHERE a @@ '!20 & !21';
SELECT count(*) from test__int WHERE a @@ '!2733 & (2738 | 254)';

DROP INDEX text_idx;

RESET enable_seqscan;
