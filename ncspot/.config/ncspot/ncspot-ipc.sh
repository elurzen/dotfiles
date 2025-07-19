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
trap 'rm -f "$LOCKFILE"' EXIT INT TERM

Create command file
touch "$COMMAND_FILE"
echo "" > "$COMMAND_FILE"

# Single connection that handles both directions
{
    # Background process: read commands and send them
    # tail -f "$COMMAND_FILE" &
    tail -f "$COMMAND_FILE" | while read -r cmd; do
	    [[ -n "$cmd" ]] || continue
	    echo "DEBUG: Sending command: '$cmd'" >&2  # This goes to stderr so you see it
	    echo "$cmd"
	    echo "" > "$COMMAND_FILE"
    done
    
    # Keep connection alive
    cat
} | nc -U "$NCSPOT_SOCKET" | while read -r line; do
    # Parse incoming track info
    echo "$line" | jq -r '.playable.title + " - " + (.playable.album_artists | join(", "))' > "$CURRENT_TRACK"
done
