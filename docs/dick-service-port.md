# Dick Service port status

This fork reproduces the Dick-specific changes that can be verified from the
`dick-service v1.0.15` APK without executing it:

- Android application ID: `org.dickservice.client`
- Android label and service branding: `Dick Service`
- `dickservice://` is accepted alongside the upstream configuration schemes.
- Firebase package entries match the release, debug, and development Android
  application IDs.
- `assets/data/dick_rule.js` is bundled byte-for-byte from the APK. Its SHA-256
  is `d2b761ac9b854c16fe4df2108e1c34c3fd889d7a55c867a306227de8aa0df55c`.
- The Android implementation namespace remains `com.follow.clash.*`, matching
  the APK. Changing Java/Kotlin namespaces would break the recovered identity.

## Dick Service feature evidence

The APK also contains dedicated login, account, plan/shop, order, ticket,
gift-card, subscription-cache, and expiry-gate code. Those modules were
compiled into Flutter's stripped AOT snapshot; this repository does not contain
their source. Their endpoint names and state-key strings are documented in the
comparison reports under `work/flclash-diff/reports/`.

The following details are intentionally **not** guessed in this port:

- HTTP methods, request bodies, pagination, authentication schema, and token
  refresh behavior.
- Order/payment callback and polling behavior, including WebView URL policy.
- Ticket and gift-card response schemas.
- Expiry-gate grace periods, offline behavior, and the exact roles of the
  service domains.

Recovering those pieces requires a test account with dynamic request capture
or service-side API documentation. The fork therefore does not claim full
Dick Service account/payment parity yet.

## Implemented from AOT (static-only, no guessing)

- `lib/common/dick_service_api.dart` — baseUrl `https://airport.dicksupport.top`, UA `AuroraDeck/7.4.2 (Android; ndk-aurora-74; rv:20260630)`, HMAC key `c9f1f637…56bb7a4`, header names `X-Client-Id/Ts/Nonce/Sign/Sign-Version`, `GET /api/v1/guest/plan/fetch`, `GET /api/v1/user/{getSubscribe,info,order/fetch,ticket/fetch}`, `POST /api/v1/user/order/{save,checkout}`, response helpers `_asMap/_throwIfFailed/_unwrap/_extractUrl/_looksLikeHtml/_findUrl/_findHtml` and signing `method\npath?query\nts\nnonce\nsha256(canonicalBody)` verified from `aot-dick-full/asm/fl_clash/common/dick_service_api.dart`.
- `lib/common/dick_service_expiry_cache.dart` — keys `dick_service_cached_expired_at/_has_active_plan/_plan_name/_last_subscribe_sync_at/_last_local_check_at/_bootstrap_done/_expired_lock` and save/clear semantics from `dick_service_expiry_cache.dart`. Login/order/ticket/gift-card request bodies remain unimplemented pending dynamic capture.
- `lib/common/dick_service_models.dart` — tolerant static-AOT models for subscriptions, plans, orders, tickets, checkout responses, and gift-card results.
- `lib/common/dick_service_profile.dart` — exact bound-subscription URL detection and `dick_service_auth_data` key.
- `lib/pages/dick_service/` — model-driven read-only account, shop, order, ticket, login, gift-card, and payment states. Mutating requests, login persistence, and payment WebView behavior remain explicit capture TODOs.
- `lib/pages/dick_service/gates.dart` — bootstrap and expiry gates, lifecycle-resume recheck, cache/signature handling, and the observed expiry messages. Offline grace and account-alert policy remain unverified.
- `lib/common/dick_service_api.dart` — typed subscription fetch joins the observed `getSubscribe` and `info` GET responses; unsupported POST contracts do not reach the transport.

The focused static tests cover the observed GET signing/subscription join and assert
that unsupported login/order/checkout writes fail before transport. Flutter analysis
passes with one pre-existing info in `test/widgets/scrollbar_inset_test.dart`.

## Verification baseline

The APK comparison used static analysis only. The rule asset hash above is
checked against the extracted APK resource. Verified with Flutter 3.47.1 / Dart 3.13.1 (`/opt/flutter`, `flutter pub get` + `flutter analyze` pass with 1 pre-existing info).
