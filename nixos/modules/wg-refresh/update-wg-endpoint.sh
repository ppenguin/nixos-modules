#!/bin/env bash
INTERFACE="$1"
PEER_PUBLIC_KEY="$2"
ENDPOINT="$3"

# Extract DNS name and port from the full endpoint
DNS_NAME="${ENDPOINT%:*}" # Extract DNS name from Endpoint
PORT="${ENDPOINT##*:}"    # Extract port from Endpoint

# Get the current IP from the WireGuard status
CURRENT_IP="$(wg show "$INTERFACE" endpoints | awk -F'[[:space:]:]' '/'"$PEER_PUBLIC_KEY"'/{ print $2 }')"

# Resolve the current IP of the DNS name
RESOLVED_IP=$(dig +short "$DNS_NAME" | tail -n 1)

# Check if the DNS resolved IP differs from the current IP
if [ "$RESOLVED_IP" != "$CURRENT_IP" ] && [ -n "$RESOLVED_IP" ]; then
	echo "IP has changed from \"$CURRENT_IP\" to \"$RESOLVED_IP\". Updating WireGuard Endpoint..."

	# Update the WireGuard endpoint
	wg set "$INTERFACE" peer "$PEER_PUBLIC_KEY" endpoint "$RESOLVED_IP:$PORT"

	echo "WireGuard endpoint updated to $RESOLVED_IP:$PORT."
else
	echo "IP address has not changed or could not resolve DNS for $DNS_NAME. No update."
fi
