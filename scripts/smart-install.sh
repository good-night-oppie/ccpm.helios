#!/bin/bash

# CCPM.Helios Smart Installation Script with Migration Protection
# Preserves existing PRDs and Epics during installation/upgrade

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR=".ccpm-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="ccpm-install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
log_info() { log "${BLUE}[INFO]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }
log_success() { log "${GREEN}[SUCCESS]${NC} $1"; }

# Migration detection functions
detect_existing_content() {
    local dir="$1"
    local content_type="$2"

    if [[ ! -d "$dir" ]]; then
        log_info "No existing $content_type directory found at $dir"
        return 1
    fi

    # Count non-gitkeep files
    local file_count=$(find "$dir" -type f -name "*.md" | wc -l)

    if [[ $file_count -eq 0 ]]; then
        log_info "Existing $content_type directory is empty (no .md files)"
        return 1
    fi

    log_warn "Found $file_count existing $content_type files in $dir"
    return 0
}

list_existing_content() {
    local dir="$1"
    local content_type="$2"

    log_info "Existing $content_type files:"
    find "$dir" -type f -name "*.md" -printf "  • %f\n" 2>/dev/null || true
}

# Backup functions
create_backup() {
    local source="$1"
    local backup_name="$2"

    if [[ -d "$source" ]]; then
        log_info "Creating backup: $source -> $BACKUP_DIR/$backup_name"
        mkdir -p "$BACKUP_DIR"
        cp -r "$source" "$BACKUP_DIR/$backup_name"
        log_success "Backup created successfully"
        return 0
    fi
    return 1
}

# Installation functions
install_directory_safely() {
    local source_dir="$1"
    local target_dir="$2"
    local content_type="$3"
    local preserve_existing="${4:-true}"

    log_info "Installing $content_type directory: $source_dir -> $target_dir"

    # Check if target directory exists and has content
    if detect_existing_content "$target_dir" "$content_type"; then
        if [[ "$preserve_existing" == "true" ]]; then
            log_warn "Preserving existing $content_type content"
            list_existing_content "$target_dir" "$content_type"

            # Create backup
            create_backup "$target_dir" "$content_type"

            # Only copy new files that don't exist
            if [[ -d "$source_dir" ]]; then
                log_info "Merging new $content_type files (preserving existing)"
                find "$source_dir" -name "*.md" -type f | while read -r source_file; do
                    local filename=$(basename "$source_file")
                    local target_file="$target_dir/$filename"

                    if [[ ! -f "$target_file" ]]; then
                        log_info "Adding new file: $filename"
                        cp "$source_file" "$target_file"
                    else
                        log_warn "Skipping existing file: $filename"
                    fi
                done
            fi
        else
            log_warn "Replacing existing $content_type content (preserve_existing=false)"
            create_backup "$target_dir" "$content_type"
            rm -rf "$target_dir"
            cp -r "$source_dir" "$target_dir"
        fi
    else
        # No existing content, safe to copy
        log_info "No existing $content_type content, installing fresh"
        mkdir -p "$(dirname "$target_dir")"
        if [[ -d "$source_dir" ]]; then
            cp -r "$source_dir" "$target_dir"
        else
            mkdir -p "$target_dir"
        fi
    fi

    log_success "$content_type installation completed"
}

# Main installation function
install_ccpm() {
    local target_base="${1:-.}"
    local preserve_content="${2:-true}"

    log_info "Starting CCPM.Helios smart installation to: $target_base"
    log_info "Content preservation mode: $preserve_content"

    cd "$target_base"

    # Detect current structure (legacy .claude vs new ccpm)
    local legacy_structure=false
    if [[ -d ".claude" && ! -d "ccpm" ]]; then
        legacy_structure=true
        log_warn "Detected legacy .claude directory structure"
    fi

    # Install/upgrade ccpm structure
    if [[ "$legacy_structure" == "true" ]]; then
        log_info "Migrating from legacy .claude structure to ccpm"

        # Migrate PRDs
        if detect_existing_content ".claude/prds" "PRDs"; then
            install_directory_safely ".claude/prds" "ccpm/prds" "PRDs" "$preserve_content"
        else
            install_directory_safely "$PROJECT_ROOT/ccpm/prds" "ccpm/prds" "PRDs" false
        fi

        # Migrate Epics
        if detect_existing_content ".claude/epics" "Epics"; then
            install_directory_safely ".claude/epics" "ccpm/epics" "Epics" "$preserve_content"
        else
            install_directory_safely "$PROJECT_ROOT/ccpm/epics" "ccpm/epics" "Epics" false
        fi

        # Create backup of legacy structure
        if [[ -d ".claude" ]]; then
            create_backup ".claude" "legacy-claude-structure"
        fi
    else
        # Standard ccpm installation/upgrade
        install_directory_safely "$PROJECT_ROOT/ccpm/prds" "ccpm/prds" "PRDs" "$preserve_content"
        install_directory_safely "$PROJECT_ROOT/ccpm/epics" "ccpm/epics" "Epics" "$preserve_content"
    fi

    # Install other ccpm directories (always replace)
    local ccpm_dirs=("commands" "context" "rules" "hooks" "scripts")
    for dir in "${ccpm_dirs[@]}"; do
        if [[ -d "$PROJECT_ROOT/ccpm/$dir" ]]; then
            log_info "Installing ccpm/$dir directory"
            cp -r "$PROJECT_ROOT/ccpm/$dir" "ccpm/"
        fi
    done

    # Install root files
    local root_files=("package.json" "README.md" "DEPENDENCIES.md")
    for file in "${root_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            local install_file=true

            # Special handling for README.md and package.json
            if [[ "$file" == "README.md" && -f "$file" ]]; then
                log_warn "README.md exists, creating backup before replacement"
                cp "$file" "$BACKUP_DIR/README.md.backup" 2>/dev/null || true
            elif [[ "$file" == "package.json" && -f "$file" ]]; then
                log_warn "package.json exists, merging dependencies"
                # TODO: Implement smart package.json merging
                create_backup "$file" "package.json.backup"
            fi

            if [[ "$install_file" == "true" ]]; then
                log_info "Installing $file"
                cp "$PROJECT_ROOT/$file" "$file"
            fi
        fi
    done

    # Install scripts directory
    if [[ -d "$PROJECT_ROOT/scripts" ]]; then
        log_info "Installing scripts directory"
        cp -r "$PROJECT_ROOT/scripts" "."
    fi

    # Install install directory
    if [[ -d "$PROJECT_ROOT/install" ]]; then
        log_info "Installing install documentation"
        cp -r "$PROJECT_ROOT/install" "."
    fi

    log_success "CCPM.Helios installation completed successfully!"

    # Show installation summary
    show_installation_summary
}

show_installation_summary() {
    log_info "=== Installation Summary ==="

    if [[ -d "$BACKUP_DIR" ]]; then
        log_warn "Backups created in: $BACKUP_DIR"
        find "$BACKUP_DIR" -type f | head -10 | while read -r backup_file; do
            log_info "  • $(basename "$backup_file")"
        done
    fi

    log_info "Installed components:"
    [[ -d "ccpm/prds" ]] && log_info "  • PRDs directory: $(find ccpm/prds -name "*.md" | wc -l) files"
    [[ -d "ccpm/epics" ]] && log_info "  • Epics directory: $(find ccpm/epics -name "*.md" | wc -l) files"
    [[ -d "ccpm/commands" ]] && log_info "  • Commands directory: $(find ccpm/commands -name "*.md" | wc -l) files"
    [[ -f "package.json" ]] && log_info "  • Package configuration"
    [[ -d "scripts" ]] && log_info "  • Installation scripts"

    log_info "Next steps:"
    log_info "  1. Verify Oracle integration: /pm:oracle-verify --health-check"
    log_info "  2. Initialize project: /pm:init"
    log_info "  3. Check status: /pm:status"

    if [[ -d "$BACKUP_DIR" ]]; then
        log_warn "To restore from backup: ./scripts/restore-backup.sh $BACKUP_DIR"
    fi
}

# Rollback function
rollback_installation() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        exit 1
    fi

    log_warn "Rolling back installation from backup: $backup_dir"

    # Restore from backup
    find "$backup_dir" -mindepth 1 -maxdepth 1 -type d | while read -r backup_subdir; do
        local dirname=$(basename "$backup_subdir")
        local target_dir=""

        case "$dirname" in
            "PRDs"|"prds") target_dir="ccpm/prds" ;;
            "Epics"|"epics") target_dir="ccpm/epics" ;;
            "legacy-claude-structure") target_dir=".claude" ;;
            *) continue ;;
        esac

        if [[ -n "$target_dir" ]]; then
            log_info "Restoring $dirname to $target_dir"
            rm -rf "$target_dir"
            cp -r "$backup_subdir" "$target_dir"
        fi
    done

    log_success "Rollback completed"
}

