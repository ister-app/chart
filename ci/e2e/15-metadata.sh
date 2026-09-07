# Scenario: metadata enrichment through the mocked external sources.
#
# Every external API (TMDB, MusicBrainz, Open Library, Wikidata/Wikipedia, iTunes) is
# served by ci/mock-external.yaml, so enrichment must actually land: this proves the
# worker's whole fetch → metadata → search-index pipeline works without internet.
# Enrichment is asynchronous (RabbitMQ per entity), so poll.

# Only some movie fixtures have a TMDB stub pair and movies() has no defined order, so ask
# whether ANY movie got enriched — movies(size: 1) passed only as long as a stubbed one
# happened to come back first.
echo "--> Waiting for TMDB movie metadata (up to ${METADATA_TIMEOUT_SECONDS:-180}s)"
movie_enriched() {
  movies=$(gql '{ movies(size: 50) { content { id name contentRating keywords trailerKey trailerSite metadata { title description sourceUri } } } }')
  enriched_movie=$(echo "$movies" | jq -c '[.data.movies.content[]
      | select([.metadata[]? | select(.description != null and .description != "")] | length > 0)]
      | first // empty')
  [ -n "$enriched_movie" ]
}
poll_until "${METADATA_TIMEOUT_SECONDS:-180}" "movie metadata from TMDB" movie_enriched

# The language-independent extras come from four more TMDB endpoints than the details call
# (release_dates, videos, keywords). The worker degrades to a null field on failure rather
# than dead-lettering, so without this assertion an unstubbed endpoint passes CI silently.
echo "--> Asserting the TMDB movie extras (certification, trailer, keywords)"
echo "$enriched_movie" | jq -e '.contentRating == "PG-13" and .trailerSite == "YouTube"
    and .trailerKey != null and (.keywords // "") != ""' >/dev/null \
  || fail "movie extras did not land: $enriched_movie"

echo "--> Waiting for TMDB show metadata"
show_enriched() {
  shows=$(gql '{ shows(size: 20) { content { name contentRating imdbId keywords trailerKey trailerSite metadata { description } } } }')
  enriched_show=$(echo "$shows" | jq -c '[.data.shows.content[]
      | select([.metadata[]? | select(.description != null and .description != "")] | length > 0)]
      | first // empty')
  [ -n "$enriched_show" ]
}
poll_until "${METADATA_TIMEOUT_SECONDS:-180}" "show metadata from TMDB" show_enriched

echo "--> Asserting the TMDB show extras (rating, imdb id, trailer, keywords)"
echo "$enriched_show" | jq -e '.contentRating == "TV-PG" and .imdbId != null
    and .trailerSite == "YouTube" and .trailerKey != null and (.keywords // "") != ""' >/dev/null \
  || fail "show extras did not land: $enriched_show"

# Credits are only fetched for a movie TMDB actually matched, so ask the enriched one.
echo "--> Waiting for cast credits (TMDB movie credits + person)"
enriched_movie_id=$(echo "$enriched_movie" | jq -r '.id')
cast_present() {
  cast=$(gql "{ cast(movieId: \"$enriched_movie_id\") { content { person { name } } } }")
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
