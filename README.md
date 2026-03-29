# bigintarray

The `bigintarray` extension provides functions, operators, and index support for
one-dimensional arrays of bigints (`bigint[]`), following the same behavior as
PostgreSQL's built-in
[intarray](https://www.postgresql.org/docs/current/intarray.html) extension but
for `bigint` (8-byte integer) arrays instead of `integer` (4-byte integer)
arrays.

This extension is a direct port of `intarray` and aims to follow its behavior as
closely as possible. If you are familiar with `intarray`, you should find
`bigintarray` works the same way, just with `bigint` values.

## Installation

```
make
sudo make install
```

Then in your database:

```sql
CREATE EXTENSION bigintarray;
```

## Functions

| Function | Return Type | Description |
|---|---|---|
| `icount(bigint[])` | `int` | number of elements in array |
| `sort(bigint[], text dir)` | `bigint[]` | sort array — dir must be `asc` or `desc` |
| `sort(bigint[])` | `bigint[]` | sort in ascending order |
| `sort_asc(bigint[])` | `bigint[]` | sort in ascending order |
| `sort_desc(bigint[])` | `bigint[]` | sort in descending order |
| `uniq(bigint[])` | `bigint[]` | remove adjacent duplicates |
| `idx(bigint[], bigint item)` | `int` | index of first element matching item, or 0 if no match |
| `subarray(bigint[], int start, int len)` | `bigint[]` | portion of array starting at position start, len elements |
| `subarray(bigint[], int start)` | `bigint[]` | portion of array starting at position start |
| `bigintset(bigint)` | `bigint[]` | make single-element array |

## Operators

| Operator | Description |
|---|---|
| `bigint[] && bigint[]` | overlap — true if arrays have at least one common element |
| `bigint[] @> bigint[]` | contains — true if left array contains right array |
| `bigint[] <@ bigint[]` | contained — true if left array is contained in right array |
| `# bigint[]` | number of elements in array |
| `bigint[] # bigint` | index of first occurrence of right argument in array, 0 if absent |
| `bigint[] + bigint` | push element onto end of array |
| `bigint[] + bigint[]` | array concatenation |
| `bigint[] - bigint` | remove entries matching right argument from array |
| `bigint[] - bigint[]` | remove elements of right array from left |
| `bigint[] \| bigint` | union of arguments |
| `bigint[] \| bigint[]` | union of arrays |
| `bigint[] & bigint[]` | intersection of arrays |
| `bigint[] @@ query_bigint` | true if array satisfies query (see below) |
| `query_bigint ~~ bigint[]` | true if array satisfies query (commutator of `@@`) |

## Searching Arrays

The `query_bigint` type allows complex boolean queries on arrays. Each value in
the query refers to an array element. The query supports `&` (AND), `|` (OR),
and `!` (NOT) with parentheses for grouping.

Examples:

```sql
-- Does the array contain both 1 and 2?
SELECT '{1,2,3}'::bigint[] @@ '1&2'::query_bigint;  -- true

-- Does the array contain 1 or 3?
SELECT '{1,2,3}'::bigint[] @@ '1|3'::query_bigint;  -- true

-- Does the array contain 1 and not 5?
SELECT '{1,2,3}'::bigint[] @@ '1&!5'::query_bigint;  -- true
```

## Index Support

`bigintarray` provides GiST and GIN index support for the `&&`, `@>`, `<@`,
`=`, and `@@` operators.

### GiST Indexes

Two GiST operator classes are provided:

- `gist__bigint_ops` (default) — indexes arrays as sorted sets of ranges. Best
  for small to medium arrays. Supports a `numranges` option (default 100) to
  control compression.
- `gist__bigintbig_ops` — indexes arrays as bit signatures. Better for larger
  arrays or very sparse data. Supports a `siglen` option (default 252 bytes) to
  control signature size.

```sql
CREATE INDEX ON mytable USING gist (arr_column gist__bigint_ops);
CREATE INDEX ON mytable USING gist (arr_column gist__bigintbig_ops);
```

### GIN Indexes

One GIN operator class is provided:

- `gin__bigint_ops` — generally faster than GiST for searching, but slower to
  build and update.

```sql
CREATE INDEX ON mytable USING gin (arr_column gin__bigint_ops);
```

## Compatibility

This extension supports PostgreSQL versions 10 through 18. The `numranges` and
`siglen` opclass options require PostgreSQL 13 or later.

## Author

Paul A. Jungwirth <pj@illuminatedcomputing.com>

## Acknowledgments

This extension is a direct port of PostgreSQL's
[intarray](https://www.postgresql.org/docs/current/intarray.html) contrib module.
All credit for the algorithms and design goes to the original intarray authors
and the PostgreSQL Global Development Group.