# Command line interface
main() {
    local command="${1:-install}"
    local target="${2:-.}"
    local preserve="${3:-true}"

    case "$command" in
        "install")
            install_ccpm "$target" "$preserve"
            ;;
        "rollback")
            rollback_installation "$target"
            ;;
        "detect")
            log_info "=== Content Detection Report ==="
            detect_existing_content "ccpm/prds" "PRDs" && list_existing_content "ccpm/prds" "PRDs"
            detect_existing_content "ccpm/epics" "Epics" && list_existing_content "ccpm/epics" "Epics"
            detect_existing_content ".claude/prds" "Legacy PRDs" && list_existing_content ".claude/prds" "Legacy PRDs"
            detect_existing_content ".claude/epics" "Legacy Epics" && list_existing_content ".claude/epics" "Legacy Epics"
            ;;
        "help"|*)
            echo "CCMP.Helios Smart Installation Script"
            echo ""
            echo "Usage: $0 <command> [target_dir] [preserve_content]"
            echo ""
            echo "Commands:"
            echo "  install     - Install CCPM with content preservation (default)"
            echo "  rollback    - Rollback to previous backup"
            echo "  detect      - Detect existing content without installing"
            echo "  help        - Show this help message"
            echo ""
            echo "Parameters:"
            echo "  target_dir      - Installation directory (default: current directory)"
            echo "  preserve_content - true|false (default: true)"
            echo ""
            echo "Examples:"
            echo "  $0 install . true          # Install preserving existing content"
            echo "  $0 install . false         # Install replacing existing content"
            echo "  $0 detect                  # Check what content exists"
            echo "  $0 rollback .ccpm-backup-* # Rollback from backup"
            ;;
    esac
}

# Run main function with all arguments
main "$@"