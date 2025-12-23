#!/bin/bash

# index.sh - Recursively find all shell scripts, make them executable, and add to global PATH
# Usage: ./index.sh [--dry-run] [--remove]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYMLINK_DIR="/usr/local/bin"
LOCAL_BIN_DIR="$HOME/.local/bin"
DRY_RUN=false
REMOVE_MODE=false
USE_LOCAL_BIN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --remove)
            REMOVE_MODE=true
            shift
            ;;
        --local)
            USE_LOCAL_BIN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--remove] [--local]"
            echo "  --dry-run: Show what would be done without making changes"
            echo "  --remove:  Remove symlinks and restore original state"
            echo "  --local:   Use ~/.local/bin instead of /usr/local/bin (no sudo required)"
            echo "  --help:    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to execute command with dry-run support
execute_cmd() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "$YELLOW" "[DRY RUN] Would execute: $cmd"
        print_status "$BLUE" "  → $description"
    else
        print_status "$BLUE" "$description"
        eval "$cmd"
    fi
}

# Function to check if we have necessary permissions
check_permissions() {
    local target_dir="$SYMLINK_DIR"
    
    # Use local bin if specified or if we don't have permission to /usr/local/bin
    if [[ "$USE_LOCAL_BIN" == "true" ]] || [[ ! -w "$SYMLINK_DIR" ]]; then
        target_dir="$LOCAL_BIN_DIR"
        USE_LOCAL_BIN=true
        
        # Create ~/.local/bin if it doesn't exist
        if [[ ! -d "$target_dir" ]]; then
            execute_cmd "mkdir -p '$target_dir'" "Creating directory: $target_dir"
        fi
        
        SYMLINK_DIR="$target_dir"
        
        # Check if ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$LOCAL_BIN_DIR:"* ]]; then
            print_status "$YELLOW" "Note: $LOCAL_BIN_DIR is not in your PATH"
            print_status "$YELLOW" "Add this line to your ~/.bashrc or ~/.zshrc:"
            print_status "$BLUE" "export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi
    
    if [[ ! -w "$SYMLINK_DIR" ]] && [[ "$DRY_RUN" == "false" ]]; then
        print_status "$RED" "Error: No write permission to $SYMLINK_DIR"
        if [[ "$SYMLINK_DIR" == "/usr/local/bin" ]]; then
            print_status "$YELLOW" "Try running with --local flag to use ~/.local/bin instead"
        fi
        exit 1
    fi
}

# Function to remove existing symlinks
remove_symlinks() {
    print_status "$YELLOW" "Removing existing symlinks..."
    
    # Find all shell scripts
    while IFS= read -r -d '' script_path; do
        script_name=$(basename "$script_path" .sh)
        symlink_path="$SYMLINK_DIR/$script_name"
        
        if [[ -L "$symlink_path" ]]; then
            # Check if it's our symlink
            if [[ "$(readlink "$symlink_path")" == "$script_path" ]]; then
                execute_cmd "rm '$symlink_path'" "Removing symlink: $symlink_path"
            fi
        fi
    done < <(find "$SCRIPT_DIR" -name "*.sh" -type f -print0)
    
    print_status "$GREEN" "Symlink removal completed!"
}

# Function to make scripts executable and create symlinks
setup_scripts() {
    local script_count=0
    local executable_count=0
    local symlink_count=0
    
    print_status "$BLUE" "Scanning for shell scripts in: $SCRIPT_DIR"
    
    # Find all .sh files recursively
    while IFS= read -r -d '' script_path; do
        ((script_count++))
        
        # Get relative path for display
        rel_path="${script_path#$SCRIPT_DIR/}"
        print_status "$BLUE" "Processing: $rel_path"
        
        # Make executable if not already
        if [[ ! -x "$script_path" ]]; then
            execute_cmd "chmod +x '$script_path'" "  Making executable: $script_path"
            ((executable_count++))
        else
            print_status "$GREEN" "  Already executable: $script_path"
        fi
        
        # Create symlink for global access (skip index.sh to avoid recursion)
        script_name=$(basename "$script_path" .sh)
        if [[ "$script_name" != "index" ]]; then
            symlink_path="$SYMLINK_DIR/$script_name"
            
            # Check if symlink already exists and points to the right place
            if [[ -L "$symlink_path" ]] && [[ "$(readlink "$symlink_path")" == "$script_path" ]]; then
                print_status "$GREEN" "  Symlink already exists: $symlink_path"
            else
                # Remove existing symlink/file if it exists
                if [[ -e "$symlink_path" ]] || [[ -L "$symlink_path" ]]; then
                    execute_cmd "rm '$symlink_path'" "  Removing existing: $symlink_path"
                fi
                
                execute_cmd "ln -s '$script_path' '$symlink_path'" "  Creating symlink: $symlink_path"
                ((symlink_count++))
            fi
        fi
        
    done < <(find "$SCRIPT_DIR" -name "*.sh" -type f -print0)
    
    # Summary
    print_status "$GREEN" "================================"
    print_status "$GREEN" "Setup completed successfully!"
    print_status "$GREEN" "================================"
    print_status "$BLUE" "Scripts found: $script_count"
    print_status "$BLUE" "Made executable: $executable_count"
    print_status "$BLUE" "Symlinks created: $symlink_count"
    
    if [[ $script_count -gt 0 ]]; then
        print_status "$YELLOW" ""
        print_status "$YELLOW" "Your scripts are now globally accessible:"
        while IFS= read -r -d '' script_path; do
            script_name=$(basename "$script_path" .sh)
            if [[ "$script_name" != "index" ]]; then
                print_status "$GREEN" "  $script_name"
            fi
        done < <(find "$SCRIPT_DIR" -name "*.sh" -type f -print0)
        
        print_status "$YELLOW" ""
        print_status "$YELLOW" "You can now run these scripts from anywhere by just typing their name!"
        print_status "$YELLOW" "Example: dataMigration, docker-manager, etc."
    fi
}

# Main execution
main() {
    print_status "$BLUE" "🚀 Shell Script Index Manager"
    print_status "$BLUE" "=============================="
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "$YELLOW" "DRY RUN MODE - No changes will be made"
    fi
    
    check_permissions
    
    if [[ "$REMOVE_MODE" == "true" ]]; then
        remove_symlinks
    else
        setup_scripts
    fi
}

# Run main function
main "$@"
