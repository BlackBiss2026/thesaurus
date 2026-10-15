#!/usr/bin/env bash
# Usage: tests/run_tests.sh [--asan] [case-name ...]
#   no case names  -> run every case in tests/cases
#   case "errors"  -> check the error handling (exit codes)
cd "$(dirname "$0")/.." || exit 1
BIN=./build/thesaurus
if [[ "$1" == "--asan" ]]; then
    BIN=./build/thesaurus_asan
    export ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1
    shift
fi
cases=("$@")
if [[ ${#cases[@]} -eq 0 ]]; then
    for d in tests/cases/*/; do cases+=("$(basename "$d")"); done
    cases+=(errors)
fi
fail=0
for c in "${cases[@]}"; do
    if [[ "$c" == errors ]]; then
        ok=1
        "$BIN" > /dev/null 2>&1;                                         [[ $? -eq 1 ]] || { echo "  no arguments: expected exit code 1"; ok=0; }
        "$BIN" tests/cases/01_example/text.txt > /dev/null 2>&1;          [[ $? -eq 1 ]] || { echo "  one argument: expected exit code 1"; ok=0; }
        "$BIN" a b c > /dev/null 2>&1;                                    [[ $? -eq 1 ]] || { echo "  three arguments: expected exit code 1"; ok=0; }
        "$BIN" /nonexistent tests/cases/01_example/thesaurus.txt > /dev/null 2>&1; [[ $? -eq 1 ]] || { echo "  missing text file: expected exit code 1"; ok=0; }
        "$BIN" tests/cases/01_example/text.txt /nonexistent > /dev/null 2>&1;      [[ $? -eq 1 ]] || { echo "  missing thesaurus file: expected exit code 1"; ok=0; }
        out=$("$BIN" /nonexistent /nonexistent 2>/dev/null)
        [[ -z "$out" ]] || { echo "  error messages must go to stderr, not stdout"; ok=0; }
    else
        d="tests/cases/$c"
        [[ -d "$d" ]] || { echo "unknown case $c"; exit 2; }
        timeout 10 "$BIN" "$d/text.txt" "$d/thesaurus.txt" > build/out_$c.txt 2> build/err_$c.txt
        rc=$?
        ok=1
        if [[ $rc -eq 124 ]]; then echo "  timeout (more than 10 seconds)"; ok=0
        elif [[ $rc -ne 0 ]]; then echo "  exit code $rc (expected 0)"; sed 's/^/    /' build/err_$c.txt | head -20; ok=0
        elif ! cmp -s build/out_$c.txt "$d/expected.txt"; then
            echo "  output differs from $d/expected.txt:"
            diff <(head -c 2000 "$d/expected.txt") <(head -c 2000 build/out_$c.txt) | head -10 | sed 's/^/    /'
            ok=0
        fi
    fi
    if [[ $ok -eq 1 ]]; then echo "PASS $c"; else echo "FAIL $c"; fail=1; fi
done
exit $fail
