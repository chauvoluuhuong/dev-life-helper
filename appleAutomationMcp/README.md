# Apple Automation MCP Server (`apple-automation-mcp`)

An MCP (Model Context Protocol) server that provides tools for executing, validating, saving, and reusing **AppleScript** and **JXA (JavaScript for Automation)** scripts on macOS via `/usr/bin/osascript` and `/usr/bin/osacompile`.

## Exposed Tools

| Tool | Description |
| :--- | :--- |
| `run_applescript` | Execute inline AppleScript code via `osascript -l AppleScript`. Supports multi-line scripts, arguments (`on run argv`), timeouts, and output formatting (`human` or `source`). |
| `run_jxa` | Execute inline JavaScript for Automation (JXA) code via `osascript -l JavaScript`. Supports `function run(argv)` arguments, `Application(...)`, and the ObjC bridge. |
| `run_osascript_file` | Execute an AppleScript (`.applescript`, `.scpt`, `.scptd`) or JXA (`.js`, `.jxa`) file from disk with optional arguments. |
| `validate_osascript` | Compile-check inline AppleScript or JXA syntax via `osacompile` without executing the script. |
| `save_script` | Save an AppleScript or JXA script into `scripts/<name>_<description>.<ext>` (with syntax validation) so it can be reused later. |
| `list_saved_scripts` | List all saved `<name>_<description>` scripts available for reuse. |
| `run_saved_script` | Execute a saved script by its `name`, `<name>_<description>`, or filename, with optional `args`. |
| `get_saved_script` | Read the metadata and source code of a saved `<name>_<description>` script. |
| `delete_saved_script` | Delete a saved `<name>_<description>` script from the library. |

## Saved Scripts (`<name>_<description>`)

When you call `save_script` with `name` and `description`:
- The file is stored in `/Users/huong/dev-life-helper/appleAutomationMcp/scripts/` (or custom `APPLE_AUTOMATION_SCRIPTS_DIR` environment variable) as:
  - `<name>_<description>.applescript` (for `AppleScript`)
  - `<name>_<description>.js` (for `JavaScript` / JXA)
- You can execute it anytime via `run_saved_script` using just its `name` (e.g., `"greet-user"`) or full `<name>_<description>` identifier.

## Automated Installation (Claude, Gemini, ChatGPT)

From the repository root, run `setup.sh` to automatically build `apple-automation-mcp` and register it across **Gemini**, **Claude**, and **ChatGPT / Codex**:

```bash
# Preview changes
./setup.sh --dry-run

# Build and install for Gemini, Claude Desktop, Claude Code, and ChatGPT/Codex
./setup.sh --local

# Remove symlinks and unregister MCP servers
./setup.sh --remove
```

### Target Config Locations Managed by `setup.sh`
- **Gemini (Antigravity)**: `~/.gemini/config/mcp_config.json`
- **Claude Desktop**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Claude Code**: `~/.claude.json`
- **ChatGPT / Codex**: `~/.codex/config.toml`

## Manual Build & Test

```bash
npm install
npm run build
npm test
```
