# Scenario: watching a movie is recorded.
#
# Mirrors what the player does: create a play queue for a movie, send the
# updatePlayQueue heartbeat with a playback position, and assert the movie shows up in
# recentlyWatched.

# The heartbeat below must land mid-movie: the server counts a position within a minute
# of the end as finished (PlayQueueService.updateWatchStatus), and a finished movie has
# nothing left to resume, so it drops straight back out of recentlyWatched. That rules
# out the 2-minute fixtures — 120s - 90s is under the minute — hence the length floor.
echo "--> Picking a movie long enough to be left mid-way"
movie_id=$(pick_movie 170000 | cut -f1)
[ -n "$movie_id" ] || fail "no movie of at least 170s found"

echo "--> Creating a play queue"
queue=$(gql "mutation { createPlayQueue(input: { sourceType: MOVIE, sourceId: \"$movie_id\" }) { id currentItemId } }")
queue_id=$(echo "$queue" | jq -r '.data.createPlayQueue.id // empty')
item_id=$(echo "$queue" | jq -r '.data.createPlayQueue.currentItemId // empty')
[ -n "$queue_id" ] && [ -n "$item_id" ] || fail "createPlayQueue failed: $queue"

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
