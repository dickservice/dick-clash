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

## Verification baseline

The APK comparison used static analysis only. The rule asset hash above is
checked against the extracted APK resource. Local Flutter 3.44.4/Dart 3.12.2
cannot resolve this checkout's current dependency set (`freezed` requires a
newer Dart SDK); release builds should use the Flutter 3.47.1 toolchain pinned
by the project CI guidance.
