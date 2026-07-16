# Scenario: full-text search through Typesense.
#
# Indexing is asynchronous, so poll. Shows are indexed from their tvshow.nfo during the
# scan; movies only reach the search index through TMDB enrichment (NfoScanner does not
# scan movie nfo files), which works here because ci/mock-external.yaml serves TMDB.

echo "--> Picking a known show title to search for"
show_term=$(gql '{ shows(size: 1) { content { name } } }' | jq -r '.data.shows.content[0].name // empty')
[ -n "$show_term" ] || fail "no show to search for"
echo "    term: $show_term"

show_hits() {
  results=$(gql "{ search(term: \"$show_term\", size: 10) { __typename } }")
  count=$(echo "$results" | jq -r '.data.search | length')
  echo "    show hits=$count"
  [ "$count" -gt 0 ]
}
poll_until "${SEARCH_TIMEOUT_SECONDS:-120}" "search returning show results" show_hits

echo "--> Picking a known movie title to search for (indexed via mocked TMDB)"
movie_term=$(gql '{ movies(size: 1) { content { name } } }' | jq -r '.data.movies.content[0].name // empty')
[ -n "$movie_term" ] || fail "no movie to search for"
echo "    term: $movie_term"

movie_hits() {
  results=$(gql "{ search(term: \"$movie_term\", size: 10) { __typename } }")
  count=$(echo "$results" | jq -r '[.data.search[] | select(.__typename == "Movie")] | length')
  echo "    movie hits=$count"
  [ "$count" -gt 0 ]
}
poll_until "${SEARCH_TIMEOUT_SECONDS:-120}" "search returning the movie" movie_hits

echo "--> Search scenario passed"
