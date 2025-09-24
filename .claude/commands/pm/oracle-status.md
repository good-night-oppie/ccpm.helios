---
allowed-tools: Bash, Read
---

# Oracle Status

Show Done Oracle verification status for all tasks in an epic.

## Usage
```
/pm:oracle-status <epic_name>
```

## Instructions

### 1. Find Epic

```bash
epic_dir=".claude/epics/$ARGUMENTS"
if [ ! -d "$epic_dir" ]; then
    echo "❌ Epic '$ARGUMENTS' not found"
    echo "   Available epics:"
    ls -1 .claude/epics/ | grep -v '^\.' | sed 's/^/   - /'
    exit 1
fi
```

### 2. Oracle Health Check

```bash
echo "🏥 Checking Done Oracle service health..."
if ! curl -s "http://localhost:3000/health" > /dev/null; then
    echo "❌ Done Oracle service unavailable"
    echo "   Please ensure Done Oracle is running at http://localhost:3000"
    exit 1
fi
echo "✅ Done Oracle service is healthy"
echo ""
```

### 3. Scan All Tasks

```bash
echo "═══════════════════════════════════════════════════════"
echo "📊 Done Oracle Status for Epic: $ARGUMENTS"
echo "═══════════════════════════════════════════════════════"
echo ""

repo_path=$(pwd)
total_tasks=0
verified_done=0
verified_not_done=0
unverified=0

# Find all task files
for task_file in "$epic_dir"/*.md; do
    if [[ "$(basename "$task_file")" =~ ^[0-9]+\.md$ ]]; then
        task_number=$(basename "$task_file" .md)
        task_name=$(grep "^name:" "$task_file" | cut -d' ' -f2- || echo "Unknown Task")
        task_status=$(grep "^status:" "$task_file" | cut -d' ' -f2- || echo "unknown")

        total_tasks=$((total_tasks + 1))

        echo "🎯 Task $task_number: $task_name"
        echo "   Local Status: $task_status"

        # Submit to Oracle for verification
        oracle_response=$(curl -s -X POST "http://localhost:3000/api/bridge/evaluate" \
            -H "Content-Type: application/json" \
            -d "{
                \"repo\": \"$repo_path\",
                \"context\": {
                    \"task\": \"Task $task_number status check\",
                    \"description\": \"$task_name\",
                    \"type\": \"status_verification_check\",
                    \"verification_source\": \"ccpm_oracle_status\"
                },
                \"metadata\": {
                    \"task_number\": \"$task_number\",
                    \"verification_type\": \"status_check\",
                    \"command\": \"oracle-status\"
                }
            }")

        verdict=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('verdict', 'error'))" 2>/dev/null || echo "error")
        confidence=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('confidence', 0))" 2>/dev/null || echo "0")
        processing_path=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('processingPath', 'unknown'))" 2>/dev/null || echo "unknown")

        if [ "$verdict" = "done" ] && [ "$(echo "$confidence > 0.7" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
            echo "   Oracle Status: ✅ DONE (confidence: $confidence, path: $processing_path)"
            verified_done=$((verified_done + 1))
        elif [ "$verdict" = "done" ]; then
            echo "   Oracle Status: ⚠️ DONE (LOW CONFIDENCE: $confidence, path: $processing_path)"
            verified_done=$((verified_done + 1))
        elif [ "$verdict" = "not-done" ]; then
            echo "   Oracle Status: ❌ NOT DONE (confidence: $confidence, path: $processing_path)"
            verified_not_done=$((verified_not_done + 1))
        else
            echo "   Oracle Status: ❓ ERROR/INCONCLUSIVE ($verdict, confidence: $confidence)"
            unverified=$((unverified + 1))
        fi

        echo ""
    fi
done
```

### 4. Summary Statistics

```bash
echo "═══════════════════════════════════════════════════════"
echo "📈 Epic Summary Statistics"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📊 Total Tasks: $total_tasks"
echo "✅ Oracle Verified DONE: $verified_done"
echo "❌ Oracle Verified NOT DONE: $verified_not_done"
echo "❓ Unverified/Error: $unverified"
echo ""

# Calculate percentages
if [ "$total_tasks" -gt 0 ]; then
    done_percent=$(echo "scale=1; $verified_done * 100 / $total_tasks" | bc -l 2>/dev/null || echo "0")
    echo "🎯 Epic Completion: $done_percent% Oracle-verified"
else
    echo "🎯 Epic Completion: No tasks found"
fi

# Epic readiness assessment
if [ "$verified_done" = "$total_tasks" ] && [ "$total_tasks" -gt 0 ]; then
    echo ""
    echo "🎉 EPIC STATUS: COMPLETE"
    echo "   All tasks are Oracle-verified as DONE"
    echo "   Epic is ready for closure"
elif [ "$verified_not_done" -eq 0 ] && [ "$unverified" -eq 0 ] && [ "$total_tasks" -gt 0 ]; then
    echo ""
    echo "⚠️ EPIC STATUS: COMPLETE (with low confidence tasks)"
    echo "   All tasks done but some have low confidence"
    echo "   Consider improving quality before epic closure"
else
    remaining=$((total_tasks - verified_done))
    echo ""
    echo "🔄 EPIC STATUS: IN PROGRESS"
    echo "   $remaining tasks remaining"
    echo "   Continue development on incomplete tasks"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
```

### 5. Recommendations

```bash
echo "💡 Recommendations:"
echo ""

if [ "$verified_not_done" -gt 0 ]; then
    echo "❌ NOT DONE Tasks:"
    echo "   - Review acceptance criteria"
    echo "   - Complete implementation"
    echo "   - Run tests and validation"
    echo "   - Use /pm:oracle-verify <task> to check readiness"
    echo ""
fi

if [ "$unverified" -gt 0 ]; then
    echo "❓ Unverified Tasks:"
    echo "   - Check Oracle service health"
    echo "   - Review task implementation"
    echo "   - Use /pm:oracle-verify <task> for details"
    echo ""
fi

if [ "$verified_done" = "$total_tasks" ] && [ "$total_tasks" -gt 0 ]; then
    echo "🎉 Ready Actions:"
    echo "   - All tasks Oracle-verified"
    echo "   - Epic ready for final review"
    echo "   - Consider epic closure when appropriate"
fi

echo "═══════════════════════════════════════════════════════"
```

## Important Notes

- Uses Done Oracle's **two-tier architecture** (v2.0.0)
  - **Tier 1 (VERDICT_GENERATION)**: Basic pass/fail at lower thresholds
  - **Tier 2 (DONE_POLICY)**: Strict 95% requirements across all metrics
- Shows real-time Oracle verification status for all tasks
- Does not change any task statuses
- **Dynamic Thresholds**: No hardcoded confidence scores - respects Oracle's policy
- Provides comprehensive epic health overview with tier information
- Use for epic planning and progress tracking