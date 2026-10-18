#!/usr/bin/env bash
# Run every check from tests/grading.txt and print the result: PASS or FAIL.
# This is exactly what GitHub runs on every push.
#
# Usage: ./tests/grade.sh        (from the repository root)
#        ./tests/grade.sh -v     also show why checks failed
cd "$(dirname "$0")/.." || exit 1
verbose=0
[[ "$1" == "-v" || -n "$GITHUB_ACTIONS" ]] && verbose=1
total=0
failed=0
log="$(mktemp)"
while IFS='|' read -r id name cmd; do
    id="$(echo "$id" | xargs)"
    [[ -z "$id" || "$id" == \#* ]] && continue
    name="$(echo "$name" | xargs)"
    total=$((total + 1))
    if timeout 300 bash -c "$cmd" > "$log" 2>&1; then
        printf '  \033[32mPASS\033[0m  %s\n' "$name"
    else
        failed=$((failed + 1))
        printf '  \033[31mFAIL\033[0m  %s\n' "$name"
        if [[ $verbose -eq 1 ]]; then
            if grep -q "Sanitizer" "$log"; then
                # keep what matters from a sanitizer report: the error, the stack, the summary
                grep -E "FAIL|ERROR: |SUMMARY: |^ +#[0-9]+ .* in " "$log" \
                    | grep -vE "libasan|libubsan|/usr/lib|libc_start" | head -30 | sed 's/^/        /'
            else
                tail -25 "$log" | sed 's/^/        /'
            fi
        fi
    fi
done < tests/grading.txt
rm -f "$log"
echo "  ---------------------------"
if [[ $failed -eq 0 ]]; then
    result="PASS"
    echo "  Result: PASS (all $total checks passed)"
else
    result="FAIL"
    echo "  Result: FAIL ($failed of $total checks failed)"
fi

if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
    {
        if [[ $result == PASS ]]; then
            echo "## ✅ עבר"
        else
            echo "## ❌ לא עבר"
            echo
            echo "ניתן לצפות בהערות שלך כאן (יופיעו תוך כשעה): https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
            echo
            echo "בהצלחה!"
        fi
    } >> "$GITHUB_STEP_SUMMARY"
fi
if [[ -n "$GITHUB_ACTIONS" ]]; then
    # Read by the staff grades collector. Do not change this line.
    echo "::notice title=Result::$result"
fi
[[ $result == PASS ]]
