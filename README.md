# Scripts code that make my life easier

## 🚀 Quick Start - Setup All Scripts Globally

Before using any individual scripts, run the `setup.sh` script to make all scripts executable and globally accessible:

### Step 1: Make setup.sh executable

```bash
chmod +x setup.sh
```

### Step 2: Run the setup script

```bash
# Preview what will be done (recommended first)
./setup.sh --dry-run

# Set up all scripts globally (no sudo required)
./setup.sh --local

# Or use system-wide installation (requires sudo)
sudo ./setup.sh
```

### What setup.sh does

- 🔍 **Finds all `.sh` files** recursively in the project
- ⚡ **Makes them executable** with `chmod +x`
- 🌐 **Creates global symlinks** so you can run scripts from anywhere
- 🤖 **Builds and registers `apple-automation-mcp`** across **Gemini** (`~/.gemini/config/mcp_config.json`), **Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`), **Claude Code** (`~/.claude.json`), and **ChatGPT / Codex** (`~/.codex/config.toml`)
- 🛡️ **Safe operation** with dry-run mode to preview changes

### Available options

- `--dry-run`: Preview changes without making them
- `--local`: Use `~/.local/bin` (no sudo needed)
- `--remove`: Remove all created symlinks and unregister MCP servers
- `--help`: Show usage information

### After setup, you can run scripts globally:

```bash
# Instead of ./killProcessUsingPort.sh 3000
killProcessUsingPort 3000

# Instead of ./dataMigration/dataMigration.sh
dataMigration

# Instead of ./dockerUtils/docker-manager.sh
docker-manager
```

---

## appleAutomationMcp (`apple-automation-mcp`)

An MCP (Model Context Protocol) server providing tools to execute, syntax-check, save, and reuse **AppleScript** and **JXA (JavaScript for Automation)** scripts on macOS via `osascript` and `osacompile`.

See [appleAutomationMcp/README.md](./appleAutomationMcp/README.md) for full documentation.

### Tools Provided

| Tool | Description |
| :--- | :--- |
| `run_applescript` | Execute inline AppleScript code via `osascript -l AppleScript`. |
| `run_jxa` | Execute inline JavaScript for Automation (JXA) code via `osascript -l JavaScript`. |
| `run_osascript_file` | Execute an `.applescript`, `.scpt`, `.scptd`, or `.js` file from disk. |
| `validate_osascript` | Compile-check AppleScript or JXA syntax via `osacompile` without executing it. |
| `save_script` | Save a script as `<name>_<description>.<ext>` in `appleAutomationMcp/scripts/` for reuse. |
| `list_saved_scripts` | List all saved `<name>_<description>` scripts available for reuse. |
| `run_saved_script` | Run a saved script by its `name` or `<name>_<description>` filename. |
| `get_saved_script` | Read the metadata and source code of a saved script. |
| `delete_saved_script` | Delete a saved script from the library. |

---

## killProcessUsingPort.sh

A utility script to kill processes using a specific port. Useful when you need to free up a port that's already in use.

### Usage

```bash
./killProcessUsingPort.sh <port_number>
```

### Examples

```bash
# Kill process using port 4000
./killProcessUsingPort.sh 4000

# Kill process using port 3000
./killProcessUsingPort.sh 3000

# Kill process using port 8080
./killProcessUsingPort.sh 8080
```

### What it does

1. **Validates input**: Checks if a port number is provided and validates it's a number
2. **Finds processes**: Uses `lsof -i :<port>` to find what's using the specified port
3. **Kills processes**: Uses `kill -9 <pid>` to forcefully terminate the processes
4. **Handles multiple processes**: Can kill multiple processes if they're all using the same port
5. **Verifies success**: Checks if the port is now free after killing the process(es)

### Features

- Input validation and error handling
- Clear feedback about what's happening
- Handles multiple processes on the same port
- Verification that the port is now free
- Graceful handling when no process is found using the port

### Requirements

- macOS/Linux with `lsof` command available
- Bash shell
