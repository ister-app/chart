# Scenario: server.config reaches the server.
#
# ci/values-ci.yaml sets management.endpoint.health.show-details=always through server.config
# only (the server's default is "never"), so a health response that lists components proves
# the mounted file was read and bound. A property with a runtime binding is used on purpose:
# the actuator exposure list or any other bean condition is frozen when the native image is
# built, so adding e.g. the "env" endpoint through the ConfigMap has no effect.
# Needs the management port, which the server Service exposes as "monitor".

CONFIG_PORT="${CONFIG_PORT:-18082}"
echo "--> Port-forwarding the management port"
forward "${RELEASE}-server" 8081 "$CONFIG_PORT"
wait_for "http://localhost:${CONFIG_PORT}/actuator/health" || fail "management port not reachable"

echo "--> Asserting /actuator/health shows components (show-details from server.config)"
health_json=$(api_curl "http://localhost:${CONFIG_PORT}/actuator/health") \
  || fail "health endpoint not reachable"
echo "$health_json" | jq -e '.components | has("db") and has("rabbit")' >/dev/null \
  || fail "health has no components: server.config was not loaded: $health_json"

echo "--> Config scenario passed"
