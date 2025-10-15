#!/usr/bin/env bash
set -e

SRC_ROOT="${SRC_ROOT:-/source}"
DST_ROOT="${DST_ROOT:-/target}"

TYPES=("mangas" "comics" "web-novels" "light-novels")

echo "📂 Watching directories under: $SRC_ROOT"
for type in "${TYPES[@]}"; do
    echo " - $SRC_ROOT/$type → $DST_ROOT/$type"
    mkdir -p "$DST_ROOT/$type"
done

# Function to link new book folders
link_book() {
    full_path="$1"
    rel_path="${full_path#$SRC_ROOT/}"        # e.g., mangas/SITE/BOOK_TITLE
    type=$(echo "$rel_path" | cut -d/ -f1)     # e.g., mangas
    book=$(basename "$full_path")             # e.g., BOOK_TITLE

    # Validate
    if [[ ! " ${TYPES[*]} " =~ " $type " ]]; then
        echo "❌ Skipping untracked type: $type"
        return
    fi

    src_book="$full_path"
    dst_book="$DST_ROOT/$type/$book"

    if [ ! -d "$src_book" ]; then
        echo "⚠️ Source is not a directory: $src_book"
        return
    fi

    if [ -e "$dst_book" ]; then
        echo "⚠️ Already exists: $dst_book"
        return
    fi

    echo "📚 Linking '$book' → $dst_book"
    mkdir -p "$dst_book"
    cp -al "$src_book"/. "$dst_book"/
}

# Watch each type independently
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

wait