---
description: Configure an OIDC issuer for the Ister media server — the flat roles claim, the ister client and its per-platform redirect URIs, with a working Keycloak example.
---

# Setting up the identity provider

Ister does not manage users. Every request to the API carries an OAuth 2.0 access token,
and the server validates it against the issuer you configure in `server.oidc.url`. Which
issuer you run is up to you — Keycloak, Authentik, Authelia, Zitadel, Dex — but three
things about that issuer are not negotiable, and getting one of them wrong produces a
failure that looks like something else entirely.

Read this chapter before you install: an issuer that is almost right lets you log in and
then refuses every query.

## What the server expects

**A flat `roles` claim in the access token.** The server authorises with Spring's
`JwtGrantedAuthoritiesConverter`, which reads a top-level `roles` array and prefixes each
entry with `ROLE_`. Two roles matter:

| role | grants |
|---|---|
| `user` | reading the library and playing media — every content query needs it |
| `admin` | the mutations on top of that: scanning libraries, subscribing to podcasts, administration |

```json
{
  "iss": "https://auth.example.com/realms/ister",
  "sub": "8f14e45f",
  "preferred_username": "alice",
  "roles": ["user", "admin"]
}
```

Nested claims do not work. Keycloak's default is `realm_access.roles`, and a token shaped
that way is perfectly valid, verifies fine, and logs the user in — after which every
single query comes back `403`. That reads like a broken server, not a claim mapping, so
check the token first when it happens (paste it into `jwt.io`, or decode the middle
segment with `base64 -d`).

**The audience is checked only when you ask for it.** By default the server validates the
signature and the issuer, not `aud`, so any token from the issuer is accepted — including
one minted for a different client in the same realm. Set `server.oidc.audience: ister` to
require that the token was issued to the `ister` client: it passes when `aud` contains
`ister` *or* `azp` equals it. Keycloak puts `azp` in every access token, so with Keycloak
the check works without a mapper; for issuers that do not emit `azp`, add an audience
mapper that puts `ister` in `aud` of the access token.

**The issuer must be reachable at the same URL from three places**: the server pod (it
fetches the JWKS), the browser or app (it runs the login flow), and whatever you use to
test. A split-horizon setup that serves a different hostname internally will fail
validation, because the `iss` claim in the token then does not match `server.oidc.url`.

## The client

The client ID is **`ister`**. It is compiled into the player and cannot be configured, so
your issuer must register a client under exactly that name.

It is a **public client with PKCE** — a browser and a mobile app cannot keep a secret, so
there is none. Enable the authorization code flow and require PKCE (`S256`).

The redirect URI **differs per platform**, and each one you skip breaks that platform with
`invalid redirect_uri` while the others keep working:

| platform | redirect URI |
|---|---|
| web | `https://<your-host>/redirect.html` |
| Android, iOS, macOS | `app.ister.player:/oauth2redirect` (custom scheme, one slash) |
| Windows, Linux | `http://localhost:<random port>` — register `http://localhost:*` |

The desktop player binds a free port per login, which is the standard loopback
redirect for native apps; the loopback is only reachable on the machine itself.

## Keycloak

A realm that works, as an import file. Trim it to taste — the parts that matter are the
two roles, the `roles` protocol mapper and the three redirect URIs.

```json
{
  "realm": "ister",
  "enabled": true,
  "roles": {
    "realm": [
      { "name": "user", "description": "Read the library and play media" },
      { "name": "admin", "description": "Scan libraries and administer" }
    ]
  },
  "clients": [
    {
      "clientId": "ister",
      "name": "Ister player",
      "enabled": true,
      "publicClient": true,
      "standardFlowEnabled": true,
      "fullScopeAllowed": true,
      "redirectUris": [
        "https://ister.example.com/*",
        "app.ister.player:/oauth2redirect",
        "http://localhost:*"
      ],
      "webOrigins": ["https://ister.example.com"],
      "attributes": {
        "pkce.code.challenge.method": "S256",
        "post.logout.redirect.uris": "+"
      },
      "protocolMappers": [
        {
          "name": "realm roles as flat claim",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-usermodel-realm-role-mapper",
          "config": {
            "claim.name": "roles",
            "jsonType.label": "String",
            "multivalued": "true",
            "access.token.claim": "true",
            "id.token.claim": "false",
            "userinfo.token.claim": "true"
          }
        },
        {
          "name": "ister audience",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-audience-mapper",
          "config": {
            "included.client.audience": "ister",
            "access.token.claim": "true",
            "id.token.claim": "false"
          }
        }
      ]
    }
  ]
}
```

