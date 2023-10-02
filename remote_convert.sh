#!/bin/bash

set -e

[[ "$#" -ne 2 ]] &&
    echo "USAGE: remote_convert REMOTE REMOTE_DIR" &&
    exit

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

prev_compressions="$(ssh "$remote" "find $folder -type f -name .converted -exec cat {} \;" | sort)"
curr_compression_targets="$(ssh "$remote" "find \"$folder\" -type f -name '*.mkv'" | sort)"

log "Previous failed attempts: $(comm -12 <(echo "$prev_compressions") <(echo "$curr_compression_targets") | wc -l)"
log "Previous successfull attempts: $(comm -13 <(echo "$curr_compression_targets") <(echo "$prev_compressions") | wc -l)"


readarray -t new_compression_targets < <(comm -13 <(echo "$prev_compressions") <(echo "$curr_compression_targets"))

log "Current compression targets: ${#new_compression_targets[@]}"


for remote_file in "${new_compression_targets[@]}"; do
    remote_folder="$(dirname "$remote_file")"

    filename="$(basename "$remote_file")"

    log "Started fetching: $remote_file"
    rsync -av --progress "$remote":"$remote_file" .
    log "Ended fetching: $remote_file"

    tmp_filename="tmp_${filename}"

    log "Started converting: $filename"

    HandBrakeCLI \
        -i "$filename" \
        -o "$tmp_filename" \
        --preset 'HQ 1080p30 Surround' \
        --maxHeight 2160 \
        --maxWidth 3840 \
        --all-audio \
        --all-subtitles \
        -x threads="$(nproc)" \
        --verbose=1 < /dev/null

    log "Ended converting: $filename"

    log "Size $(size "$filename") -> $(size "$tmp_filename")"

    if [[ "$(stat -c '%s' "$tmp_filename")" -lt "$(stat -c '%s' "$filename")" ]]; then
        log "Compression was a success"

        log "Start Copying temporary compressed to remote"
        rsync -av --progress "${tmp_filename}" "${remote}:${remote_folder}"
        log "Ended Copying temporary compressed to remote"

        ssh -n "$remote" rm -v \""$remote_file"\"
        ssh -n "$remote" mv -v \""${remote_folder}/${tmp_filename}"\" \""$remote_file"\"

        log "Replaced uncompressed on remote: $remote_file"
    else
        log "Compression did not compress"
    fi

    remote_log="$(dirname "$remote_file")/.converted"
    ssh -n "$remote" "echo \"$remote_file\" >> \"$remote_log\""

    rm "$filename" "$tmp_filename"
    log "Deleted local files"
    echo

done
