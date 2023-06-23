#!/bin/bash

set -e

remote="$1"
folder="$2"

LOGFILE=log_compression_"$(date '+%F_%T')"

log(){
    touch "$LOGFILE"
    echo -e "$(date '+%F %T')\t$1"
    echo -e "$(date '+%F %T')\t$1" >> "$LOGFILE"
}

size(){
    du -h "$1" | awk '{ print $1}'
}

while read -r remote_file; do
    local_file="$(basename "$remote_file")"

    remote_log="$(dirname "$remote_file")/.converted"
    if ssh -nq "$remote" "test -e \"$remote_log\""; then
        if ssh -n "$remote" "cat \"$remote_log\" | grep -qxF \"$remote_file\""; then
            log "Already attempted to convert: $remote_file"
            echo
            continue
        fi
    fi

    log "Started fetching: $remote_file"
    rsync -av --progress "$remote":"$remote_file" .
    log "Ended fetching: $remote_file"

    dest="${local_file%.mkv}.mp4"

    log "Started converting: $local_file"

        # --preset 'Fast 1080p30' \
    HandBrakeCLI \
        -i "$local_file" \
        -o "$dest" \
        --preset 'HQ 1080p30 Surround' \
        --maxHeight 2160 \
        --maxWidth 3840 \
        --all-audio \
        --all-subtitles \
        -x threads=16 \
        --verbose=1 < /dev/null
    log "Ended converting: $local_file"

    log "Size $(size "$local_file") -> $(size "$dest")"

    if [[ "$(stat -c '%s' "$dest")" -lt "$(stat -c '%s' "$local_file")" ]]; then
        log "Compression was a success"

        log "Start Copying compressed to remote"
        rsync -av --progress "$dest" "$remote":"$(dirname "$remote_file")"
        log "Ended Copying compressed to remote"

        ssh -n "$remote" rm \""$remote_file"\"
        log "Removed uncompressed on remote: $remote_file"
    else
        log "Compression did not compress"
    fi

    ssh -n "$remote" "echo \"$remote_file\" >> \"$remote_log\""

    rm "$local_file" "$dest"
    log "Deleted local files"
    echo

done < <(ssh "$remote" "find \"$folder\" -type f -name '*.mkv'" | sort)
