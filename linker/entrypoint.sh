#!/usr/bin/env bash
set -e

SRC_ROOT="${SRC_ROOT:-/source}"
DST_ROOT="${DST_ROOT:-/target}"
SCAN_INTERVAL="${SCAN_INTERVAL:-600}"  # seconds (default 10 minutes)

TYPES=("mangas" "comics" "web-novels" "light-novels")

echo "📂 Watching directories under: $SRC_ROOT"
for type in "${TYPES[@]}"; do
    echo " - $SRC_ROOT/$type → $DST_ROOT/$type"
    mkdir -p "$DST_ROOT/$type"
done

# Function to hardlink files from src to dst
link_files_in_folder() {
    local src_folder="$1"
    local dst_folder="$2"

    mkdir -p "$dst_folder"

    find "$src_folder" -type f | while read -r src_file; do
        rel_path="${src_file#$src_folder/}"
        dst_file="$dst_folder/$rel_path"

        dst_dir=$(dirname "$dst_file")
        mkdir -p "$dst_dir"

        if [ ! -e "$dst_file" ]; then
            ln "$src_file" "$dst_file"
            echo "🔗 Linked: $dst_file"
        fi
    done
}

# Link full book directory
link_book() {
    full_path="$1"
    rel_path="${full_path#$SRC_ROOT/}"        # e.g., mangas/SITE/BOOK_TITLE
    type=$(echo "$rel_path" | cut -d/ -f1)
    book=$(basename "$full_path")

    if [[ ! " ${TYPES[*]} " =~ " $type " ]]; then
        echo "❌ Skipping untracked type: $type"
        return
    fi

    src_book="$full_path"
    dst_book="$DST_ROOT/$type/$book"

    if [ ! -d "$src_book" ]; then
        return
    fi

    echo "📚 Linking book '$book'"
    link_files_in_folder "$src_book" "$dst_book"
}

# Watcher: runs in background
start_watcher() {
    for type in "${TYPES[@]}"; do
        src_dir="$SRC_ROOT/$type"

        inotifywait -m -r -e create,move --format '%w%f' "$src_dir" |
        while read -r path; do
            rel="${path#$SRC_ROOT/}"
            depth=$(echo "$rel" | awk -F/ '{print NF}')
            if [ -d "$path" ] && [ "$depth" -eq 3 ]; then
                link_book "$path"
            fi
        done &
    done
}

# Periodic rescan loop
start_rescanner() {
    while true; do
        echo "🔁 Running periodic rescan..."

        for type in "${TYPES[@]}"; do
            find "$SRC_ROOT/$type" -mindepth 2 -maxdepth 2 -type d | while read -r book_folder; do
                link_book "$book_folder"
            done
        done

        sleep "$SCAN_INTERVAL"
    done
}

# Start both in parallel
start_watcher
start_rescanner

# Wait to keep container running
wait