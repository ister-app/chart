# Scenario: HLS streaming with a real transcode.
#
# Fetches the master playlist for a movie with a stream token, follows it to a variant
# playlist and downloads the first segment — which forces ffmpeg to actually transcode
# inside the cluster. Runs after the scan scenario so it does not compete with ffprobe
# for the node's CPUs.

echo "--> Creating a stream token"
stream_token=$(gql 'mutation { createStreamToken { token } }' | jq -r '.data.createStreamToken.token // empty')
[ -n "$stream_token" ] || fail "createStreamToken returned no token"

echo "--> Picking a movie's media file"
MOVIE_MEDIA_FILE_ID=$(gql '{ movies(size: 1) { content { name mediaFile { id } } } }' \
  | jq -r '.data.movies.content[0].mediaFile[0].id // empty')
[ -n "$MOVIE_MEDIA_FILE_ID" ] || fail "no movie media file found"
export MOVIE_MEDIA_FILE_ID
echo "    mediaFileId: $MOVIE_MEDIA_FILE_ID"

# The server generates the playlists on the first request and holds the request until they
# exist, which on a busy runner (the scan's per-file analysis is still running) can exceed
# its own wait and come back as a 5xx. Poll rather than fail on the first answer; the
# ingress variants of the e2e run this scenario straight after the scan.
echo "--> Fetching the master playlist (up to ${MASTER_TIMEOUT_SECONDS:-300}s)"
fetch_master() {
  master=$(api_curl "$API/hls/$MOVIE_MEDIA_FILE_ID/master.m3u8?token=$stream_token" 2>/dev/null) || return 1
  echo "$master" | head -1 | grep -q '#EXTM3U'
}
poll_until "${MASTER_TIMEOUT_SECONDS:-300}" "master playlist" fetch_master

# The master playlist references variant playlists; their URIs already carry ?token=.
variant_path=$(echo "$master" | grep -v '^#' | grep '\.m3u8' | head -1)
[ -n "$variant_path" ] || fail "no variant playlist in master: $master"
echo "    variant: $variant_path"

# Playlist URIs are relative to the master playlist's directory.
hls_url() { # path-or-uri
  case "$1" in
    http*) echo "$1" ;;
    *) echo "$API/hls/$MOVIE_MEDIA_FILE_ID/$1" ;;
  esac
}

echo "--> Waiting for the first transcoded segment (up to ${TRANSCODE_TIMEOUT_SECONDS:-180}s)"
first_segment_plays() {
  variant=$(api_curl "$(hls_url "$variant_path")") || return 1
  segment_path=$(echo "$variant" | grep -v '^#' | grep -E '\.(ts|vtt)' | grep '\.ts' | head -1)
  [ -n "$segment_path" ] || { echo "    no segment in variant playlist yet"; return 1; }
  seg_file="${TMPDIR:-/tmp}/ister-e2e-segment.ts"
  api_curl -o "$seg_file" "$(hls_url "$segment_path")" || return 1
  size=$(stat -c%s "$seg_file")
  first_byte=$(head -c1 "$seg_file" | od -An -tu1 | tr -d ' ')
  echo "    segment: $segment_path size=$size first_byte=$first_byte"
  # 0x47 = 71, the MPEG-TS sync byte: proves this is real transcoded video, not an error page.
  [ "$size" -gt 0 ] && [ "$first_byte" = "71" ]
}
poll_until "${TRANSCODE_TIMEOUT_SECONDS:-180}" "first transcoded HLS segment" first_segment_plays

echo "--> Streaming scenario passed"
