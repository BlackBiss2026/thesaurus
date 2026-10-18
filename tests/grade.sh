#!/usr/bin/env bash
# Run every test from tests/grading.txt and print your score.
# This is exactly what GitHub runs on every push.
#
# Usage: ./tests/grade.sh        (from the repository root)
#        ./tests/grade.sh -v     also show why tests failed
cd "$(dirname "$0")/.." || exit 1
verbose=0
[[ "$1" == "-v" || -n "$GITHUB_ACTIONS" ]] && verbose=1
total=0
max=0
rows=""
log="$(mktemp)"
while IFS='|' read -r id name pts cmd; do
    id="$(echo "$id" | xargs)"
    [[ -z "$id" || "$id" == \#* ]] && continue
    name="$(echo "$name" | xargs)"
    pts="$(echo "$pts" | xargs)"
    max=$((max + pts))
    if timeout 300 bash -c "$cmd" > "$log" 2>&1; then
        total=$((total + pts))
        printf '  \033[32mPASS\033[0m %3d/%-3d %s\n' "$pts" "$pts" "$name"
        rows+="| ✅ | $name | $pts/$pts |"$'\n'
    else
        printf '  \033[31mFAIL\033[0m %3d/%-3d %s\n' 0 "$pts" "$name"
        if [[ $verbose -eq 1 ]]; then
            if grep -q "Sanitizer" "$log"; then
                # keep what matters from a sanitizer report: the error, the stack, the summary
                grep -E "FAIL|ERROR: |SUMMARY: |^ +#[0-9]+ .* in " "$log" \
                    | grep -vE "libasan|libubsan|/usr/lib|libc_start" | head -30 | sed 's/^/        /'
            else
                tail -25 "$log" | sed 's/^/        /'
            fi
        fi
        rows+="| ❌ | $name | 0/$pts |"$'\n'
    fi
done < tests/grading.txt
rm -f "$log"
echo "  ---------------------------"
echo "  Score: $total / $max"

if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
    {
        echo "## Score: $total / $max"
        echo
        echo "| | Test | Points |"
        echo "|---|---|---|"
        printf '%s' "$rows"
    } >> "$GITHUB_STEP_SUMMARY"
fi
if [[ -n "$GITHUB_ACTIONS" ]]; then
    # Read by the staff grades collector. Do not change this line.
    echo "::notice title=Score::$total/$max"
fi
[[ $total -eq $max ]]
