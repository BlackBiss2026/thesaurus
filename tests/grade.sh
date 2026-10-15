#!/usr/bin/env bash
# Run the same tests the GitHub autograder runs, and print your score.
# Usage: ./tests/grade.sh        (from the repository root)
cd "$(dirname "$0")/.." || exit 1
total=0
max=0
while IFS='|' read -r id name pts cmd; do
    id="$(echo "$id" | xargs)"
    [[ -z "$id" || "$id" == \#* ]] && continue
    name="$(echo "$name" | xargs)"
    pts="$(echo "$pts" | xargs)"
    max=$((max + pts))
    if timeout 120 bash -c "$cmd" > /tmp/grade_$$.log 2>&1; then
        total=$((total + pts))
        printf '  \033[32mPASS\033[0m %3d/%-3d %s\n' "$pts" "$pts" "$name"
    else
        printf '  \033[31mFAIL\033[0m %3d/%-3d %s\n' 0 "$pts" "$name"
        if [[ "$1" == "-v" ]]; then sed 's/^/        /' /tmp/grade_$$.log | tail -20; fi
    fi
done < tests/grading.txt
rm -f /tmp/grade_$$.log
echo "  ---------------------------"
echo "  Score: $total / $max   (run with -v to see failure details)"
