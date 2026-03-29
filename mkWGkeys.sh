#!/usr/bin/env bash

if [ $# -lt 1 ]; then
    echo "secrets yaml required"
    exit 1
fi

ofile="$1"

if [ ! -f "$1" ]; then
    printf 'secrets config "%s" does not exist\n' "$1"
    ofile="/dev/stdout"
fi

wgpriv=.wgpriv
wgpub=.wgpub

nix-shell -p wireguard-tools --run "wg genkey >$wgpriv"
nix-shell -p wireguard-tools --run "wg pubkey <$wgpriv >$wgpub"
printf "\nwireguard:\n  private: %s\n  public: %s\n" "$(<$wgpriv)" "$(<$wgpub)" >>"$ofile"
rm -f "$wgpriv" "$wgpub"
