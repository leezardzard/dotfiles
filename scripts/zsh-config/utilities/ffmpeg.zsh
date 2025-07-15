###############################################################################
# Add FFMPEG function
###############################################################################
compress_video() {
    local source_file=$1
    local destination_file=$2

    ffmpeg -i "$source_file" -vcodec libx264 -preset fast -crf 20 -y -vf "scale=1920:trunc(ow/a/2)*2" -acodec libmp3lame -ab 128k "$destination_file"
} 