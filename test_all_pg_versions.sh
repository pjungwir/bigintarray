#!/bin/bash
#
# Build, install, and test bigintarray against PostgreSQL versions 10-18.
#
# Requires:
#   - sudo access (for make install)
#   - ~/bin/pg_config in PATH (uses PGCLUSTER envvar)
#   - pg_lsclusters to discover PGPORT
#   - All PG versions 10-18 installed
#
# Usage: ./test_all_pg_versions.sh [--only-build | --only-test]
#

set -e

ONLY_BUILD=false
ONLY_TEST=false
for arg in "$@"; do
    case "$arg" in
        --only-build) ONLY_BUILD=true ;;
        --only-test)  ONLY_TEST=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [ "$ONLY_BUILD" = true ] && [ "$ONLY_TEST" = true ]; then
    echo "Error: --only-build and --only-test are mutually exclusive" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

VERSIONS="10 11 12 13 14 15 16 17 18"

PASS=()
FAIL=()
SKIP=()

for ver in $VERSIONS; do
    echo "========================================"
    echo "PostgreSQL $ver"
    echo "========================================"

    # Check if this version is installed
    pgport=$(pg_lsclusters -h | awk -v v="$ver" '$1 == v { print $3 }')
    if [ -z "$pgport" ]; then
        echo "SKIP: PG $ver not found in pg_lsclusters"
        SKIP+=("$ver")
        continue
    fi

    # Check if the cluster is running
    pgstatus=$(pg_lsclusters -h | awk -v v="$ver" '$1 == v { print $4 }')
    if [ "$pgstatus" != "online" ]; then
        echo "SKIP: PG $ver cluster is not online (status: $pgstatus)"
        SKIP+=("$ver")
        continue
    fi

    PG_CONFIG=/usr/lib/postgresql/"$ver"/bin/pg_config

    if [ "$ONLY_TEST" = false ]; then
        echo "--- Clean ---"
        PG_CONFIG="$PG_CONFIG" make clean 2>&1 || true

        echo "--- Build ---"
        if ! PG_CONFIG="$PG_CONFIG" make 2>&1; then
            echo "FAIL: PG $ver build failed"
            FAIL+=("$ver")
            continue
        fi

        if [ "$ONLY_BUILD" = true ]; then
            echo "PASS: PG $ver (build only)"
            PASS+=("$ver")
            continue
        fi

        echo "--- Install (sudo) ---"
        if ! sudo PG_CONFIG="$PG_CONFIG" make install 2>&1; then
            echo "FAIL: PG $ver install failed"
            FAIL+=("$ver")
            continue
        fi
    fi

    echo "--- Test (PGPORT=$pgport) ---"
    # Drop the extension first in case a previous run left it
    psql -p "$pgport" -d postgres -c "DROP EXTENSION IF EXISTS bigintarray CASCADE" 2>/dev/null || true

    if PGCLUSTER="$ver" make installcheck PGPORT="$pgport" 2>&1; then
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