The issuer for `server.oidc.url` is then
`https://<keycloak-host>/realms/ister`.

Clicking the same thing together in the admin console: **Realm roles** → create `user`
and `admin`; **Clients** → create `ister`, client authentication off, standard flow on;
**Clients → ister → Client scopes → ister-dedicated → Add mapper → By configuration →
User Realm Role**, with token claim name `roles`, "Multivalued" on, "Add to access token"
on. Assign the roles under **Users → *user* → Role mapping**. The audience mapper (only
needed with `server.oidc.audience` on a non-Keycloak issuer, harmless otherwise) is **Add
mapper → By configuration → Audience**, included client audience `ister`, "Add to access
token" on.

Two Keycloak specifics worth knowing before they cost you an evening:

- **Users need an email address.** Keycloak's declarative user profile requires one, and
  a user without it gets the `VERIFY_PROFILE` required action. Every login then ends in
  `Account is not fully set up`, including the password grant.
- **Direct access grants** (the password grant) are off by default. You do not need them
  for the app, only if you want to script against the API — `curl -d grant_type=password
  -d client_id=ister -d username=… -d password=…` is the quickest way to inspect the
  claims in a token.

## Production checklist

The example above is already production-shaped. What separates it from a realm that
merely works on a laptop:

- **Exact redirect URIs**, no bare `*`: `https://<your-host>/redirect.html`,
  `app.ister.player:/oauth2redirect` and `http://localhost:*`. The port wildcard on the
  loopback is the only wildcard the player needs. A `*` redirect lets any site that can
  trigger a login collect the authorization code.
- **Exact web origins** (`https://<your-host>`), not `*`.
- **Direct access grants off.** Turn them back off if you enabled them for the token check
  below; the app never uses the password grant.
- **PKCE `S256` required** and client authentication off — it is a public client.
- **`server.oidc.audience: ister`** when the realm serves more than one application, with
  the audience mapper on issuers that do not emit `azp`.
- The flat `roles` claim and an email address on every user, as described above.

## Other issuers

The chart does not care which one you run, as long as it can do all three of these:

- register a **public** client named `ister` with PKCE and the redirect URIs above;
- put a **flat, multi-valued `roles` claim** in the *access* token (not just the ID
  token) — in Authentik a property mapping returning `{"roles": [...]}`, in Zitadel a
  custom claim, in Dex whatever your connector maps groups to;
- serve a standard discovery document at
  `<issuer>/.well-known/openid-configuration`.

Providers that can only put roles in a nested claim need a mapper that flattens them.
There is no server-side setting to point ister at a different claim path.

## Checking it before you blame the app

Fetch a token and look at it. With Keycloak and direct access grants enabled:

```sh
curl -s -d grant_type=password -d client_id=ister \
     -d username=alice -d password=… \
     https://auth.example.com/realms/ister/protocol/openid-connect/token \
  | cut -d'"' -f4 | cut -d. -f2 | base64 -d 2>/dev/null
```

You are looking for `"roles":["user"]` at the top level. If it is nested under
`realm_access`, the mapper is missing. If the request fails with `invalid_grant: Account
is not fully set up`, the user profile is incomplete — usually the email address.

With a good token, the API answers:

```sh
curl -s -X POST https://ister.example.com/api/graphql \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"query":"{ movies(size: 1) { totalElements } }"}'
```

A `403` here with a token that carries `user` means the claim is not being read; a `401`
means the signature or issuer does not match `server.oidc.url` — or, with
`server.oidc.audience` set, that the token was minted for another client (neither `aud`
nor `azp` carries `ister`).
