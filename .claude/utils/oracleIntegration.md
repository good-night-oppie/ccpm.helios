# Done Oracle Integration for ccpm.helios

This utility provides Done Oracle verification functions for ccpm.helios commands to enforce completion standards.

## Oracle Verification Functions

### verifyTaskCompletion()
```bash
# Verify task completion with Done Oracle
# Usage: call this function before closing any task
verify_task_completion() {
    local task_number="$1"
    local repo_path="$2"
    local task_description="$3"

    echo "🔍 Verifying task $task_number with Done Oracle..."

    # Submit to Done Oracle Bridge API
    local oracle_response=$(curl -s -X POST "http://localhost:3000/api/bridge/evaluate" \
        -H "Content-Type: application/json" \
        -d "{
            \"repo\": \"$repo_path\",
            \"context\": {
                \"task\": \"Task $task_number completion verification\",
                \"description\": \"$task_description\",
                \"type\": \"task_completion_check\"
            },
            \"metadata\": {
                \"task_number\": \"$task_number\",
                \"verification_type\": \"ccpm_completion\"
            }
        }")

    local verdict=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('verdict', 'error'))" 2>/dev/null || echo "error")
    local confidence=$(echo "$oracle_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('confidence', 0))" 2>/dev/null || echo "0")

    if [ "$verdict" = "done" ] && [ "$(echo "$confidence > 0.7" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
        echo "✅ Oracle Verification: DONE (confidence: $confidence)"
        return 0
    else
        echo "❌ Oracle Verification: $verdict (confidence: $confidence)"
        echo "   Task does not meet Done Oracle completion standards"
        return 1
    fi
}
```

### checkDependencyCompletion()
```bash
# Check if dependency tasks are Oracle-verified as complete
check_dependency_completion() {
    local depends_on="$1"  # JSON array of dependencies
    local repo_path="$2"

    if [ "$depends_on" = "[]" ] || [ -z "$depends_on" ]; then
        echo "✅ No dependencies to verify"
        return 0
    fi

    echo "🔍 Checking dependency completion with Done Oracle..."

    # Parse dependencies (simplified - assumes format like [001, 002])
    local deps=$(echo "$depends_on" | tr -d '[]' | tr ',' ' ')

    for dep in $deps; do
        dep=$(echo "$dep" | tr -d ' "')
        echo "  Checking dependency: Task $dep"

        # Find local task file for dependency
        local dep_file=$(find .claude/epics -name "$dep.md" | head -1)
        if [ -z "$dep_file" ]; then
            echo "❌ Dependency task $dep not found"
            return 1
        fi

        # Get task description for Oracle verification
        local dep_description=$(grep "^name:" "$dep_file" | cut -d' ' -f2- || echo "Task $dep")

        # Verify with Oracle
        if ! verify_task_completion "$dep" "$repo_path" "$dep_description"; then
            echo "❌ Dependency Task $dep not Oracle-verified as complete"
            return 1
        fi
    done

    echo "✅ All dependencies Oracle-verified as complete"
    return 0
}
```

### oracleHealthCheck()
```bash
# Check if Done Oracle service is available
oracle_health_check() {
    echo "🏥 Checking Done Oracle service health..."

    local health_response=$(curl -s "http://localhost:3000/health" 2>/dev/null)
    local status=$(echo "$health_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', 'error'))" 2>/dev/null || echo "error")

    if [ "$status" = "healthy" ]; then
        echo "✅ Done Oracle service is healthy"
        return 0
    else
        echo "❌ Done Oracle service unavailable"
        echo "   Please ensure Done Oracle is running at http://localhost:3000"
        return 1
    fi
}
```

## Usage in Commands

### In /pm:issue-close
```bash
# Before closing task
if ! oracle_health_check; then
    echo "❌ Cannot close task - Done Oracle service required"
    exit 1
fi

task_description=$(grep "^name:" .claude/epics/*/$ARGUMENTS.md | cut -d' ' -f2-)
if ! verify_task_completion "$ARGUMENTS" "$(pwd)" "$task_description"; then
    echo "❌ Task $ARGUMENTS cannot be closed - not verified by Done Oracle"
    echo "   Complete all acceptance criteria and retry"
    exit 1
fi
```

### In /pm:issue-start
```bash
# Before starting task
if ! oracle_health_check; then
    echo "❌ Cannot start task - Done Oracle service required"
    exit 1
fi

depends_on=$(grep "^depends_on:" .claude/epics/*/$ARGUMENTS.md | cut -d' ' -f2-)
if ! check_dependency_completion "$depends_on" "$(pwd)"; then
    echo "❌ Task $ARGUMENTS cannot start - dependencies not Oracle-verified"
    echo "   Complete dependency tasks first"
    exit 1
fi
```

## Configuration

Set these environment variables for customization:
- `ORACLE_URL`: Done Oracle service URL (default: http://localhost:3000)
- `ORACLE_MIN_CONFIDENCE`: Minimum confidence threshold (default: 0.7)
- `ORACLE_TIMEOUT`: Request timeout in seconds (default: 30)