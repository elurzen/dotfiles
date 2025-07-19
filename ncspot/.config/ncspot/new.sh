#!/bin/zsh
NCSPOT_SOCKET="/run/user/1000/ncspot/ncspot.sock"
COMMAND_FILE="/tmp/ncspot-commands"
CURRENT_TRACK="/tmp/current-track"
LOCKFILE="/tmp/ncspot-ipc.lock"

# Prevent multiple instances
if [ -f "$LOCKFILE" ]; then
    echo "ncspot-ipc already running (PID: $(cat "$LOCKFILE"))"
    exit 0
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# Create command file
touch "$COMMAND_FILE"
echo "" > "$COMMAND_FILE"

# Single connection that handles both directions
send_commands() {
    tail -f "$COMMAND_FILE" | while read -r cmd; do
        [[ -n "$cmd" ]] || continue
        echo "DEBUG: Sending command: '$cmd'" >&2
        echo "$cmd" >&3  # Send to file descriptor 3
        echo "" > "$COMMAND_FILE"
    done
}

send_commands &
SENDER_PID=$!

# Main connection - both send and receive
exec 3> >(nc -U "$NCSPOT_SOCKET")
nc -U "$NCSPOT_SOCKET" | while read -r line; do
    # Parse incoming track info
    if echo "$line" | jq -e '.playable' >/dev/null 2>&1; then
        echo "$line" | jq -r '.playable.title + " - " + (.playable.album_artists | join(", "))' > "$CURRENT_TRACK"
    fi
done

# Cleanup
kill $SENDER_PID 2>/dev/null
exec 3>&-
