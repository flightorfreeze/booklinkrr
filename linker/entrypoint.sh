#!/usr/bin/env bash
set -e

SRC_ROOT="${SRC_ROOT:-/source}"
DST_ROOT="${DST_ROOT:-/target}"
SCAN_INTERVAL="${SCAN_INTERVAL:-600}"

TYPES=("mangas" "comics" "web-novels" "light-novels" "webtoons")

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

    find "$src_folder" -type f 2>/dev/null | while read -r src_file; do
        rel_path="${src_file#$src_folder/}"
        dst_file="$dst_folder/$rel_path"

        dst_dir=$(dirname "$dst_file")
        mkdir -p "$dst_dir"

        if [ ! -e "$dst_file" ]; then
            if ln "$src_file" "$dst_file" 2>/dev/null; then
                echo "🔗 Linked: $dst_file"
            else
                echo "❌ Failed to link: $src_file (check if source and target are on same filesystem)"
            fi
        fi
    done
}

# Link book directory: /source/type/site/book → /target/type/book
link_book() {
    local book_path="$1"
    
    # Extract components from path
    local rel_path="${book_path#$SRC_ROOT/}"  # e.g., "mangas/Bato (EN)/That Time I Got Reincarnated"
    local type=$(echo "$rel_path" | cut -d/ -f1)
    local book_title=$(basename "$book_path")
    
    if [[ ! " ${TYPES[*]} " =~ " $type " ]]; then
        echo "❌ Skipping untracked type: $type"
        return
    fi

    if [ ! -d "$book_path" ]; then
        return
    fi

    # Skip the site directory, link directly to target/type/book_title
    local dst_book="$DST_ROOT/$type/$book_title"

    echo "📚 Linking book: $type/$book_title"
    link_files_in_folder "$book_path" "$dst_book"
}

# Watcher: monitors for new directories
start_watcher() {
    for type in "${TYPES[@]}"; do
        src_dir="$SRC_ROOT/$type"
        
        if [ ! -d "$src_dir" ]; then
            echo "⚠️  Warning: $src_dir does not exist, skipping watch"
            continue
        fi

        (
            inotifywait -m -r -e create,moved_to --format '%w%f' "$src_dir" 2>/dev/null |
            while read -r path; do
                if [ -d "$path" ]; then
                    # Check if this is a book directory (3 levels deep: type/site/book)
                    local rel="${path#$SRC_ROOT/}"
                    local depth=$(echo "$rel" | tr -cd '/' | wc -c)
                    
                    if [ "$depth" -eq 2 ]; then
                        # This is a book directory at the right depth
                        link_book "$path"
                    fi
                fi
            done
        ) &
    done
}

# Periodic rescan loop
start_rescanner() {
    while true; do
        echo "🔁 Running periodic rescan at $(date)"

        for type in "${TYPES[@]}"; do
            src_type_dir="$SRC_ROOT/$type"
            
            if [ ! -d "$src_type_dir" ]; then
                continue
            fi

            # Find all book directories (exactly 2 levels deep under type/)
            find "$src_type_dir" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | while read -r book_folder; do
                link_book "$book_folder"
            done
        done

        sleep "$SCAN_INTERVAL"
    done
}

# Initial scan on startup
echo "🚀 Running initial scan..."
for type in "${TYPES[@]}"; do
    src_type_dir="$SRC_ROOT/$type"
    if [ -d "$src_type_dir" ]; then
        find "$src_type_dir" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | while read -r book_folder; do
            link_book "$book_folder"
        done
    fi
done

# Start both watchers in background
start_watcher
start_rescanner &

# Keep container running
echo "✅ BookLinker is running. Press Ctrl+C to stop."
wait