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

# Function to configure MCP servers for Claude, Gemini, and ChatGPT
setup_mcp_servers() {
    local mcp_dir="$SCRIPT_DIR/appleAutomationMcp"
    local mcp_name="apple-automation-mcp"

    if [[ ! -d "$mcp_dir" ]]; then
        return 0
    fi

    print_status "$BLUE" ""
    print_status "$BLUE" "🤖 Setting up MCP Server: $mcp_name"
    print_status "$BLUE" "========================================"

    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        print_status "$RED" "Error: node and npm are required to build and install $mcp_name"
        return 1
    fi

    local node_bin
    node_bin="$(command -v node)"
    local server_entry="$mcp_dir/dist/index.js"

    # Build MCP server
    execute_cmd "cd '$mcp_dir' && npm install --no-fund --no-audit && npm run build && chmod +x '$server_entry'" \
        "Building $mcp_name in $mcp_dir"

    # Register in Gemini, Claude Desktop, Claude Code, and ChatGPT (Codex)
    local gemini_config="$HOME/.gemini/config/mcp_config.json"
    local claude_desktop_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    local claude_code_config="$HOME/.claude.json"
    local chatgpt_codex_config="$HOME/.codex/config.toml"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "$YELLOW" "[DRY RUN] Would register $mcp_name in:"
        print_status "$BLUE" "  → Gemini:         $gemini_config"
        print_status "$BLUE" "  → Claude Desktop: $claude_desktop_config"
        print_status "$BLUE" "  → Claude Code:    $claude_code_config"
        print_status "$BLUE" "  → ChatGPT/Codex:  $chatgpt_codex_config"
        return 0
    fi

    local claude_was_running=false
    if pgrep -x "Claude" >/dev/null 2>&1; then
        claude_was_running=true
        print_status "$YELLOW" "Closing Claude Desktop temporarily so it doesn't overwrite claude_desktop_config.json..."
        osascript -e 'tell application "Claude" to quit' >/dev/null 2>&1 || killall "Claude" >/dev/null 2>&1 || true
        for _ in {1..20}; do
            if ! pgrep -x "Claude" >/dev/null 2>&1; then
                break
            fi
            sleep 0.25
        done
    fi

    MCP_NAME="$mcp_name" NODE_BIN="$node_bin" SERVER_ENTRY="$server_entry" \
    GEMINI_CONFIG="$gemini_config" \
    CLAUDE_DESKTOP_CONFIG="$claude_desktop_config" \
    CLAUDE_CODE_CONFIG="$claude_code_config" \
    CHATGPT_CODEX_CONFIG="$chatgpt_codex_config" \
    node -e '
const fs = require("fs");
const path = require("path");

const mcpName = process.env.MCP_NAME;
const nodeBin = process.env.NODE_BIN;
const serverEntry = process.env.SERVER_ENTRY;

function upsertJsonMcp(filePath, label, createIfMissing = true) {
  try {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      if (!createIfMissing) return;
      fs.mkdirSync(dir, { recursive: true });
    }
    let data = {};
    if (fs.existsSync(filePath)) {
      const raw = fs.readFileSync(filePath, "utf8").trim();
      if (raw) data = JSON.parse(raw);
    } else if (!createIfMissing) {
      return;
    }
    if (!data.mcpServers || typeof data.mcpServers !== "object") {
      data.mcpServers = {};
    }
    data.mcpServers[mcpName] = {
      command: nodeBin,
      args: [serverEntry],
    };
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n", "utf8");
    console.log(`  ✔ Registered in ${label}: ${filePath}`);
  } catch (err) {
    console.error(`  ✖ Failed to update ${label} (${filePath}): ${err.message}`);
  }
}

function upsertTomlMcp(filePath, label) {
  try {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    let content = fs.existsSync(filePath) ? fs.readFileSync(filePath, "utf8") : "";
    const blockRegex = new RegExp(
      `\\n?\\[mcp_servers\\.${mcpName}(?:\\.[^\\]]+)?\\][\\s\\S]*?(?=\\n\\[|$)`,
      "g"
    );
    content = content.replace(blockRegex, "").trimEnd();
    const newBlock = [
      "",
      `[mcp_servers.${mcpName}]`,
      `command = ${JSON.stringify(nodeBin)}`,
      `args = [${JSON.stringify(serverEntry)}]`,
      "",
    ].join("\n");
    fs.writeFileSync(filePath, (content ? content + "\n" : "") + newBlock, "utf8");
    console.log(`  ✔ Registered in ${label}: ${filePath}`);
  } catch (err) {
    console.error(`  ✖ Failed to update ${label} (${filePath}): ${err.message}`);
  }
}

