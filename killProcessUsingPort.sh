#!/bin/bash

# killProcessUsePort.sh - Kill process using a specific port
# Usage: ./killProcessUsePort.sh <port_number>

# Check if port number is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <port_number>"
    echo "Example: $0 4000"
    exit 1
fi

PORT=$1

# Check if port is a valid number
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: Port must be a number"
    exit 1
fi

echo "Looking for process using port $PORT..."

# Find process using the port
PROCESS_INFO=$(lsof -i :$PORT -t)

if [ -z "$PROCESS_INFO" ]; then
    echo "No process found using port $PORT"
    exit 0
fi

echo "Found process(es) using port $PORT:"
lsof -i :$PORT

echo ""
echo "Killing process(es)..."

# Kill each process found
for PID in $PROCESS_INFO; do
    echo "Killing process $PID..."
    kill -9 $PID
    
    if [ $? -eq 0 ]; then
        echo "Successfully killed process $PID"
    else
        echo "Failed to kill process $PID"
    fi
done

echo ""
echo "Verifying port $PORT is now free..."
if lsof -i :$PORT >/dev/null 2>&1; then
    echo "Warning: Port $PORT is still in use"
else
    echo "Port $PORT is now free"
fi
