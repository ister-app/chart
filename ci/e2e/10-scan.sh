# Scenario: scanning indexes every library type.
#
# Triggers the scan and polls until shows, movies, albums, books AND comic series all
# have rows, then waits for the per-file analysis that runs behind those rows before
# asserting the deeper structure the scanners are responsible for: audiobook chapters,
# media-overlay detection on the read-aloud epub, comic page counts.

echo "--> Triggering the library scan"
# scanLibraries is gated on ROLE_admin, so it needs the admin token. (Server 3.0.0
# renamed scanLibrary to scanLibraries and gave it an optional libraryId; without one
# it scans every library, which is what this suite wants.)
scan=$(gql 'mutation { scanLibraries }' "$ADMIN_TOKEN")
echo "$scan" | jq -e '.data.scanLibraries == true' >/dev/null \
  || fail "scanLibraries did not return true: $scan"

# The scan is asynchronous (RabbitMQ events, then ffprobe per file). Poll rather than
# sleep — a fixed sleep is either flaky or slow.
echo "--> Waiting for the scanner to index all media types (up to ${SCAN_TIMEOUT_SECONDS:-300}s)"
scan_counts() {
  shows=$(gql '{ shows(size: 1) { totalElements } }' | jq -r '.data.shows.totalElements // 0')
  movies=$(gql '{ movies(size: 1) { totalElements } }' | jq -r '.data.movies.totalElements // 0')
  albums=$(gql '{ albums(size: 1) { totalElements } }' | jq -r '.data.albums.totalElements // 0')
  books=$(gql '{ books(size: 1) { totalElements } }' | jq -r '.data.books.totalElements // 0')
  series=$(gql '{ series(size: 1) { totalElements } }' | jq -r '.data.series.totalElements // 0')
  echo "    shows=$shows movies=$movies albums=$albums books=$books series=$series"
  [ "$shows" -gt 0 ] && [ "$movies" -gt 0 ] && [ "$albums" -gt 0 ] \
    && [ "$books" -gt 0 ] && [ "$series" -gt 0 ]
}
poll_until "${SCAN_TIMEOUT_SECONDS:-300}" "indexing all media types" scan_counts

# The row counts above only prove the files were *found*: the per-file analysis that
# fills in audiobook chapters, the media-overlay flag and comic page counts runs later,
# in its own RabbitMQ handlers (EPUB_FILE_FOUND & friends). Asserting straight after the
# counts is a race — it broke once the counts came in fast, with the read-aloud epub
# still at mediaOverlays=null ("not analysed yet"). So wait for the analysis too, and
# only then assert, so a real miss still prints the JSON instead of a timeout message.
echo "--> Waiting for the per-file analysis (up to ${ANALYSIS_TIMEOUT_SECONDS:-180}s)"
BOOKS_QUERY='{ books(size: 50) { content { name chapters { id } epubFiles { id mediaOverlays } } } }'
SERIES_QUERY='{ series(size: 50) { content { name startYear books { name epubFiles { pageCount } } } } }'

fetch_analysis() {
  books_json=$(gql "$BOOKS_QUERY")
  series_json=$(gql "$SERIES_QUERY")
}

analysis_done() {
  fetch_analysis
  # jq errors (a half-filled payload) just mean "not done yet" here; the asserts below
  # report them for real.
  echo "$books_json" | jq -e '
    (.data.books.content | map(select(.chapters | length > 0)) | length > 0)
    and ([.data.books.content[].epubFiles // [] | .[] | select(.mediaOverlays == true)] | length > 0)
  ' >/dev/null 2>&1 || return 1
  echo "$series_json" | jq -e '
    ([.data.series.content[].books[].epubFiles // [] | .[] | select(.pageCount > 0)] | length > 0)
    and (.data.series.content | map(select(.startYear == 1998)) | length > 0)
  ' >/dev/null 2>&1
}

analysis_deadline=$((SECONDS + ${ANALYSIS_TIMEOUT_SECONDS:-180}))
while :; do
  analysis_done && break
  [ $SECONDS -lt $analysis_deadline ] || break
  sleep 5
done
# The loop leaves the last fetched payloads in $books_json / $series_json; on a timeout
# those are what the asserts below report.

echo "--> Asserting audiobook chapters"
echo "$books_json" | jq -e '.data.books.content | map(select(.chapters | length > 0)) | length > 0' >/dev/null \
  || fail "no book with audiobook chapters found: $(echo "$books_json" | jq -c '.data.books.content')"

echo "--> Asserting media-overlay (read-aloud) detection"
# "Spring Walk.epub" is a media-overlay epub deliberately named without any hint in the
# filename, so this only passes when the scanner detects overlays from the contents.
echo "$books_json" | jq -e '[.data.books.content[].epubFiles // [] | .[] | select(.mediaOverlays == true)] | length > 0' >/dev/null \
  || fail "no epub with mediaOverlays=true found: $(echo "$books_json" | jq -c '.data.books.content')"

echo "--> Asserting comic volumes with pages"
echo "$series_json" | jq -e '[.data.series.content[].books[].epubFiles // [] | .[] | select(.pageCount > 0)] | length > 0' >/dev/null \
  || fail "no comic volume with pageCount > 0: $(echo "$series_json" | jq -c '.data.series.content')"
echo "$series_json" | jq -e '.data.series.content | map(select(.startYear == 1998)) | length > 0' >/dev/null \
  || fail "series start year (1998) not parsed: $(echo "$series_json" | jq -c '.data.series.content')"

echo "--> Scan scenario passed"