upsertJsonMcp(process.env.GEMINI_CONFIG, "Gemini (Antigravity)", true);
upsertJsonMcp(process.env.CLAUDE_DESKTOP_CONFIG, "Claude Desktop", true);
upsertJsonMcp(process.env.CLAUDE_CODE_CONFIG, "Claude Code", false);
upsertTomlMcp(process.env.CHATGPT_CODEX_CONFIG, "ChatGPT / Codex");
'

    if [[ "$claude_was_running" == "true" ]]; then
        print_status "$BLUE" "Relaunching Claude Desktop..."
        open -a "Claude" >/dev/null 2>&1 || true
    fi

    print_status "$GREEN" "MCP server '$mcp_name' configured for Gemini, Claude, and ChatGPT!"
}

# Function to remove MCP server registrations from Claude, Gemini, and ChatGPT
remove_mcp_servers() {
    local mcp_name="apple-automation-mcp"
    local gemini_config="$HOME/.gemini/config/mcp_config.json"
    local claude_desktop_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    local claude_code_config="$HOME/.claude.json"
    local chatgpt_codex_config="$HOME/.codex/config.toml"

    print_status "$YELLOW" "Removing MCP server '$mcp_name' from Gemini, Claude, and ChatGPT..."

    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "$YELLOW" "[DRY RUN] Would remove $mcp_name from:"
        print_status "$BLUE" "  → Gemini:         $gemini_config"
        print_status "$BLUE" "  → Claude Desktop: $claude_desktop_config"
        print_status "$BLUE" "  → Claude Code:    $claude_code_config"
        print_status "$BLUE" "  → ChatGPT/Codex:  $chatgpt_codex_config"
        return 0
    fi

    if ! command -v node >/dev/null 2>&1; then
        return 0
    fi

    MCP_NAME="$mcp_name" \
    GEMINI_CONFIG="$gemini_config" \
    CLAUDE_DESKTOP_CONFIG="$claude_desktop_config" \
    CLAUDE_CODE_CONFIG="$claude_code_config" \
    CHATGPT_CODEX_CONFIG="$chatgpt_codex_config" \
    node -e '
const fs = require("fs");
const mcpName = process.env.MCP_NAME;

function removeJsonMcp(filePath, label) {
  if (!fs.existsSync(filePath)) return;
  try {
    const data = JSON.parse(fs.readFileSync(filePath, "utf8"));
    if (data.mcpServers && mcpName in data.mcpServers) {
      delete data.mcpServers[mcpName];
      fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n", "utf8");
      console.log(`  ✔ Removed from ${label}: ${filePath}`);
    }
  } catch (err) {
    console.error(`  ✖ Failed to update ${label} (${filePath}): ${err.message}`);
  }
}

function removeTomlMcp(filePath, label) {
  if (!fs.existsSync(filePath)) return;
  try {
    const content = fs.readFileSync(filePath, "utf8");
    const blockRegex = new RegExp(
      `\\n?\\[mcp_servers\\.${mcpName}(?:\\.[^\\]]+)?\\][\\s\\S]*?(?=\\n\\[|$)`,
      "g"
    );
    const updated = content.replace(blockRegex, "").trimEnd() + "\n";
    if (updated !== content) {
      fs.writeFileSync(filePath, updated, "utf8");
      console.log(`  ✔ Removed from ${label}: ${filePath}`);
    }
  } catch (err) {
    console.error(`  ✖ Failed to update ${label} (${filePath}): ${err.message}`);
  }
}

removeJsonMcp(process.env.GEMINI_CONFIG, "Gemini (Antigravity)");
removeJsonMcp(process.env.CLAUDE_DESKTOP_CONFIG, "Claude Desktop");
removeJsonMcp(process.env.CLAUDE_CODE_CONFIG, "Claude Code");
removeTomlMcp(process.env.CHATGPT_CODEX_CONFIG, "ChatGPT / Codex");
'
}

# Main execution
main() {
    print_status "$BLUE" "🚀 Shell Script & MCP Index Manager"
    print_status "$BLUE" "===================================="
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "$YELLOW" "DRY RUN MODE - No changes will be made"
    fi
    
    check_permissions
    
    if [[ "$REMOVE_MODE" == "true" ]]; then
        remove_symlinks
        remove_mcp_servers
    else
        setup_scripts
        setup_mcp_servers
    fi
}

# Run main function
main "$@"
