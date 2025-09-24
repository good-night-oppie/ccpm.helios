---
allowed-tools: Bash, Read
---

# Oracle Verify

Manually verify task completion with Done Oracle without closing the task.

## Usage
```
/pm:oracle-verify <issue_number>
```

## Instructions

### 1. Find Local Task File

First check if `.claude/epics/*/$ARGUMENTS.md` exists.
If not found: "❌ No local task for issue #$ARGUMENTS"

### 2. Oracle Health Check

```bash
echo "🏥 Checking Done Oracle service health..."
if ! curl -s "http://localhost:3000/health" > /dev/null; then
    echo "❌ Done Oracle service unavailable"
    echo "   Please ensure Done Oracle is running at http://localhost:3000"
    exit 1
fi
echo "✅ Done Oracle service is healthy"
```

### 3. Submit for Oracle Verification

```bash
# Get task details
task_file=$(find .claude/epics -name "$ARGUMENTS.md" | head -1)
task_description=$(grep "^name:" "$task_file" | cut -d' ' -f2- || echo "Task $ARGUMENTS")
repo_path=$(pwd)

echo "🔍 Submitting Task $ARGUMENTS for Oracle verification..."

# Submit to Done Oracle Bridge API
oracle_response=$(curl -s -X POST "http://localhost:3000/api/bridge/evaluate" \
    -H "Content-Type: application/json" \
    -d "{
        \"repo\": \"$repo_path\",
        \"context\": {
            \"task\": \"Task $ARGUMENTS manual verification\",
            \"description\": \"$task_description\",
            \"type\": \"manual_verification_check\",
            \"verification_source\": \"ccpm_oracle_verify\"
        },
        \"metadata\": {
            \"task_number\": \"$ARGUMENTS\",
            \"verification_type\": \"manual_check\",
            \"command\": \"oracle-verify\"
        }
    }")

# Parse Oracle response
verdict=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('verdict', 'error'))" 2>/dev/null || echo "error")
confidence=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('confidence', 0))" 2>/dev/null || echo "0")
reasoning=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('reasoning', 'No reasoning provided'))" 2>/dev/null || echo "No reasoning provided")
processing_path=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('processingPath', 'unknown'))" 2>/dev/null || echo "unknown")
complexity=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('complexity', 0))" 2>/dev/null || echo "0")
```

### 4. Display Results

```bash
echo ""
echo "═══════════════════════════════════════════════════════"
echo "📋 Done Oracle Verification Results for Task $ARGUMENTS"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "🎯 Verdict: $verdict"
echo "📊 Confidence: $confidence"
echo "🧠 Processing Path: $processing_path"
echo "⚖️ Complexity Score: $complexity"
echo ""
echo "💭 Oracle Reasoning:"
echo "$reasoning"
echo ""

if [ "$verdict" = "done" ] && [ "$(echo "$confidence > 0.7" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
    echo "✅ ORACLE VERDICT: TASK COMPLETE"
    echo "   Task $ARGUMENTS meets Done Oracle completion standards"
    echo "   Ready for closure with: /pm:issue-close $ARGUMENTS"
elif [ "$verdict" = "done" ]; then
    echo "⚠️ ORACLE VERDICT: LOW CONFIDENCE"
    echo "   Task appears complete but confidence is low ($confidence)"
    echo "   Consider improving implementation quality before closure"
elif [ "$verdict" = "not-done" ]; then
    echo "❌ ORACLE VERDICT: NOT COMPLETE"
    echo "   Task $ARGUMENTS does not meet completion standards"
    echo "   Review and address Oracle feedback before closure"
else
    echo "❓ ORACLE VERDICT: INCONCLUSIVE"
    echo "   Unable to determine completion status"
    echo "   Check implementation and try again"
fi
```

### 5. Save Verification Record

```bash
# Save verification to task updates
epic_name=$(dirname "$(find .claude/epics -name "$ARGUMENTS.md" | head -1)" | xargs basename)
updates_dir=".claude/epics/$epic_name/updates/$ARGUMENTS"
mkdir -p "$updates_dir"

verification_file="$updates_dir/oracle-verification-$(date +%Y%m%d-%H%M%S).json"

echo "{
  \"task\": \"$ARGUMENTS\",
  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
  \"verdict\": \"$verdict\",
  \"confidence\": $confidence,
  \"reasoning\": \"$reasoning\",
  \"processing_path\": \"$processing_path\",
  \"complexity\": $complexity,
  \"verification_type\": \"manual\",
  \"command\": \"oracle-verify\"
}" > "$verification_file"

echo ""
echo "📁 Verification record saved: $verification_file"
```

### 6. Output Summary

```bash
echo ""
echo "═══════════════════════════════════════════════════════"
if [ "$verdict" = "done" ] && [ "$(echo "$confidence > 0.7" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
    echo "✅ Task $ARGUMENTS: READY FOR CLOSURE"
    echo "   Use: /pm:issue-close $ARGUMENTS"
else
    echo "🔄 Task $ARGUMENTS: NEEDS MORE WORK"
    echo "   Continue development and re-verify"
fi
echo "═══════════════════════════════════════════════════════"
```

## Important Notes

- Uses Done Oracle's **two-tier architecture** (v2.0.0)
  - **Tier 1 (VERDICT_GENERATION)**: Initial assessment with flexible thresholds
  - **Tier 2 (DONE_POLICY)**: Final DONE verdict requires 95% across all metrics
- This command does not change task status - it only verifies
- Use this to check readiness before `/pm:issue-close`
- **Dynamic Evaluation**: No hardcoded confidence thresholds - uses Oracle's policy engine
- Verification records include tier information and done policy status
- Saved for complete audit trail with architecture version tracking