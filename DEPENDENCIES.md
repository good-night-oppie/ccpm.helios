# CCPM.Helios Dependencies

This document outlines all dependencies required for CCPM.Helios to function properly.

## Quick Validation

```bash
# Check all dependencies automatically
npm run check-deps
# or
bash scripts/check-deps.sh
```

## Required System Dependencies

### Core System Tools

| Dependency | Minimum Version | Purpose | Installation |
|------------|----------------|---------|--------------|
| **bash** | 4.0+ | Shell execution for all scripts | Usually pre-installed |
| **git** | 2.30.0+ | Version control operations | `brew install git` / `apt-get install git` |
| **curl** | Any | Oracle API communication | `brew install curl` / `apt-get install curl` |
| **python3** | 3.6+ | JSON parsing in Oracle scripts | `brew install python3` / `apt-get install python3` |
| **bc** | Any | Percentage calculations | `brew install bc` / `apt-get install bc` |

### Standard POSIX Utilities

These are typically pre-installed on Unix-like systems:

- `grep` - Text pattern matching
- `sed` - Stream text editing
- `find` - File system searching
- `ls` - Directory listings
- `wc` - Word/line counting
- `mkdir` - Directory creation

### Python Modules

Required Python standard library modules (usually included with Python 3):

- `sys` - System-specific parameters and functions
- `json` - JSON encoder and decoder

## Optional Dependencies

### GitHub Integration

| Dependency | Purpose | Installation |
|------------|---------|--------------|
| **GitHub CLI (gh)** | GitHub issue management, authentication | [Installation Guide](https://github.com/cli/cli#installation) |
| **gh-sub-issue extension** | Parent-child issue relationships | Auto-installed by `/pm:init` |

**Without GitHub CLI:**
- Core Oracle functionality works
- Local task management works
- GitHub synchronization unavailable

### Done Oracle Integration

| Service | Purpose | Installation |
|---------|---------|--------------|
| **Done Oracle Service** | AI-powered task completion verification | [oppie-done-oracle](https://github.com/good-night-Oppie/oppie-done-oracle) |

**Service Details:**
- **URL**: `http://localhost:3000`
- **Health Check**: `http://localhost:3000/health`
- **API Endpoint**: `http://localhost:3000/api/bridge/evaluate`

**Without Oracle Service:**
- Basic PM functionality works
- Task verification unavailable
- Oracle commands (`/pm:oracle-*`) will fail gracefully

## Installation Instructions

### macOS (Homebrew)

```bash
# Install required dependencies
brew install git curl python3 bc

# Install optional dependencies
brew install gh

# Install Done Oracle (follow repository instructions)
git clone https://github.com/good-night-Oppie/oppie-done-oracle.git
cd oppie-done-oracle
# Follow setup instructions in repository
```

### Ubuntu/Debian

```bash
# Install required dependencies
sudo apt-get update
sudo apt-get install git curl python3 bc

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Install Done Oracle (follow repository instructions)
git clone https://github.com/good-night-Oppie/oppie-done-oracle.git
cd oppie-done-oracle
# Follow setup instructions in repository
```

### CentOS/RHEL

```bash
# Install required dependencies
sudo yum install git curl python3 bc

# Install GitHub CLI (see official instructions)
# Install Done Oracle (follow repository instructions)
```

## Validation Commands

### Individual Checks

```bash
# Check core dependencies
command -v git && echo "Git: ✅" || echo "Git: ❌"
command -v curl && echo "cURL: ✅" || echo "cURL: ❌"
command -v python3 && echo "Python3: ✅" || echo "Python3: ❌"
command -v bc && echo "bc: ✅" || echo "bc: ❌"

# Check GitHub CLI
command -v gh && echo "GitHub CLI: ✅" || echo "GitHub CLI: ❌"
gh auth status 2>/dev/null && echo "GitHub Auth: ✅" || echo "GitHub Auth: ❌"

# Check Done Oracle
curl -s http://localhost:3000/health >/dev/null && echo "Oracle Service: ✅" || echo "Oracle Service: ❌"

# Check Python modules
python3 -c "import sys, json" && echo "Python JSON: ✅" || echo "Python JSON: ❌"
```

### System Validation

```bash
# Run CCMP.Helios validation
npm run validate
# or
/pm:validate

# Check all dependencies
npm run check-deps
# or
bash scripts/check-deps.sh
```

## Troubleshooting

### Common Issues

#### Oracle Service Unavailable
```bash
# Check if service is running
curl -s http://localhost:3000/health

# Start Oracle service (depends on installation method)
done-oracle --port 3000
# or
docker run -p 3000:3000 done-oracle:latest
```

#### GitHub CLI Authentication
```bash
# Login to GitHub
gh auth login

# Check authentication status
gh auth status
```

#### Python JSON Import Errors
```bash
# Test Python JSON support
python3 -c "import sys, json; print('Python JSON support: OK')"

# If fails, reinstall Python or check installation
python3 --version
which python3
```

#### Missing bc Calculator
```bash
# Test bc availability
echo "scale=2; 10/3" | bc

# Install if missing
# macOS: brew install bc
# Ubuntu: sudo apt-get install bc
# CentOS: sudo yum install bc
```

### Performance Considerations

- **Oracle API calls**: Require network connectivity to `localhost:3000`
- **GitHub operations**: May be rate-limited; authenticated requests have higher limits
- **JSON parsing**: Python startup overhead is minimal for small JSON responses
- **Shell operations**: Optimized for POSIX compliance and performance

## Development Dependencies

If extending CCPM.Helios functionality:

```json
{
  "devDependencies": {
    "shellcheck": "^0.8.0",
    "bats": "^1.0.0"
  }
}
```

- **ShellCheck**: Shell script static analysis
- **Bats**: Bash Automated Testing System

## License Considerations

All dependencies use permissive licenses compatible with MIT:

- System tools: Various open-source licenses
- GitHub CLI: MIT License
- Done Oracle: Check repository for license details
- Python: Python Software Foundation License

## Support

For dependency-related issues:

1. Run `npm run check-deps` for automated diagnosis
2. Check individual tool documentation for installation issues
3. Verify network connectivity for Oracle service integration
4. Ensure proper authentication for GitHub operations

For project-specific issues, see the main [README.md](README.md) troubleshooting section.