#!/usr/bin/env bash
# Usage: tests/run_tests.sh [--asan] [case-name ...]
#   no case names  -> run every case in tests/cases
#   case "errors"  -> check the error handling (exit codes)
cd "$(dirname "$0")/.." || exit 1
BIN=./build/thesaurus
if [[ "$1" == "--asan" ]]; then
    # Memory check only: a case fails only if AddressSanitizer / UBSan reports
    # an error (exit code 99). Wrong output is already graded by the other tests.
    MEMONLY=1
    export ASAN_OPTIONS=detect_leaks=1:exitcode=99 UBSAN_OPTIONS=halt_on_error=1:exitcode=99
    mkdir -p build
    cat > build/asan_wrap.sh <<WRAP
#!/usr/bin/env bash
"$(pwd)/build/thesaurus_asan" "\$@" 2> >(tee -a build/stderr_all.txt >&2)
rc=\$?
[[ \$rc -eq 99 ]] && touch build/.sanitizer_error
exit \$rc
WRAP
    chmod +x build/asan_wrap.sh
    BIN=./build/asan_wrap.sh
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
    if [[ -n "$MEMONLY" ]]; then
        if [[ -f build/.sanitizer_error ]]; then
            ok=0
            echo "  memory error:"
            grep -E "ERROR: |SUMMARY: |runtime error|^ +#[0-9]+ " build/stderr_all.txt | head -20 | sed 's/^/    /'
        else
            ok=1
        fi
        rm -f build/.sanitizer_error build/stderr_all.txt
    fi
    if [[ $ok -eq 1 ]]; then echo "PASS $c"; else echo "FAIL $c"; fail=1; fi
done
exit $fail
