#!/bin/bash

# Get the directory where this script is located.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for the "single" or "partitioned" parameter.
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [single|partitioned]"
    exit 1
fi
if [ "$1" == "single" ] || [ "$1" == "partitioned" ]; then
    FLAVOR=$1
    echo "Running benchmark for $FLAVOR"
else
    echo "Invalid argument. Please use 'single' or 'partitioned'."
    exit 1
fi

# Clear the results file before we write to it.
touch "$SCRIPT_DIR/results.csv"
> "$SCRIPT_DIR/results.csv"

TRIES=3
OS=$(uname -s)

for query_num in $(seq 0 42); do
    sync

    if [ "$OS" = "Linux" ]; then
        echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
    elif [ "$OS" = "Darwin" ]; then
        sudo purge
    fi

    echo -n "["

    for i in $(seq 1 $TRIES); do
        # Parse query results out of the JSON output, which reports the time in nanoseconds.
        RES=$(RUST_LOG=off ./target/release/datafusion-bench clickbench \
            -i 1 \
            --opt flavor=$FLAVOR \
            --formats vortex \
            -d gh-json \
            -q $query_num \
            --hide-progress-bar | jq ".value / 1000000000")

        [[ $RES != "" ]] && \
            echo -n "$RES" || \
            echo -n "null"
        [[ "$i" != $TRIES ]] && echo -n ", "
        echo "${query_num},${i},${RES}" >> "$SCRIPT_DIR/results.csv"
    done

    echo "],"
done
