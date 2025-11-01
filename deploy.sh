#!/usr/bin/env bash

# Script execution safety settings:
# -E: trap inheritance by functions
# -e: exit immediately on any error
# -u: error on unset variables
# -o pipefail: return exit code of the last failed command in pipeline
set -Eeuo pipefail

# Explicit PATH definition to avoid binary lookup issues
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"


# Project variables
PROJECT_NAME="hugo"           # Project/Hugo service name
PROJECT_WEB="angie"           # Project web server name
PROJECT_DIR="/opt/hugo"       # Project directory


# Logging settings
LOG_TO_STDOUT=1       # output logs to stdout
LOG_TO_FILE=0         # log to file (<script_name>.log)
LOG_TO_SYSLOG=0       # log to syslog with <script_name> tag


# Main script variables
SCRIPT_PID=$$    # Current script PID
# Absolute path to script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd -P)
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"    # Script name
SCRIPT_LOG="${SCRIPT_DIR}/${SCRIPT_NAME%.*}.log" # Log file
SCRIPT_LOG_PREFIX='[%Y-%m-%d %H:%M:%S.%3N]'     # Timestamp format for logs
SCRIPT_LOCK="${SCRIPT_DIR}/${SCRIPT_NAME%.*}.lock" # Lock file


# Cleanup function for exit or errors
cleanup() {
    trap - SIGINT SIGTERM SIGHUP SIGQUIT ERR EXIT  # reset traps

    # Close lock file descriptor if opened
    [[ -n "${fd_lock-}" ]] && exec {fd_lock}>&-

    # Remove lock file if it belongs to current process
    if [[ -f "$SCRIPT_LOCK" && $(< "$SCRIPT_LOCK") -eq $SCRIPT_PID ]]; then
        rm -f "$SCRIPT_LOCK"
    fi
}


# Logging function
logging() {
    while IFS= read -r line; do
        # Format log line with timestamp
        log_line="$(date +"${SCRIPT_LOG_PREFIX}") - $line"

        # Output to stdout if enabled
        if (( "$LOG_TO_STDOUT" )); then echo "$log_line"; fi

        # Log to file if enabled
        if (( "$LOG_TO_FILE" )); then echo "$log_line" >> "$SCRIPT_LOG"; fi

        # Log to syslog if enabled
        if (( "$LOG_TO_SYSLOG" )); then logger -t "$SCRIPT_NAME" -- "$line"; fi
    done
}


# Script locking function to prevent concurrent execution
lock_script() {
    # Open lock file descriptor for writing
    exec {fd_lock}>> "${SCRIPT_LOCK}"

    # Try to acquire exclusive lock, exit if failed
    if ! flock -n "$fd_lock"; then
        echo "Another script instance is already running, exiting..."
        exit 1
    fi

    # Write current script PID to lock file
    echo "$SCRIPT_PID" > "$SCRIPT_LOCK"
}


# Main deploy function
deploy() {
    echo "Check git and docker binaries"
    # Check if git and docker are available
    if ! command -v git; then echo >&2 "Git is not installed"; fi
    if ! command -v docker; then echo >&2 "Docker is not installed"; fi

    # Change to project directory if writable
    if [[ -w "$PROJECT_DIR" ]]; then
        cd "$PROJECT_DIR"
    else
        echo "No such directory: $PROJECT_DIR"
        exit 1
    fi

    # If git repository exists - update it
    if [[ -d .git ]]; then
        echo "Pull changes from main branch"
        git checkout main
        git fetch --all
        git reset --hard origin/main
    else
        echo "No git files found"
        exit 1
    fi

    echo "Restart $PROJECT_NAME service"
    #systemctl restart "$PROJECT_NAME"   # systemctl can be used
    docker compose up hugo               # start service via Docker Compose

    sleep 3  # short timeout

    echo "Waiting for site generation..."
    # Wait for Hugo service to finish
    while docker compose ps --services --filter "status=running" | grep -q "^$PROJECT_NAME$"; do
        echo "Waiting for site generation..."
        sleep 1
    done

    echo 'Done!'

    # Check if web server is running
    echo "Checking if webserver container is running"
    if docker compose ps --services --filter "status=running" | grep -q "^$PROJECT_WEB$"; then
        echo 'Up!'
    else
        echo "Container with $PROJECT_WEB webserver is not running"
        exit 1
    fi

    sleep 3

    # Output recent service logs
    echo "Some output of running service"
    LOG=$(journalctl -n 50 --no-pager -u "$PROJECT_NAME")
    echo "------------------------------"
    echo "$LOG"
    echo "------------------------------"
}


# Main script function
main() {
    # Trap signals and errors, call cleanup
    trap 'RC=$?; cleanup; exit $RC' SIGINT SIGHUP SIGTERM SIGQUIT ERR EXIT
    # Redirect stdout and stderr to logging function
    exec > >(logging) 2>&1
    lock_script   # lock script
    deploy        # run deploy
}


# Entry point
if main; then
    sleep 1
    echo "Deploy completed successfully"
    exit 0
else
    echo "Deploy failed"
    exit 1
fi
