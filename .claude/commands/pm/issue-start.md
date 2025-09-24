---
allowed-tools: Bash, Read, Write, LS, Task
---

# Issue Start

Begin work on a GitHub issue with parallel agents based on work stream analysis.

## Usage
```
/pm:issue-start <issue_number>
```

## Quick Check

1. **Get issue details:**
   ```bash
   gh issue view $ARGUMENTS --json state,title,labels,body
   ```
   If it fails: "❌ Cannot access issue #$ARGUMENTS. Check number or run: gh auth login"

2. **Find local task file:**
   - First check if `.claude/epics/*/$ARGUMENTS.md` exists (new naming)
   - If not found, search for file containing `github:.*issues/$ARGUMENTS` in frontmatter (old naming)
   - If not found: "❌ No local task for issue #$ARGUMENTS. This issue may have been created outside the PM system."

3. **Done Oracle Dependency Verification (REQUIRED):**
   **CRITICAL**: All task dependencies must be Oracle-verified before starting.

   ```bash
   # Check Oracle service health
   if ! curl -s "http://localhost:3000/health" > /dev/null; then
       echo "❌ Cannot start task - Done Oracle service required"
       echo "   Start Done Oracle service and retry"
       exit 1
   fi

   # Get task dependencies
   task_file=$(find .claude/epics -name "$ARGUMENTS.md" | head -1)
   depends_on=$(grep "^depends_on:" "$task_file" | cut -d' ' -f2- | tr -d '[]' | tr ',' ' ')

   # Verify each dependency is Oracle-verified as complete
   if [ -n "$depends_on" ] && [ "$depends_on" != "[]" ]; then
       echo "🔍 Verifying dependencies with Done Oracle..."

       for dep in $depends_on; do
           dep=$(echo "$dep" | tr -d ' "')
           echo "  Checking dependency: Task $dep"

           # Find dependency task file
           dep_file=$(find .claude/epics -name "$dep.md" | head -1)
           if [ -z "$dep_file" ]; then
               echo "❌ Dependency task $dep not found"
               exit 1
           fi

           # Get dependency task description
           dep_description=$(grep "^name:" "$dep_file" | cut -d' ' -f2- || echo "Task $dep")

           # Verify with Oracle
           echo "  Submitting Task $dep for Oracle verification..."
           oracle_response=$(curl -s -X POST "http://localhost:3000/api/bridge/evaluate" \
               -H "Content-Type: application/json" \
               -d "{
                   \"repo\": \"$(pwd)\",
                   \"context\": {
                       \"task\": \"Task $dep dependency verification\",
                       \"description\": \"$dep_description\",
                       \"type\": \"dependency_completion_check\",
                       \"verification_source\": \"ccpm_issue_start\"
                   },
                   \"metadata\": {
                       \"task_number\": \"$dep\",
                       \"verification_type\": \"dependency_check\",
                       \"requesting_task\": \"$ARGUMENTS\"
                   }
               }")

           verdict=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('verdict', 'error'))" 2>/dev/null || echo "error")
           confidence=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('confidence', 0))" 2>/dev/null || echo "0")

           if [ "$verdict" = "done" ] && [ "$(echo "$confidence > 0.7" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
               echo "  ✅ Task $dep verified DONE by Oracle (confidence: $confidence)"
           else
               echo "  ❌ Task $dep NOT Oracle-verified: $verdict (confidence: $confidence)"
               echo ""
               echo "❌ Cannot start Task $ARGUMENTS - dependency Task $dep not complete"
               echo "   Complete Task $dep first and ensure it passes Oracle verification"
               echo "   Then retry: /pm:issue-start $ARGUMENTS"
               exit 1
           fi
       done

       echo "✅ All dependencies Oracle-verified as complete"
   else
       echo "✅ No dependencies to verify"
   fi
   ```

4. **Check for analysis:**
   ```bash
   test -f .claude/epics/*/$ARGUMENTS-analysis.md || echo "❌ No analysis found for issue #$ARGUMENTS

   Run: /pm:issue-analyze $ARGUMENTS first
   Or: /pm:issue-start $ARGUMENTS --analyze to do both"
   ```
   If no analysis exists and no --analyze flag, stop execution.

## Instructions

### 1. Ensure Worktree Exists

Check if epic worktree exists:
```bash
# Find epic name from task file
epic_name={extracted_from_path}

# Check worktree
if ! git worktree list | grep -q "epic-$epic_name"; then
  echo "❌ No worktree for epic. Run: /pm:epic-start $epic_name"
  exit 1
fi
```

### 2. Read Analysis

Read `.claude/epics/{epic_name}/$ARGUMENTS-analysis.md`:
- Parse parallel streams
- Identify which can start immediately
- Note dependencies between streams

### 3. Setup Progress Tracking

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Create workspace structure:
```bash
mkdir -p .claude/epics/{epic_name}/updates/$ARGUMENTS
```

Update task file frontmatter `updated` field with current datetime.

### 4. Launch Parallel Agents

For each stream that can start immediately:

Create `.claude/epics/{epic_name}/updates/$ARGUMENTS/stream-{X}.md`:
```markdown
---
issue: $ARGUMENTS
stream: {stream_name}
agent: {agent_type}
started: {current_datetime}
status: in_progress
---

# Stream {X}: {stream_name}

## Scope
{stream_description}

## Files
{file_patterns}

## Progress
- Starting implementation
```

Launch agent using Task tool:
```yaml
Task:
  description: "Issue #$ARGUMENTS Stream {X}"
  subagent_type: "{agent_type}"
  prompt: |
    You are working on Issue #$ARGUMENTS in the epic worktree.
    
    Worktree location: ../epic-{epic_name}/
    Your stream: {stream_name}
    
    Your scope:
    - Files to modify: {file_patterns}
    - Work to complete: {stream_description}
    
    Requirements:
    1. Read full task from: .claude/epics/{epic_name}/{task_file}
    2. Work ONLY in your assigned files
    3. Commit frequently with format: "Issue #$ARGUMENTS: {specific change}"
    4. Update progress in: .claude/epics/{epic_name}/updates/$ARGUMENTS/stream-{X}.md
    5. Follow coordination rules in /rules/agent-coordination.md
    
    If you need to modify files outside your scope:
    - Check if another stream owns them
    - Wait if necessary
    - Update your progress file with coordination notes
    
    Complete your stream's work and mark as completed when done.
```

### 5. GitHub Assignment

```bash
# Assign to self and mark in-progress
gh issue edit $ARGUMENTS --add-assignee @me --add-label "in-progress"
```

### 6. Output

```
✅ Started parallel work on issue #$ARGUMENTS

Epic: {epic_name}
Worktree: ../epic-{epic_name}/

Launching {count} parallel agents:
  Stream A: {name} (Agent-1) ✓ Started
  Stream B: {name} (Agent-2) ✓ Started
  Stream C: {name} - Waiting (depends on A)

Progress tracking:
  .claude/epics/{epic_name}/updates/$ARGUMENTS/

Monitor with: /pm:epic-status {epic_name}
Sync updates: /pm:issue-sync $ARGUMENTS
```

## Error Handling

If any step fails, report clearly:
- "❌ {What failed}: {How to fix}"
- Continue with what's possible
- Never leave partial state

## Important Notes

Follow `/rules/datetime.md` for timestamps.
Keep it simple - trust that GitHub and file system work.