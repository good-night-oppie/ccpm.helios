#!/bin/bash

# CCPM.Helios Dependency Checker
# Validates all required system dependencies before operations

set -e

echo "🔍 CCPM.Helios Dependency Validation"
echo "═══════════════════════════════════════════════════════"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

missing_deps=""
missing_optional=""
all_good=true

# Function to check required dependency
check_required() {
    local cmd="$1"
    local description="$2"
    local min_version="$3"

    if command -v "$cmd" >/dev/null 2>&1; then
        if [ -n "$min_version" ]; then
            local version
            case "$cmd" in
                "git")
                    version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
                    ;;
                "python3")
                    version=$(python3 --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
                    ;;
                *)
                    version="installed"
                    ;;
            esac
            echo -e "  ${GREEN}✅ $description${NC} ($version)"
        else
            echo -e "  ${GREEN}✅ $description${NC}"
        fi
    else
        echo -e "  ${RED}❌ $description${NC}"
        missing_deps="$missing_deps $cmd"
        all_good=false
    fi
}

# Function to check optional dependency
check_optional() {
    local cmd="$1"
    local description="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ $description${NC} (optional)"
    else
        echo -e "  ${YELLOW}⚠️  $description${NC} (optional - some features unavailable)"
        missing_optional="$missing_optional $cmd"
    fi
}

echo "${BLUE}📋 Required System Dependencies${NC}"
echo "────────────────────────────────────────────────────"
check_required "bash" "Bash Shell" "4.0"
check_required "git" "Git Version Control" "2.30.0"
check_required "curl" "cURL HTTP Client"
check_required "python3" "Python 3" "3.6"
check_required "bc" "Basic Calculator"

echo ""
echo "${BLUE}📦 Standard POSIX Utilities${NC}"
echo "────────────────────────────────────────────────────"
check_required "grep" "GNU Grep"
check_required "sed" "Stream Editor"
check_required "find" "Find Command"
check_required "ls" "List Directory"
check_required "wc" "Word Count"
check_required "mkdir" "Make Directory"

echo ""
echo "${BLUE}🔧 Optional Dependencies${NC}"
echo "────────────────────────────────────────────────────"
check_optional "gh" "GitHub CLI (required for GitHub integration)"

echo ""
echo "${BLUE}🌐 Oracle Integration Dependencies${NC}"
echo "────────────────────────────────────────────────────"

# Check Done Oracle service availability
if curl -s "http://localhost:3000/health" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Done Oracle Service${NC} (http://localhost:3000)"
else
    echo -e "  ${YELLOW}⚠️  Done Oracle Service${NC} (not running at http://localhost:3000)"
    echo "     Install from: https://github.com/good-night-Oppie/oppie-done-oracle"
fi

# Check Python JSON parsing capability
if python3 -c "import sys, json" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Python JSON Support${NC}"
else
    echo -e "  ${RED}❌ Python JSON Support${NC} (sys/json modules required)"
    all_good=false
fi

echo ""
echo "═══════════════════════════════════════════════════════"

# Summary
if [ "$all_good" = true ]; then
    echo -e "${GREEN}🎉 All required dependencies satisfied!${NC}"

    if [ -n "$missing_optional" ]; then
        echo -e "${YELLOW}📝 Optional dependencies missing:$missing_optional${NC}"
        echo "   Some features may be unavailable but core functionality will work."
    fi

    echo ""
    echo -e "${BLUE}🚀 CCPM.Helios is ready to use!${NC}"
    echo ""
    echo "Next steps:"
    echo "  /pm:init      - Initialize project management system"
    echo "  /pm:validate  - Run full system validation"
    exit 0
else
    echo -e "${RED}💥 Missing required dependencies:$missing_deps${NC}"
    echo ""
    echo -e "${YELLOW}📋 Installation Instructions:${NC}"
    echo ""

    if [[ "$missing_deps" == *"git"* ]]; then
        echo "Install Git:"
        echo "  macOS:   brew install git"
        echo "  Ubuntu:  sudo apt-get install git"
        echo "  CentOS:  sudo yum install git"
        echo ""
    fi

    if [[ "$missing_deps" == *"curl"* ]]; then
        echo "Install cURL:"
        echo "  macOS:   brew install curl"
        echo "  Ubuntu:  sudo apt-get install curl"
        echo "  CentOS:  sudo yum install curl"
        echo ""
    fi

    if [[ "$missing_deps" == *"python3"* ]]; then
        echo "Install Python 3:"
        echo "  macOS:   brew install python3"
        echo "  Ubuntu:  sudo apt-get install python3"
        echo "  CentOS:  sudo yum install python3"
        echo ""
    fi

    if [[ "$missing_deps" == *"bc"* ]]; then
        echo "Install Basic Calculator (bc):"
        echo "  macOS:   brew install bc"
        echo "  Ubuntu:  sudo apt-get install bc"
        echo "  CentOS:  sudo yum install bc"
        echo ""
    fi

    if [[ "$missing_optional" == *"gh"* ]]; then
        echo "Install GitHub CLI (optional but recommended):"
        echo "  macOS:   brew install gh"
        echo "  Ubuntu:  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
        echo "           echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
        echo "           sudo apt update && sudo apt install gh"
        echo "  See: https://github.com/cli/cli#installation"
        echo ""
    fi

    echo -e "${RED}Please install missing dependencies before using CCPM.Helios${NC}"
    exit 1
fi