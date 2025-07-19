#!/bin/bash

CURRENT_TRACK="/tmp/current-track"
COMMAND_FILE="/tmp/ncspot-commands"

# Function to send commands to ncspot
send_command() {
    echo "$1" >> "$COMMAND_FILE"
}

# Function to escape markup characters
escape_markup() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# Function to output current track info
output_track() {
    if [ -f "$CURRENT_TRACK" ]; then
        track=$(cat "$CURRENT_TRACK" 2>/dev/null)
	track=$(escape_markup "$track")
        if [ -n "$track" ] && [ "$track" != " - " ]; then
            # Truncate if too long
            if [ ${#track} -gt 50 ]; then
                track="${track:0:47}..."
            fi
            echo "{\"text\":\"♪ $track\", \"tooltip\":\"$track\", \"class\":\"playing\"}"
        else
            echo "{\"text\":\"♪ Not playing\", \"tooltip\":\"ncspot not active\", \"class\":\"stopped\"}"
        fi
    else
        echo "{\"text\":\"♪ No track\", \"tooltip\":\"Track file not found\", \"class\":\"error\"}"
    fi
}

# Handle click events
case "$1" in
    "playpause")
        send_command "playpause"
        ;;
    "save")
        send_command "save current"
        ;;
    # "prev") 
    #     send_command "previous"
    #     ;;
    *)
        # Default: read current track and display it
        output_track
        ;;
esac
