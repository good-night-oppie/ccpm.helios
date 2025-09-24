---
allowed-tools: Bash, Read, Write, LS
---

# Issue Close

Mark an issue as complete and close it on GitHub.

## Usage
```
/pm:issue-close <issue_number> [completion_notes]
```

## Instructions

### 1. Find Local Task File

First check if `.claude/epics/*/$ARGUMENTS.md` exists (new naming).
If not found, search for task file with `github:.*issues/$ARGUMENTS` in frontmatter (old naming).
If not found: "❌ No local task for issue #$ARGUMENTS"

### 2. Done Oracle Verification (REQUIRED)

**CRITICAL**: All tasks must be verified by Done Oracle before closure.

Load Oracle integration functions:
```bash
source .claude/utils/oracleIntegration.md
```

Check Oracle service health:
```bash
if ! oracle_health_check; then
    echo "❌ Cannot close task - Done Oracle service required"
    echo "   Start Done Oracle service and retry"
    exit 1
fi
```

Verify task completion:
```bash
# Get task details
task_file=$(find .claude/epics -name "$ARGUMENTS.md" | head -1)
task_description=$(grep "^name:" "$task_file" | cut -d' ' -f2- || echo "Task $ARGUMENTS")
repo_path=$(pwd)

# Submit to Done Oracle for verification
echo "🔍 Verifying Task $ARGUMENTS completion with Done Oracle..."

oracle_response=$(curl -s -X POST "http://localhost:3000/api/bridge/evaluate" \
    -H "Content-Type: application/json" \
    -d "{
        \"repo\": \"$repo_path\",
        \"context\": {
            \"task\": \"Task $ARGUMENTS completion verification\",
            \"description\": \"$task_description\",
            \"type\": \"task_completion_check\",
            \"verification_source\": \"ccpm_issue_close\"
        },
        \"metadata\": {
            \"task_number\": \"$ARGUMENTS\",
            \"verification_type\": \"ccpm_completion\",
            \"command\": \"issue-close\"
        }
    }")

verdict=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('verdict', 'error'))" 2>/dev/null || echo "error")
confidence=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('confidence', 0))" 2>/dev/null || echo "0")

# Validate Oracle verdict
if [ "$verdict" = "done" ] && [ "$(echo "$confidence > 0.7" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
    echo "✅ Oracle Verification: DONE (confidence: $confidence)"
    echo "   Task $ARGUMENTS verified complete by Done Oracle"
else
    echo "❌ Oracle Verification FAILED: $verdict (confidence: $confidence)"
    echo "   Task $ARGUMENTS does not meet Done Oracle completion standards"
    echo ""
    echo "   Complete all acceptance criteria and ensure:"
    echo "   - All implementation is finished"
    echo "   - All tests are passing"
    echo "   - All documentation is complete"
    echo "   - Integration testing is successful"
    echo ""
    echo "   Then retry: /pm:issue-close $ARGUMENTS"
    exit 1
fi
```

### 3. Update Local Status

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update task file frontmatter:
```yaml
status: closed
updated: {current_datetime}
oracle_verified: true
oracle_verdict: done
oracle_confidence: {confidence}
oracle_verification_date: {current_datetime}
```

### 4. Update Progress File

If progress file exists at `.claude/epics/{epic}/updates/$ARGUMENTS/progress.md`:
- Set completion: 100%
- Add completion note with timestamp
- Update last_sync with current datetime

### 5. Close on GitHub

Add completion comment and close:
```bash
# Add final comment
echo "✅ Task completed

$ARGUMENTS

---
Closed at: {timestamp}" | gh issue comment $ARGUMENTS --body-file -

# Close the issue
gh issue close $ARGUMENTS
```

### 6. Update Epic Task List on GitHub

Check the task checkbox in the epic issue:

```bash
# Get epic name from local task file path
epic_name={extract_from_path}

# Get epic issue number from epic.md
epic_issue=$(grep 'github:' .claude/epics/$epic_name/epic.md | grep -oE '[0-9]+$')

if [ ! -z "$epic_issue" ]; then
  # Get current epic body
  gh issue view $epic_issue --json body -q .body > /tmp/epic-body.md
  
  # Check off this task
  sed -i "s/- \[ \] #$ARGUMENTS/- [x] #$ARGUMENTS/" /tmp/epic-body.md
  
  # Update epic issue
  gh issue edit $epic_issue --body-file /tmp/epic-body.md
  
  echo "✓ Updated epic progress on GitHub"
fi
```

### 7. Update Epic Progress

- Count total tasks in epic
- Count closed tasks
- Calculate new progress percentage
- Update epic.md frontmatter progress field

### 8. Output

```
✅ Closed issue #$ARGUMENTS
  Oracle: Verified DONE (confidence: {oracle_confidence})
  Local: Task marked complete with Oracle verification
  GitHub: Issue closed & epic updated
  Epic progress: {new_progress}% ({closed}/{total} tasks complete)

Next: Run /pm:next for next priority task
```

## Important Notes

Follow `/rules/frontmatter-operations.md` for updates.
Follow `/rules/github-operations.md` for GitHub commands.
Always sync local state before GitHub.