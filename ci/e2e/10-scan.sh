# Scenario: scanning indexes every library type.
#
# Triggers the scan and polls until shows, movies, albums, books AND comic series all
# have rows, then asserts the deeper structure the scanners are responsible for:
# audiobook chapters, media-overlay detection on the read-aloud epub, comic page counts.

echo "--> Triggering the library scan"
scan=$(gql 'mutation { scanLibrary }')
echo "$scan" | jq -e '.data.scanLibrary == true' >/dev/null \
  || fail "scanLibrary did not return true: $scan"

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

echo "--> Asserting audiobook chapters"
books_json=$(gql '{ books(size: 50) { content { name chapters { id } epubFiles { id mediaOverlays } } } }')
echo "$books_json" | jq -e '.data.books.content | map(select(.chapters | length > 0)) | length > 0' >/dev/null \
  || fail "no book with audiobook chapters found: $(echo "$books_json" | jq -c '.data.books.content')"

echo "--> Asserting media-overlay (read-aloud) detection"
# "Spring Walk.epub" is a media-overlay epub deliberately named without any hint in the
# filename, so this only passes when the scanner detects overlays from the contents.
echo "$books_json" | jq -e '[.data.books.content[].epubFiles // [] | .[] | select(.mediaOverlays == true)] | length > 0' >/dev/null \
  || fail "no epub with mediaOverlays=true found: $(echo "$books_json" | jq -c '.data.books.content')"

echo "--> Asserting comic volumes with pages"
series_json=$(gql '{ series(size: 50) { content { name startYear books { name epubFiles { pageCount } } } } }')
echo "$series_json" | jq -e '[.data.series.content[].books[].epubFiles // [] | .[] | select(.pageCount > 0)] | length > 0' >/dev/null \
  || fail "no comic volume with pageCount > 0: $(echo "$series_json" | jq -c '.data.series.content')"
echo "$series_json" | jq -e '.data.series.content | map(select(.startYear == 1998)) | length > 0' >/dev/null \
  || fail "series start year (1998) not parsed: $(echo "$series_json" | jq -c '.data.series.content')"

echo "--> Scan scenario passed"
