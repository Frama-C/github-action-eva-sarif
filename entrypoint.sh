#!/bin/bash -e

echo "Frama-C/Eva action entrypoint, displaying environment information"
echo "PWD=$PWD"

if [ $# -ne 3 ]; then
    echo "error: expected 3 arguments: fc-dir, fc-makefile and eva-target"
    exit 1
fi

fc_dir="$1"
fc_makefile="$2"
target="${3%.eva}"

if [ ! -f "$fc_dir/$fc_makefile" ]; then
    echo "error: file not found: $fc_dir/$fc_makefile"
    exit 1
fi

eval $(opam env)

echo "Parsing files: running target ${target}.parse"

# '-B' ensures that existing/versioned files will not prevent a rebuild
make -B -C "$fc_dir" -f "$fc_makefile" "${target}.parse"

echo "Running Eva: running target ${target}.eva"

make -C "$fc_dir" -f "$fc_makefile" "${target}.eva"

# output Eva summary
cd "$fc_dir"
summary=$(mktemp eva_summary_XXX.log)
sed -n -e '/====== ANALYSIS SUMMARY ======/,/\[metrics\] Eva coverage statistics/{/\[metrics\] Eva coverage statistics/!p}' "${target}.eva/eva.log" > $summary

alarm_count=$(wc -l "${target}.eva/alarms.csv" | cut -d' ' -f1)
coverage=$(grep "Coverage estimation" "${target}.eva/metrics.log" | cut -d'=' -f2)

echo "::set-output name=alarm-count::$alarm_count"
echo "::set-output name=coverage::$coverage"

# Produce SARIF report

frama-c -load "${target}.eva"/framac.sav -mdr-gen sarif -mdr-no-print-libc -mdr-out "${target}.sarif"
