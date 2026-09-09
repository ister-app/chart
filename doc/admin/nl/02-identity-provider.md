---
description: Een OIDC-issuer instellen voor de Ister-mediaserver — de platte roles-claim, de client ister en zijn redirect-URI's per platform, met een werkend Keycloak-voorbeeld.
---

# De identity provider instellen

Ister beheert zelf geen gebruikers. Elk verzoek aan de API draagt een OAuth 2.0
access-token, en de server valideert dat tegen de issuer die je in `server.oidc.url`
opgeeft. Welke issuer je draait is aan jou — Keycloak, Authentik, Authelia, Zitadel, Dex
— maar drie dingen liggen vast, en één ervan verkeerd hebben geeft een storing die er
heel anders uitziet dan hij is.

Lees dit hoofdstuk vóór je installeert: een issuer die er bijna is laat je inloggen en
weigert daarna elke query.

## Wat de server verwacht

**Een platte `roles`-claim in het access-token.** De server autoriseert met Spring's
`JwtGrantedAuthoritiesConverter`, die een `roles`-array op het hoogste niveau leest en er
`ROLE_` voor zet. Twee rollen doen ertoe:

| rol | geeft recht op |
|---|---|
| `user` | de bibliotheek lezen en media afspelen — elke contentquery heeft hem nodig |
| `admin` | de mutaties daarbovenop: bibliotheken scannen, podcasts abonneren, beheer |

```json
{
  "iss": "https://auth.example.com/realms/ister",
  "sub": "8f14e45f",
  "preferred_username": "alice",
  "roles": ["user", "admin"]
}
```

Geneste claims werken niet. Keycloak zet ze standaard in `realm_access.roles`, en zo'n
token is volkomen geldig, valideert prima en logt de gebruiker in — waarna élke query
`403` teruggeeft. Dat leest als een kapotte server in plaats van een claim-mapping, dus
kijk eerst naar het token als dit gebeurt (plak het in `jwt.io`, of decodeer het middelste
segment met `base64 -d`).

**De audience wordt niet gecontroleerd.** De server controleert de handtekening en de
issuer, niet `aud`, dus een audience-mapper heb je niet nodig.

**De issuer moet vanaf drie plekken op dezelfde URL bereikbaar zijn**: vanaf de
serverpod (die haalt de JWKS op), vanaf de browser of app (die doet de login), en vanaf
waar je test. Een split-horizon-opstelling die intern een andere hostnaam serveert
mislukt, want de `iss`-claim in het token komt dan niet overeen met `server.oidc.url`.

## De client

De client-id is **`ister`**. Die zit in de player gecompileerd en is niet instelbaar, dus
je issuer moet een client onder precies die naam kennen.

Het is een **public client met PKCE** — een browser en een mobiele app kunnen geen geheim
bewaren, dus er is er geen. Zet de authorization code flow aan en eis PKCE (`S256`).

De redirect-URI **verschilt per platform**, en elke die je overslaat breekt dat platform
met `invalid redirect_uri` terwijl de rest blijft werken:

| platform | redirect-URI |
|---|---|
| web | `https://<jouw-host>/redirect.html` |
| Android, iOS, macOS | `app.ister.player:/oauth2redirect` (custom scheme, één slash) |
| Windows, Linux | `http://localhost:<willekeurige poort>` — registreer `http://localhost:*` |

De desktopplayer pakt per login een vrije poort; dat is de gebruikelijke
loopback-redirect voor native apps, en die loopback is alleen op het apparaat zelf
bereikbaar.

## Keycloak

Een realm die werkt, als importbestand. Snoei naar smaak — waar het om gaat zijn de twee
rollen, de `roles`-protocolmapper en de drie redirect-URI's.

```json
{
  "realm": "ister",
  "enabled": true,
  "roles": {
    "realm": [
      { "name": "user", "description": "Bibliotheek lezen en media afspelen" },
      { "name": "admin", "description": "Bibliotheken scannen en beheren" }
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
        }
      ]
    }
  ]
}
```

De issuer voor `server.oidc.url` is dan
`https://<keycloak-host>/realms/ister`.

Hetzelfde bij elkaar klikken in de adminconsole: **Realm roles** → maak `user` en
`admin`; **Clients** → maak `ister` aan, client authentication uit, standard flow aan;
**Clients → ister → Client scopes → ister-dedicated → Add mapper → By configuration →
User Realm Role**, met token claim name `roles`, "Multivalued" aan en "Add to access
token" aan. De rollen ken je toe onder **Users → *gebruiker* → Role mapping**.

Twee Keycloak-eigenaardigheden die je beter vooraf weet:

- **Gebruikers hebben een e-mailadres nodig.** Keycloaks declaratieve gebruikersprofiel
  eist er een, en zonder krijgt de gebruiker de required action `VERIFY_PROFILE`. Elke
  login eindigt dan op `Account is not fully set up`, ook de password grant.
- **Direct access grants** (de password grant) staan standaard uit. Voor de app heb je ze
  niet nodig, alleen als je tegen de API wilt scripten — `curl -d grant_type=password -d
  client_id=ister -d username=… -d password=…` is de snelste manier om de claims in een
  token te bekijken.

## Andere issuers

De chart maakt niet uit welke je draait, zolang hij deze drie dingen kan:

- een **public** client `ister` registreren met PKCE en de redirect-URI's hierboven;
- een **platte, meerwaardige `roles`-claim** in het *access*-token zetten (niet alleen in
  het ID-token) — in Authentik een property mapping die `{"roles": [...]}` teruggeeft, in
  Zitadel een custom claim, in Dex wat je connector aan groepen mapt;
- een standaard discovery-document serveren op
  `<issuer>/.well-known/openid-configuration`.

Providers die rollen alleen genest kwijt kunnen, hebben een mapper nodig die ze plat
slaat. Er is geen instelling aan de serverkant om ister naar een ander claimpad te laten
kijken.

## Controleren voordat je de app de schuld geeft

Haal een token op en kijk ernaar. Met Keycloak en direct access grants aan:

```sh
curl -s -d grant_type=password -d client_id=ister \
     -d username=alice -d password=… \
     https://auth.example.com/realms/ister/protocol/openid-connect/token \
  | cut -d'"' -f4 | cut -d. -f2 | base64 -d 2>/dev/null
```

Je zoekt `"roles":["user"]` op het hoogste niveau. Staat het genest onder `realm_access`,
dan ontbreekt de mapper. Mislukt het verzoek met `invalid_grant: Account is not fully set
up`, dan is het gebruikersprofiel onvolledig — meestal het e-mailadres.

Met een goed token antwoordt de API:

```sh
curl -s -X POST https://ister.example.com/api/graphql \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"query":"{ movies(size: 1) { totalElements } }"}'
```

Een `403` met een token dat `user` bevat betekent dat de claim niet gelezen wordt; een
`401` betekent dat de handtekening of de issuer niet bij `server.oidc.url` past.
