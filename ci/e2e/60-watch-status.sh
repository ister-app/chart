# Scenario: watching a movie is recorded.
#
# Mirrors what the player does: create a play queue for a movie, send the
# updatePlayQueue heartbeat with a playback position, and assert the movie shows up in
# recentlyWatched. Runs after 30-streaming.sh, which exported MOVIE_MEDIA_FILE_ID.

echo "--> Picking a movie"
movie_id=$(gql '{ movies(size: 1) { content { id name } } }' | jq -r '.data.movies.content[0].id // empty')
[ -n "$movie_id" ] || fail "no movie found"

echo "--> Creating a play queue"
queue=$(gql "mutation { createPlayQueue(input: { sourceType: MOVIE, sourceId: \"$movie_id\" }) { id currentItemId } }")
queue_id=$(echo "$queue" | jq -r '.data.createPlayQueue.id // empty')
item_id=$(echo "$queue" | jq -r '.data.createPlayQueue.currentItemId // empty')
[ -n "$queue_id" ] && [ -n "$item_id" ] || fail "createPlayQueue failed: $queue"

# The server only records watch status beyond 60s of progress; 90s is mid-movie for
# the 3-minute fixtures, so it registers as "in progress" rather than "finished".
echo "--> Sending playback heartbeats (90s into the movie)"
updated=$(gql "mutation { updatePlayQueue(id: \"$queue_id\", progressInMilliseconds: 90000, playQueueItemId: \"$item_id\", playState: PLAYING) { id } }")
echo "$updated" | jq -e '.data.updatePlayQueue.id' >/dev/null \
  || fail "updatePlayQueue failed: $updated"

echo "--> Asserting the movie appears in recentlyWatched"
recently_watched() {
  recent=$(gql '{ recentlyWatched { type movie { id } } }')
  echo "$recent" | jq -e --arg id "$movie_id" '[.data.recentlyWatched // [] | .[] | select(.movie.id == $id)] | length > 0' >/dev/null
}
poll_until "${WATCH_STATUS_TIMEOUT_SECONDS:-60}" "movie appearing in recentlyWatched" recently_watched

echo "--> Watch-status scenario passed"
