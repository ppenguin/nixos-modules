#!/usr/bin/env bash

# from: https://www.instructables.com/Quick-and-Dirty-Dynamic-DNS-Using-GoDaddy/ (upgraded)

if [ $# -lt 3 ]; then
    echo "FATAL: At least three arguments required:"
    echo "Usage: $(basename "$0") <keypath> <secretpath> <hostname1@domain1> .. <hostnamen@domainn>"
    exit 1
fi

keypath="$1"
secretpath="$2"
shift 2
# remaining args are hostname@domain pairs

api_key="$(cat "$keypath")"
key_secret="$(cat "$secretpath")"
gdapikey="$api_key:$key_secret"

function log() {
    echo "$1"
}

function updateDns() {
    hostname="$1"
    domain="$2"
    newip="$3"

    fullDomain="$hostname.$domain"
    log "Check hostname for \"${fullDomain}\"..."

    dnsdata="$(curl -s -X GET -H "Authorization: sso-key ${gdapikey}" "https://api.godaddy.com/v1/domains/${domain}/records/A/${hostname}")"
    gdip="$(echo "$dnsdata" | cut -d ',' -f 1 | tr -d '"' | cut -d ":" -f 2)"

    log "Current External IP is $newip, GoDaddy DNS IP for \"${fullDomain}\" is $gdip"

    if [ "$gdip" != "$newip" ] && [ "$newip" != "" ]; then
        log "IP has changed! Updating DNS for \"${fullDomain}\" on GoDaddy..."
        curl -s -X PUT "https://api.godaddy.com/v1/domains/${domain}/records/A/${hostname}" \
        -H "Authorization: sso-key ${gdapikey}" \
        -H "Content-Type: application/json" \
        -d "[{\"data\": \"${newip}\"}]"
        log "Changed IP of \"${fullDomain}\" from \"${gdip}\" to \"${newip}\"."
    else
        log "IP for \"${fullDomain}\" not changed, nothing will be done."
    fi
}

myip="$(curl -s "https://api.ipify.org")"

for hd in "$@"; do
    IFS='@' read -r -a a <<<"$hd"
    # echo "host=${a[0]}  domain=${a[1]}"
    updateDns "${a[0]}" "${a[1]}" "$myip"
done