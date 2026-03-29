#!/bin/bash
#
# Build, install, and test bigintarray against PostgreSQL versions 10-18
# using pgenv-managed instances (no sudo required).
#
# Prerequisites:
#   1. Install pgenv:
#        git clone https://github.com/theory/pgenv.git ~/.pgenv
#        export PATH="$HOME/.pgenv/bin:$HOME/.pgenv/pgsql/bin:$PATH"
#
#   2. Build each major version (latest patch) with pgenv:
#        pgenv build 10.23
#        pgenv build 11.22
#        ...
#        pgenv build 18.3
#
#   The script discovers which versions are installed under ~/.pgenv/
#   and runs each one on port 15410-15418 (15400 + major version).
#
# Usage: ./test_all_pg_versions.sh [--only-build | --only-test] [--versions "16 17 18"]
#

set -e

ONLY_BUILD=false
ONLY_TEST=false
CUSTOM_VERSIONS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --only-build) ONLY_BUILD=true ;;
        --only-test)  ONLY_TEST=true ;;
        --versions)   shift; CUSTOM_VERSIONS="$1" ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

if [ "$ONLY_BUILD" = true ] && [ "$ONLY_TEST" = true ]; then
    echo "Error: --only-build and --only-test are mutually exclusive" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PGENV_ROOT="${PGENV_ROOT:-$HOME/.pgenv}"
export PATH="$PGENV_ROOT/bin:$PGENV_ROOT/pgsql/bin:$PATH"

VERSIONS="${CUSTOM_VERSIONS:-10 11 12 13 14 15 16 17 18}"
PORT_BASE=15400

PASS=()
FAIL=()
SKIP=()

# Find the installed pgenv version string for a given major version.
# Returns the latest patch version found (e.g. "18.3" for major 18).
find_pgenv_version() {
    local major="$1"
    local best=""
    for d in "$PGENV_ROOT"/pgsql-"${major}".*; do
        [ -d "$d" ] && best="${d##*/pgsql-}"
    done
    echo "$best"
}

# Clusters started by this script, for cleanup
STARTED_CLUSTERS=()

cleanup() {
    for datadir in "${STARTED_CLUSTERS[@]}"; do
        pg_ctl stop -D "$datadir" -m fast 2>/dev/null || true
    done
}
trap cleanup EXIT

for ver in $VERSIONS; do
    echo "========================================"
    echo "PostgreSQL $ver"
    echo "========================================"

    fullver=$(find_pgenv_version "$ver")
    if [ -z "$fullver" ]; then
        echo "SKIP: PG $ver not found under $PGENV_ROOT"
        SKIP+=("$ver")
        continue
    fi

    pgenv switch "$fullver"

    pgport=$((PORT_BASE + ver))
    datadir="$PGENV_ROOT/pgsql-$fullver/data-bigintarray-test"

    if [ "$ONLY_TEST" = false ]; then
        echo "--- Clean ---"
        make clean 2>&1 || true

        echo "--- Build ---"
        if ! make 2>&1; then
            echo "FAIL: PG $ver build failed"
            FAIL+=("$ver")
            continue
        fi

        if [ "$ONLY_BUILD" = true ]; then
            echo "PASS: PG $ver (build only)"
            PASS+=("$ver")
            continue
        fi

        echo "--- Install ---"
        if ! make install 2>&1; then
            echo "FAIL: PG $ver install failed"
            FAIL+=("$ver")
            continue
        fi
    fi

    # Ensure a running cluster for testing
    echo "--- Start cluster (port $pgport) ---"
    if ! [ -d "$datadir" ]; then
        initdb -D "$datadir" --no-locale -E UTF8 -A trust 2>&1
    fi

    if ! pg_ctl status -D "$datadir" >/dev/null 2>&1; then
        pg_ctl start -D "$datadir" -o "-p $pgport -k /tmp" -l "$datadir/logfile" -w 2>&1
        STARTED_CLUSTERS+=("$datadir")
    fi

    echo "--- Test (PGPORT=$pgport) ---"
    # Drop the extension first in case a previous run left it
    psql -p "$pgport" -h /tmp -d postgres -c "DROP EXTENSION IF EXISTS bigintarray CASCADE" 2>/dev/null || true

    if make installcheck PGPORT="$pgport" PGHOST=/tmp 2>&1; then
        echo "PASS: PG $ver"
        PASS+=("$ver")
    else
        echo "FAIL: PG $ver tests failed"
        echo "--- regression.diffs ---"
        cat regression.diffs 2>/dev/null || true
        FAIL+=("$ver")
    fi

    echo ""
done

echo "========================================"
echo "Summary"
echo "========================================"
echo "PASS: ${PASS[*]:-none}"
echo "FAIL: ${FAIL[*]:-none}"
echo "SKIP: ${SKIP[*]:-none}"

if [ ${#FAIL[@]} -gt 0 ]; then
    exit 1
fi
