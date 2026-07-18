# Scenario: podcast subscribe → refresh → download.
#
# The feed is served in-cluster by ci/podcast-feed.yaml; episodes download into the
# cache PVC, so this also exercises the cache volume wiring.

echo "--> Subscribing to the test feed"
# subscribePodcast is gated on ROLE_admin; refreshPodcasts below stays user-level.
sub=$(gql 'mutation { subscribePodcast(feedUrl: "http://podcast-feed:8080/feed.xml") { id title } }' "$ADMIN_TOKEN")
podcast_id=$(echo "$sub" | jq -r '.data.subscribePodcast.id // empty')
[ -n "$podcast_id" ] || fail "subscribePodcast failed: $sub"
echo "    podcast id: $podcast_id"

echo "--> Refreshing podcasts"
gql 'mutation { refreshPodcasts }' | jq -e '.data.refreshPodcasts == true' >/dev/null \
  || fail "refreshPodcasts did not return true"

echo "--> Waiting for 3 episodes, at least one downloaded"
podcast_episodes() {
  eps=$(gql "{ podcastEpisodes(podcastId: \"$podcast_id\", size: 10) { totalElements content { downloaded } } }")
  total=$(echo "$eps" | jq -r '.data.podcastEpisodes.totalElements // 0')
  downloaded=$(echo "$eps" | jq -r '[.data.podcastEpisodes.content[] | select(.downloaded)] | length')
  echo "    episodes=$total downloaded=$downloaded"
  [ "$total" -ge 3 ] && [ "$downloaded" -ge 1 ]
}
poll_until "${PODCAST_TIMEOUT_SECONDS:-180}" "podcast episodes appearing and downloading" podcast_episodes

echo "--> Podcast scenario passed"
