# Scenario: reading a book — epub resources and reading-progress sync.
#
# Fetches an entry from inside a scanned epub through EpubResourceController (stream
# token auth), then round-trips reading progress through the REST endpoints the player
# uses (REST rather than the GraphQL mutation because REST carries the audiobook
# chapter mapping).

echo "--> Picking an epub media file and its book"
book_json=$(gql '{ books(size: 50) { content { id name epubFiles { id } } } }')
book_id=$(echo "$book_json" | jq -r '[.data.books.content[] | select(.epubFiles | length > 0)][0].id // empty')
epub_media_file_id=$(echo "$book_json" | jq -r '[.data.books.content[] | select(.epubFiles | length > 0)][0].epubFiles[0].id // empty')
[ -n "$book_id" ] && [ -n "$epub_media_file_id" ] || fail "no book with an epub file found: $book_json"
echo "    bookId: $book_id, epub mediaFileId: $epub_media_file_id"

echo "--> Fetching an epub resource (META-INF/container.xml)"
stream_token=$(gql 'mutation { createStreamToken { token } }' | jq -r '.data.createStreamToken.token // empty')
[ -n "$stream_token" ] || fail "createStreamToken returned no token"
container=$(curl -fsS "$API/epub/$epub_media_file_id/resource/META-INF/container.xml?token=$stream_token")
echo "$container" | grep -q '<container' || fail "epub container.xml not served: $container"

echo "--> Round-tripping reading progress"
posted=$(rest POST /reading-progress \
  -H 'Content-Type: application/json' \
  -d "{\"bookId\": \"$book_id\", \"location\": \"epubcfi(/6/4!/4/2/2)\", \"progress\": 0.42}")
echo "$posted" | jq -e '.progress == 0.42 and .finished == false' >/dev/null \
  || fail "POST /reading-progress unexpected response: $posted"

fetched=$(rest GET "/reading-progress?bookId=$book_id")
echo "$fetched" | jq -e '.location == "epubcfi(/6/4!/4/2/2)" and .progress == 0.42' >/dev/null \
  || fail "GET /reading-progress did not return what was posted: $fetched"

echo "--> Checking the combined book progress (reading + chapters + overlay flags)"
progress=$(rest GET "/book-progress?bookId=$book_id")
echo "$progress" | jq -e '.reading.location == "epubcfi(/6/4!/4/2/2)"' >/dev/null \
  || fail "GET /book-progress missing the reading position: $progress"

echo "--> Books scenario passed"
