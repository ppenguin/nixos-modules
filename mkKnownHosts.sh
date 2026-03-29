#!/usr/bin/env bash

# TODO: (?) re-implement in nix and include as a special flake output (is this practical/possible?)
KHF="hosts/known_hosts"
KHWF="hosts/known_hosts_wanted.txt"
TKHF=".known_hosts.tmp"
mv "$KHF" "$TKHF"

while IFS= read -r h; do
	echo "Scanning $h..."
	ssh-keyscan "$h" 2>/dev/null | awk '$1 ~ /^'"$h"'$/ { print $0 }' >>"$TKHF"
done <"$KHWF"

sort -u <"${TKHF}" >"${KHF}" && rm -f "${TKHF}"
