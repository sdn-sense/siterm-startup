#!/bin/bash
# Read all env variables for the process.
set -a
source /etc/environment || true
set +a

AUTO_TLS_RENEWAL="${AUTO_TLS_RENEWAL:-true}"
SRC_CERT="/etc/secret-mount/tls.crt"
SRC_KEY="/etc/secret-mount/tls.key"
GRID_CERT="/etc/grid-security/hostcert.pem"
GRID_KEY="/etc/grid-security/hostkey.pem"

CHECK_INTERVAL=3600
FORCE_COMPARE_INTERVAL=10800

last_hash=""
baseline=false
last_compare=0

hash_sources() {
    sha256sum "$SRC_CERT" "$SRC_KEY" 2>/dev/null | sha256sum | awk '{print $1}'
}

files_diff() {
    ! cmp -s "$1" "$2"
}

copy_tls() {
    cp -f "$SRC_CERT" "$GRID_CERT"
    cp -f "$SRC_KEY"  "$GRID_KEY"
}

print_dateline() {
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` $1 "
}

if [[ "$AUTO_TLS_RENEWAL" != "true" ]]; then
    print_dateline "[tls-watch] AUTO_TLS_RENEWAL disabled"
    while true; do sleep "$CHECK_INTERVAL"; done
fi
print_dateline "[tls-watch] TLS watcher started"
copy_tls
while true; do

    now=$(date +%s)
    [[ -f "$SRC_CERT" && -f "$SRC_KEY" ]] || {
        sleep "$CHECK_INTERVAL"
        continue
    }
    print_dateline "[tls-watch] Checking TLS certs"
    current_hash="$(hash_sources)"
    changed=false
    # Detect source change
    if [[ "$current_hash" != "$last_hash" ]]; then
        print_dateline "[tls-watch] Source TLS change detected"
        changed=true
    fi
    # Periodic forced comparison
    if (( now - last_compare >= FORCE_COMPARE_INTERVAL )); then
        last_compare="$now"

        for pair in \
            "$SRC_CERT:$GRID_CERT" \
            "$SRC_KEY:$GRID_KEY";
        do
            IFS=: read -r src dst <<< "$pair"
            if [[ ! -f "$dst" ]] || files_diff "$src" "$dst"; then
                changed=true
                break
            fi
        done
    fi
    if [[ "$changed" == "true" ]]; then
        print_dateline "[tls-watch] TLS change detected, syncing certs"
        last_hash="$current_hash"
        if [[ "$baseline" == "true" ]]; then
            print_dateline "[tls-watch] TLS change present, please restart container"
        else
            print_dateline "[tls-watch] Baseline established (no restart)"
            baseline=true
            changed=false
        fi
    fi
    sleep "$CHECK_INTERVAL"
done

