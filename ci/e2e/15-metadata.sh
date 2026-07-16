# Scenario: metadata enrichment through the mocked external sources.
#
# Every external API (TMDB, MusicBrainz, Open Library, Wikidata/Wikipedia, iTunes) is
# served by ci/mock-external.yaml, so enrichment must actually land: this proves the
# worker's whole fetch → metadata → search-index pipeline works without internet.
# Enrichment is asynchronous (RabbitMQ per entity), so poll.

echo "--> Waiting for TMDB movie metadata (up to ${METADATA_TIMEOUT_SECONDS:-180}s)"
movie_enriched() {
  movie=$(gql '{ movies(size: 1) { content { name metadata { title description sourceUri } } } }')
  echo "$movie" | jq -e '[.data.movies.content[0].metadata[]? | select(.description != null and .description != "")] | length > 0' >/dev/null
}
poll_until "${METADATA_TIMEOUT_SECONDS:-180}" "movie metadata from TMDB" movie_enriched

echo "--> Waiting for TMDB show metadata"
show_enriched() {
  show=$(gql '{ shows(size: 5) { content { name metadata { description } } } }')
  echo "$show" | jq -e '[.data.shows.content[].metadata[]? | select(.description != null and .description != "")] | length > 0' >/dev/null
}
poll_until "${METADATA_TIMEOUT_SECONDS:-180}" "show metadata from TMDB" show_enriched

echo "--> Waiting for cast credits (TMDB movie credits + person)"
cast_present() {
  movie_id=$(gql '{ movies(size: 1) { content { id } } }' | jq -r '.data.movies.content[0].id // empty')
  [ -n "$movie_id" ] || return 1
  cast=$(gql "{ cast(movieId: \"$movie_id\") { content { person { name } } } }")
  echo "$cast" | jq -e '.data.cast.content | length > 0' >/dev/null
}
poll_until "${METADATA_TIMEOUT_SECONDS:-180}" "movie cast from TMDB" cast_present

echo "--> Waiting for album metadata (MusicBrainz annotation)"
album_enriched() {
  album=$(gql '{ albums(size: 10) { content { name metadata { description } } } }')
  echo "$album" | jq -e '[.data.albums.content[].metadata[]? | select(.description != null and .description != "")] | length > 0' >/dev/null
}
poll_until "${METADATA_TIMEOUT_SECONDS:-180}" "album metadata from MusicBrainz" album_enriched

echo "--> Waiting for book metadata (Open Library description)"
book_enriched() {
  book=$(gql '{ books(size: 50) { content { name metadata { description } } } }')
  echo "$book" | jq -e '[.data.books.content[].metadata[]? | select(.description != null and .description != "")] | length > 0' >/dev/null
}
poll_until "${METADATA_TIMEOUT_SECONDS:-180}" "book metadata from Open Library" book_enriched

echo "--> Waiting for comic series metadata (Wikipedia description)"
series_enriched() {
  series=$(gql '{ series(size: 10) { content { name metadata { description } } } }')
  echo "$series" | jq -e '[.data.series.content[].metadata[]? | select(.description != null and .description != "")] | length > 0' >/dev/null
}
poll_until "${METADATA_TIMEOUT_SECONDS:-180}" "comic series metadata from Wikipedia" series_enriched

echo "--> Podcast directory search through the mocked iTunes API"
directory=$(gql '{ searchPodcastDirectory(term: "ister") { name feedUrl } }')
echo "$directory" | jq -e '.data.searchPodcastDirectory | length > 0' >/dev/null \
  || fail "searchPodcastDirectory returned nothing: $directory"

echo "--> Asserting no dead-lettered events"
snapshot=$(gql '{ serverActivitySnapshot { recentFailures { queue error } } }')
failures=$(echo "$snapshot" | jq '[.data.serverActivitySnapshot.recentFailures // [] | .[]] | length')
if [ "$failures" -gt 0 ]; then
  echo "$snapshot" | jq -c '.data.serverActivitySnapshot.recentFailures'
  fail "expected zero failed events with all external sources mocked, got $failures"
fi

echo "--> Metadata scenario passed"
