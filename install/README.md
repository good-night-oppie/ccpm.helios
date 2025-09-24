# Quick Install

## Unix/Linux/macOS

```bash
curl -sSL https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.sh | bash
```

## Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.bat | iex
```

Or download and execute:

```powershell
curl -o ccpm.bat https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.bat && ccpm.bat
```

## One-liner alternatives

### Unix/Linux/macOS (direct commands)
```bash
git clone https://github.com/automazeio/ccpm.git . && rm -rf .git
```

### Windows (cmd)
```cmd
git clone https://github.com/automazeio/ccpm.git . && rmdir /s /q .git
```

### Windows (PowerShell)
```powershell
git clone https://github.com/automazeio/ccpm.git .; Remove-Item -Recurse -Force .git
```

## Done Oracle Integration Setup

CCPM includes **Done Oracle** integration for AI-powered task completion verification. To enable Oracle functionality:

### 1. Prerequisites
- Node.js 18+ installed
- Done Oracle service running at `http://localhost:3000`

### 2. Done Oracle Service Setup

```bash
# If you have Done Oracle installed separately:
done-oracle --port 3000 --health-check

# Or via Docker:
docker run -p 3000:3000 done-oracle:latest
```

### 3. Verify Integration

```bash
# Check Oracle service health
curl -s http://localhost:3000/health

# Test Oracle API
curl -s -X POST http://localhost:3000/api/bridge/evaluate \
  -H "Content-Type: application/json" \
  -d '{"repo": ".", "context": {"task": "test", "type": "health_check"}}'
```

### 4. Oracle Commands Usage

Once setup is complete, you can use Oracle commands in your CCPM workflow:

```bash
# Check all tasks in an epic for Oracle verification
/pm:oracle-status <epic-name>

# Manually verify a specific task
/pm:oracle-verify <task-number>
```

**Note**: Oracle commands require the Done Oracle service to be running. If the service is unavailable, commands will fail gracefully with clear error messages.
