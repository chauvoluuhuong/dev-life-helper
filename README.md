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
- 🛡️ **Safe operation** with dry-run mode to preview changes

### Available options

- `--dry-run`: Preview changes without making them
- `--local`: Use `~/.local/bin` (no sudo needed)
- `--remove`: Remove all created symlinks
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
