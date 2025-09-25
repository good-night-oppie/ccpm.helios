#!/bin/bash

# CCPM.Helios Backup Restoration Script
# Restores from smart-install.sh created backups

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
log_info() { log "${BLUE}[INFO]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }
log_success() { log "${GREEN}[SUCCESS]${NC} $1"; }

# Validation functions
validate_backup_dir() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi

    if [[ ! -r "$backup_dir" ]]; then
        log_error "Cannot read backup directory: $backup_dir"
        return 1
    fi

    # Check if backup directory contains expected structure
    local has_content=false
    for subdir in "$backup_dir"/*; do
        if [[ -d "$subdir" ]]; then
            has_content=true
            break
        fi
    done

    if [[ "$has_content" == "false" ]]; then
        log_error "Backup directory appears to be empty: $backup_dir"
        return 1
    fi

    return 0
}

# List backup contents
list_backup_contents() {
    local backup_dir="$1"

    log_info "Backup contents in $backup_dir:"
    find "$backup_dir" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
        local dirname=$(basename "$subdir")
        local file_count=$(find "$subdir" -type f | wc -l)
        log_info "  • $dirname: $file_count files"

        # Show first few files as preview
        find "$subdir" -name "*.md" -type f | head -3 | while read -r file; do
            log_info "    - $(basename "$file")"
        done
        if [[ $(find "$subdir" -name "*.md" -type f | wc -l) -gt 3 ]]; then
            log_info "    ... and more"
        fi
    done
}

# Restore function
restore_from_backup() {
    local backup_dir="$1"
    local confirm="${2:-false}"
    local target_dir="${3:-.}"

    log_info "Starting restoration from backup: $backup_dir"
    log_info "Target directory: $target_dir"

    cd "$target_dir"

    # Show what will be restored
    list_backup_contents "$backup_dir"

    if [[ "$confirm" != "true" ]]; then
        echo ""
        log_warn "This will overwrite existing files. Are you sure? [y/N]"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Restoration cancelled by user"
            return 0
        fi
    fi

    # Create pre-restore backup
    local pre_restore_backup=".pre-restore-backup-$(date +%Y%m%d-%H%M%S)"
    log_info "Creating pre-restoration backup: $pre_restore_backup"
    mkdir -p "$pre_restore_backup"

    # Backup current state
    [[ -d "ccpm/prds" ]] && cp -r "ccpm/prds" "$pre_restore_backup/current-prds" || true
    [[ -d "ccpm/epics" ]] && cp -r "ccpm/epics" "$pre_restore_backup/current-epics" || true
    [[ -d ".claude" ]] && cp -r ".claude" "$pre_restore_backup/current-claude" || true

    # Perform restoration
    find "$backup_dir" -mindepth 1 -maxdepth 1 -type d | while read -r backup_subdir; do
        local dirname=$(basename "$backup_subdir")
        local target_path=""

        case "$dirname" in
            "PRDs"|"prds")
                target_path="ccpm/prds"
                ;;
            "Epics"|"epics")
                target_path="ccpm/epics"
                ;;
            "legacy-claude-structure")
                target_path=".claude"
                ;;
            "package.json.backup")
                if [[ -f "$backup_subdir" ]]; then
                    target_path="package.json"
                fi
                ;;
            "README.md.backup")
                if [[ -f "$backup_subdir" ]]; then
                    target_path="README.md"
                fi
                ;;
            *)
                log_warn "Unknown backup directory: $dirname, skipping"
                continue
                ;;
        esac

        if [[ -n "$target_path" ]]; then
            log_info "Restoring $dirname -> $target_path"

            # Remove existing target
            if [[ -d "$target_path" ]]; then
                rm -rf "$target_path"
            elif [[ -f "$target_path" ]]; then
                rm -f "$target_path"
            fi

            # Create parent directory if needed
            mkdir -p "$(dirname "$target_path")"

            # Restore from backup
            if [[ -d "$backup_subdir" ]]; then
                cp -r "$backup_subdir" "$target_path"
            elif [[ -f "$backup_subdir" ]]; then
                cp "$backup_subdir" "$target_path"
            fi

            log_success "Restored $dirname"
        fi
    done

    log_success "Restoration completed successfully!"
    log_info "Pre-restoration backup saved in: $pre_restore_backup"

    # Show restoration summary
    show_restoration_summary
}

show_restoration_summary() {
    log_info "=== Restoration Summary ==="

    log_info "Restored components:"
    [[ -d "ccpm/prds" ]] && log_info "  • PRDs: $(find ccpm/prds -name "*.md" | wc -l) files"
    [[ -d "ccpm/epics" ]] && log_info "  • Epics: $(find ccpm/epics -name "*.md" | wc -l) files"
    [[ -d ".claude" ]] && log_info "  • Legacy .claude structure restored"
    [[ -f "package.json" ]] && log_info "  • Package configuration restored"

    log_info "Next steps:"
    log_info "  1. Verify installation: ./scripts/smart-install.sh detect"
    log_info "  2. Test Oracle integration: /pm:oracle-verify --health-check"
    log_info "  3. Check project status: /pm:status"
}

# List available backups
list_available_backups() {
    local search_dir="${1:-.}"

    log_info "Available backups in $search_dir:"

    find "$search_dir" -maxdepth 1 -type d -name ".ccpm-backup-*" | sort -r | while read -r backup_dir; do
        local backup_name=$(basename "$backup_dir")
        local backup_date=$(echo "$backup_name" | sed 's/.*-\([0-9]\{8\}-[0-9]\{6\}\)/\1/')
        local file_count=0

        if [[ -d "$backup_dir" ]]; then
            file_count=$(find "$backup_dir" -type f | wc -l)
        fi

        log_info "  • $backup_name ($file_count files) - $backup_date"
    done

    # Also list pre-restore backups
    find "$search_dir" -maxdepth 1 -type d -name ".pre-restore-backup-*" | sort -r | while read -r backup_dir; do
        local backup_name=$(basename "$backup_dir")
        local backup_date=$(echo "$backup_name" | sed 's/.*-\([0-9]\{8\}-[0-9]\{6\}\)/\1/')
        local file_count=0

        if [[ -d "$backup_dir" ]]; then
            file_count=$(find "$backup_dir" -type f | wc -l)
        fi

        log_warn "  • $backup_name ($file_count files) - $backup_date [PRE-RESTORE]"
    done
}

# Clean old backups
clean_old_backups() {
    local search_dir="${1:-.}"
    local days_to_keep="${2:-30}"

    log_info "Cleaning backups older than $days_to_keep days in $search_dir"

    find "$search_dir" -maxdepth 1 -type d \
        \( -name ".ccpm-backup-*" -o -name ".pre-restore-backup-*" \) \
        -mtime +$days_to_keep | while read -r old_backup; do

        local backup_name=$(basename "$old_backup")
        log_warn "Removing old backup: $backup_name"
        rm -rf "$old_backup"
    done

    log_success "Cleanup completed"
}

# Main function
main() {
    local command="${1:-help}"

    case "$command" in
        "restore")
            local backup_dir="$2"
            local confirm="${3:-false}"

            if [[ -z "$backup_dir" ]]; then
                log_error "Please specify backup directory"
                log_info "Usage: $0 restore <backup_directory> [true|false]"
                exit 1
            fi

            if validate_backup_dir "$backup_dir"; then
                restore_from_backup "$backup_dir" "$confirm"
            else
                exit 1
            fi
            ;;
        "list")
            local search_dir="${2:-.}"
            list_available_backups "$search_dir"
            ;;
        "clean")
            local search_dir="${2:-.}"
            local days="${3:-30}"
            clean_old_backups "$search_dir" "$days"
            ;;
        "help"|*)
            echo "CCPM.Helios Backup Restoration Script"
            echo ""
            echo "Usage: $0 <command> [parameters...]"
            echo ""
            echo "Commands:"
            echo "  restore <backup_dir> [confirm]  - Restore from backup directory"
            echo "  list [search_dir]               - List available backups"
            echo "  clean [search_dir] [days]       - Clean backups older than N days"
            echo "  help                           - Show this help message"
            echo ""
            echo "Parameters:"
            echo "  backup_dir  - Path to backup directory (e.g., .ccpm-backup-20231201-120000)"
            echo "  confirm     - 'true' to skip confirmation prompt"
            echo "  search_dir  - Directory to search for backups (default: current)"
            echo "  days        - Days to keep backups (default: 30)"
            echo ""
            echo "Examples:"
            echo "  $0 list                              # List all available backups"
            echo "  $0 restore .ccpm-backup-20231201-120000  # Restore with confirmation"
            echo "  $0 restore .ccpm-backup-20231201-120000 true  # Restore without prompt"
            echo "  $0 clean . 7                        # Clean backups older than 7 days"
            ;;
    esac
}

# Run main function with all arguments
main "$@"