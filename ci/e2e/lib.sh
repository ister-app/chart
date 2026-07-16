# Shared helpers for the e2e scenario scripts. Sourced, not executed.
#
# Expects the caller to have set (ci/e2e.sh does):
#   API        — base URL of the server API, e.g. http://localhost:18080/api
#   OIDC_PORT  — local port the mock issuer is forwarded on
#   TOKEN      — a minted JWT (after calling mint_token)

fail() { echo "FAIL: $*" >&2; exit 1; }

forward() { # svc port -> localhost port
  kubectl port-forward -n "$NAMESPACE" "svc/$1" "$3:$2" >/dev/null 2>&1 &
  PIDS+=($!)
}

wait_for() { # url
  for _ in $(seq 1 30); do
    curl -fsS -o /dev/null "$1" 2>/dev/null && return 0
    sleep 1
  done
  return 1
}

# GraphQL over HTTP. Passes the query as a JSON string via jq so quoting can't bite us.
gql() { # query [token]
  local body auth=()
  body=$(jq -n --arg q "$1" '{query: $q}')
  [ -n "${2:-$TOKEN}" ] && auth=(-H "Authorization: Bearer ${2:-$TOKEN}")
  curl -fsS -X POST "$API/graphql" \
    -H 'Content-Type: application/json' \
    "${auth[@]}" \
    -d "$body"
}

# REST call against the API with Bearer auth. Usage: rest GET /reading-progress?bookId=x
# Extra curl args (e.g. -d, -H) can follow the path.
rest() { # method path [curl args...]
  local method="$1" path="$2"
  shift 2
  curl -fsS -X "$method" "$API$path" -H "Authorization: Bearer $TOKEN" "$@"
}

# Mints a JWT with roles=[user] at the mock issuer and puts it in $TOKEN.
# The Host header matters: mock-oauth2-server builds the `iss` claim from it, and the
# server rejects any token whose `iss` differs from OIDC_URL (http://mock-oidc:8080/default).
mint_token() {
  TOKEN=$(curl -fsS -X POST "http://localhost:${OIDC_PORT}/default/token" \
    -H 'Host: mock-oidc:8080' \
    -d grant_type=client_credentials \
    -d client_id=ci \
    -d client_secret=ci-secret \
    -d scope=ister | jq -r '.access_token')
  [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || fail "no access_token from the mock issuer"
}

# Polls a command until it exits 0, up to a deadline. Usage:
#   poll_until <timeout_seconds> <description> <command...>
# The command is run with eval so it can be a pipeline in a single string.
poll_until() {
  local timeout="$1" what="$2"
  shift 2
  local deadline=$((SECONDS + timeout))
  while [ $SECONDS -lt $deadline ]; do
    if eval "$@"; then
      return 0
    fi
    sleep 5
  done
  fail "$what did not happen within ${timeout}s"
}
