# Local test environment for the ister chart. See ci/up.sh for the details;
# every target is idempotent.
#
#   make up          — fixtures + kind cluster + mock-oidc + podcast-feed + chart
#   make e2e         — run the API end-to-end scenarios (ci/e2e.sh)
#   make player-e2e  — run the player's Flutter integration tests against the cluster
#   make down        — delete the kind cluster

CLUSTER_NAME ?= ister
NAMESPACE    ?= ister
RELEASE      ?= ister
TESTDATA_DIR ?= $(abspath ../testdata)
PLAYER_DIR   ?= $(abspath ../player)

.PHONY: fixtures up e2e player-e2e down

fixtures:
	cd $(TESTDATA_DIR) && ./create_mkv.sh || true
	cd $(TESTDATA_DIR) && ./create_books.sh && ./create_comics.sh && ./create_podcast_feed.sh http://podcast-feed:8080

# Image pinning is passed through to ci/up.sh; default is the chart's own pinned version.
#   make up SERVER_IMAGE_TAG=1.2.0-snapshot
#   make up SERVER_IMAGE_REPOSITORY=localhost/ister-server SERVER_IMAGE_TAG=dev SERVER_IMAGE_PULL_POLICY=Never
up:
	TESTDATA_DIR=$(TESTDATA_DIR) CLUSTER_NAME=$(CLUSTER_NAME) NAMESPACE=$(NAMESPACE) RELEASE=$(RELEASE) \
	SERVER_IMAGE_REPOSITORY=$(SERVER_IMAGE_REPOSITORY) SERVER_IMAGE_TAG=$(SERVER_IMAGE_TAG) \
	SERVER_IMAGE_PULL_POLICY=$(SERVER_IMAGE_PULL_POLICY) \
	MIGRATIONS_IMAGE_REPOSITORY=$(MIGRATIONS_IMAGE_REPOSITORY) MIGRATIONS_IMAGE_TAG=$(MIGRATIONS_IMAGE_TAG) \
	ci/up.sh

e2e:
	ci/e2e.sh $(RELEASE) $(NAMESPACE)

# Starts the forwards, runs the integration tests, and tears the forwards down.
player-e2e:
	ci/e2e/forward-for-player.sh $(RELEASE) $(NAMESPACE) & \
	FWD_PID=$$!; \
	sleep 3; \
	(cd $(PLAYER_DIR) && flutter test integration_test -d linux --dart-define=ISTER_TEST_MODE=true); \
	STATUS=$$?; \
	kill $$FWD_PID 2>/dev/null; \
	exit $$STATUS

down:
	kind delete cluster --name $(CLUSTER_NAME)
