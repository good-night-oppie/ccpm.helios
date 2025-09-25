#!/bin/bash

# Oracle Verify - Manually verify task completion with Done Oracle without closing the task
# Usage: /pm:oracle-verify <issue_number>

set -e

issue_number="$1"

if [ -z "$issue_number" ]; then
    echo "❌ Please provide an issue number"
    echo "Usage: /pm:oracle-verify <issue_number>"
    exit 1
fi

# Find Local Task File
task_file=$(find .claude/epics -name "$issue_number.md" | head -1)
if [ -z "$task_file" ]; then
    echo "❌ No local task for issue #$issue_number"
    exit 1
fi

# Oracle Health Check
echo "🏥 Checking Done Oracle service health..."
if ! curl -s "http://localhost:3000/health" > /dev/null; then
    echo "❌ Done Oracle service unavailable"
    echo "   Please ensure Done Oracle is running at http://localhost:3000"
    exit 1
fi
echo "✅ Done Oracle service is healthy"

# Submit for Oracle Verification
task_description=$(grep "^name:" "$task_file" | cut -d' ' -f2- || echo "Task $issue_number")
repo_path=$(pwd)

echo "🔍 Submitting Task $issue_number for Oracle verification..."

# Submit to Done Oracle Bridge API
oracle_response=$(curl -s -X POST "http://localhost:3000/api/bridge/evaluate" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: dev-api-key-123456" \
    -d "{
        \"repo\": \"$repo_path\",
        \"context\": {
            \"task\": \"Task $issue_number manual verification\",
            \"description\": \"$task_description\",
            \"type\": \"manual_verification_check\",
            \"verification_source\": \"ccpm_oracle_verify\"
        },
        \"metadata\": {
            \"task_number\": \"$issue_number\",
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
done_policy_met=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('donePolicyMet', False))" 2>/dev/null || echo "false")
tier=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tier', 'unknown'))" 2>/dev/null || echo "unknown")

# Display Results
echo ""
echo "═══════════════════════════════════════════════════════"
echo "📋 Done Oracle Verification Results for Task $issue_number"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "🎯 Verdict: $verdict"
echo "📊 Confidence: $confidence"
echo "🏛️ Tier: $tier"
echo "📋 Done Policy Met: $done_policy_met"
echo "🧠 Processing Path: $processing_path"
echo "⚖️ Complexity Score: $complexity"
echo ""
echo "💭 Oracle Reasoning:"
echo "$reasoning"
echo ""

if [ "$verdict" = "DONE" ] && [ "$done_policy_met" = "True" ]; then
    echo "✅ ORACLE VERDICT: TASK COMPLETE"
    echo "   Task $issue_number meets Done Oracle completion standards (Tier 2)"
    echo "   All DONE policy requirements satisfied"
    echo "   Ready for closure with: /pm:issue-close $issue_number"
elif [ "$verdict" = "NOT-DONE" ]; then
    echo "❌ ORACLE VERDICT: NOT COMPLETE"
    echo "   Task $issue_number does not meet completion standards"
    echo "   Tier evaluation: $tier"
    echo "   Done policy met: $done_policy_met"
    echo "   Review and address Oracle feedback before closure"
else
    echo "❓ ORACLE VERDICT: INCONCLUSIVE"
    echo "   Unable to determine completion status"
    echo "   Verdict: $verdict, Tier: $tier"
    echo "   Check implementation and try again"
fi

# Save Verification Record
epic_name=$(dirname "$(find .claude/epics -name "$issue_number.md" | head -1)" | xargs basename)
updates_dir=".claude/epics/$epic_name/updates/$issue_number"
mkdir -p "$updates_dir"

verification_file="$updates_dir/oracle-verification-$(date +%Y%m%d-%H%M%S).json"

echo "{
  \"task\": \"$issue_number\",
  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
  \"verdict\": \"$verdict\",
  \"confidence\": $confidence,
  \"reasoning\": \"$reasoning\",
  \"processing_path\": \"$processing_path\",
  \"complexity\": $complexity,
  \"done_policy_met\": $done_policy_met,
  \"tier\": \"$tier\",
  \"verification_type\": \"manual\",
  \"command\": \"oracle-verify\",
  \"architecture_version\": \"2.0.0-two-tier\"
}" > "$verification_file"

echo ""
echo "📁 Verification record saved: $verification_file"

# Output Summary
echo ""
echo "═══════════════════════════════════════════════════════"
if [ "$verdict" = "DONE" ] && [ "$done_policy_met" = "True" ]; then
    echo "✅ Task $issue_number: READY FOR CLOSURE"
    echo "   Use: /pm:issue-close $issue_number"
    echo "   Two-tier verification: COMPLETE"
else
    echo "🔄 Task $issue_number: NEEDS MORE WORK"
    echo "   Continue development and re-verify"
    echo "   Current tier: $tier"
    echo "   Done policy: $done_policy_met"
fi
echo "═══════════════════════════════════════════════════════"