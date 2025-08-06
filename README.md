# Scripts code that make my life easier

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
