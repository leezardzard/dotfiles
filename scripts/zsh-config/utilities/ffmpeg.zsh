###############################################################################
# Add FFMPEG function
###############################################################################
compress_video() {
    local source_file=$1
    
    if [[ -z "$source_file" ]]; then
        echo "❌ Error: Source file is required."
        echo "Usage: compress_video <source_file>"
        return 1
    fi
    
    # Automatically generate destination filename by replacing extension with .mp4
    local destination_file="${source_file%.*}.mp4"

    ffmpeg -i "$source_file" -vcodec libx264 -preset fast -crf 20 -y -vf "scale=1920:trunc(ow/a/2)*2" -acodec libmp3lame -ab 128k "$destination_file"
} 