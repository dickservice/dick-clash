# Dick Service port status

## Integrated audit checkpoint

The integrated API/cache/script/database suite passes 61 tests. Native asset
hooks were temporarily disabled for Dart tests and restored afterward; this is
not an Android release-build or device verification. Analysis reports only the
pre-existing const-constructor info in scrollbar_inset_test.dart.

- API: typed plan/order/ticket lists, period-keyed prices, UUID-v4 signing
  nonce, dedicated reset-price order, response/error and formatting contracts.
- Account pages: inline first-purchase login, cancellation confirmation,
  authenticated list guidance, payment trade number and explicit close action.
- State: bootstrap profile detection, persisted account-alert deduplication,
  30-minute refresh, timestamped-cache integrity and clock rollback locks.
- Rules: built-in script identity -10086, asset loading, non-persisted list
  injection and script-mode fallback (not a global overwrite-mode change).
- Android resources: launcher/round icons, adaptive foreground and TV banner
  copied from the Dick APK. Implementation namespace is unchanged.
- Shared UI: updater repository, Telegram link and Dick account navigation
  are represented; no proven default VPN/startup-page change is claimed.

Remaining evidence limits: original AOT was not reconstructed; core binaries
have different Go/VCS metadata but their behavioral delta is unresolved.
Firebase resource omission does not establish telemetry disablement. About
core-link source/payload provenance, endpoint recovery, URL-matched logout
cleanup and exact runtime warning behavior need further verification. APK
signing identity, a rebuilt APK and real-device/payment flows are not verified.
Consequently this checkpoint is not a claim of exhaustive binary parity.

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

The static AOT now provides the login, order, checkout, order cancellation,
ticket creation, gift-card redemption, reset-security, and payment WebView
contracts. Pagination, token refresh, payment callback/polling behavior, and
the expiry gate's exact offline grace policy remain unavailable.

## Implemented from AOT (static-only, no guessing)

- `lib/common/dick_service_api.dart` — baseUrl `https://airport.dicksupport.top`, UA `AuroraDeck/7.4.2 (Android; ndk-aurora-74; rv:20260630)`, HMAC key `c9f1f637…56bb7a4`, header names `X-Client-Id/Ts/Nonce/Sign/Sign-Version`, `GET /api/v1/guest/plan/fetch`, `GET /api/v1/user/{getSubscribe,info,order/fetch,ticket/fetch}`, `POST /api/v1/user/order/{save,checkout}`, response helpers `_asMap/_throwIfFailed/_unwrap/_extractUrl/_looksLikeHtml/_findUrl/_findHtml` and signing `method\npath?query\nts\nnonce\nsha256(canonicalBody)` verified from `aot-dick-full/asm/fl_clash/common/dick_service_api.dart`.
- `lib/common/dick_service_expiry_cache.dart` — keys `dick_service_cached_expired_at/_has_active_plan/_plan_name/_last_subscribe_sync_at/_last_local_check_at/_bootstrap_done/_expired_lock` and save/clear semantics from `dick_service_expiry_cache.dart`.
- `lib/common/dick_service_models.dart` — tolerant static-AOT models for subscriptions, plans, orders, tickets, checkout responses, and gift-card results.
- `lib/common/dick_service_profile.dart` — exact bound-subscription URL detection and `dick_service_auth_data` key.
- `lib/pages/dick_service/` — account login and persistence, bound-profile import, shop/order checkout, payment WebView, order cancellation, gift-card redemption, ticket creation, subscription reset, traffic-reset purchase, and logout.
- `lib/pages/dick_service/gates.dart` — bootstrap and expiry gates, lifecycle-resume recheck, cache/signature handling, and the observed expiry messages. Offline grace and account-alert policy remain unverified.
- `lib/common/dick_service_api.dart` — typed subscription fetch joins `getSubscribe` and `info`; AOT-observed POST bodies are implemented for login, order save/checkout/cancel, gift-card redemption, and ticket creation.

The focused static tests cover GET signing/subscription joins, login verification,
all observed write bodies, and expiry-cache integrity. Flutter analysis passes with
one pre-existing info in `test/widgets/scrollbar_inset_test.dart`.

## Verification baseline

The APK comparison used static analysis only. The rule asset hash above is
checked against the extracted APK resource. Verified with Flutter 3.47.1 / Dart 3.13.1 (`/opt/flutter`, `flutter pub get` + `flutter analyze` pass with 1 pre-existing info).
