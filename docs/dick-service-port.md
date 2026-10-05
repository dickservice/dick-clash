# Dick Service port status

## Scope and evidence boundary

This fork ports Dick Service v1.0.15 differences that are supported by the
available APK resources, reconstructed Dick AOT, reachable AOT call sites, and
source comparison. It is not a claim of byte-for-byte or exhaustive behavioral
parity. The original FlClash AOT was not reconstructed, and the Dick APK was
not executed on a device in this workspace.

Static evidence does not establish pagination, token refresh, payment
callback/polling, offline grace, exact core behavior, Firebase telemetry
behavior, or the complete profile predicate used during logout. Those items
remain explicitly unimplemented or marked unknown rather than guessed.

## Integrated audit checkpoint (pending current commit)

The current workdir adds the verified page/lifecycle parity changes listed below.
The commit hash will be filled by the repository history after this checkpoint is
committed and pushed. Focused tests passed; full analyzer retains only the
pre-existing `prefer_const_constructors` info in
`test/widgets/scrollbar_inset_test.dart:18:24`.

## Previous integrated audit checkpoint (5e9c9d6)

The previous integrated checkpoint was committed and pushed as `5e9c9d6`
(`fix: align Dick Service gate/logout/orders with AOT evidence`):

- `HEAD == origin/main == 5e9c9d6` at that checkpoint.
- Focused Dick Service suites passed 17–18 tests
  (`dick_service_api` / `dick_service_expiry_cache` / `dick_service_script`)
  with the same asset-hook protocol.
- Native asset hooks (`hooks.user_defines.setup.build_assets` and
  `hooks.user_defines.rust_api.build_assets`) were temporarily disabled for
  Dart tests and restored to `true` afterward; this is not an Android
  release-build or device verification.
- `flutter analyze --no-pub` reported only the pre-existing
  const-constructor info in `test/widgets/scrollbar_inset_test.dart`.
- `assets/data/dick_rule.js` remained byte-for-byte unchanged at 55,840 bytes
  with SHA-256
  `d2b761ac9b854c16fe4df2108e1c34c3fd889d7a55c867a306227de8aa0df55c`.

The earlier `c25c2cb` checkpoint had the broader 61-test integration suite.
Since then the residual audit corrections (login error mapping
`0x88ba8c` 401/422, plan fetch without `_throwIfFailed` `0x8b631c`, strict
`Map.from` list conversion, `plan.prices`-only reset provenance
`0x6867a4`, and logout/profile gate alignment) were integrated and verified
before `5e9c9d6` was pushed.

This document now records the current workdir
`/root/.openclaw/workspace/work/flclash-diff/fork` (the previously cited
`/root/.openclaw/work/flclash-diff/fork` was invalid).

## Implemented from AOT

### Current page and lifecycle alignment

- Mine redemption is an AOT-style scroll-controlled modal bottom sheet: a
  successful redemption shows the result, returns `true`, and Mine reloads the
  subscription. The sheet uses the exact AOT explanatory text and loading text.
- Shop and Tickets now use `RefreshIndicator` with always-scrollable content and
  await their reload futures, matching the AOT pull-to-refresh interaction.
- The purchase sheet is scrollable, shows the AOT `当前选择：<周期> · <价格>`
  summary, uses `正在创建订单...`, and preserves the AOT missing-credential
  text `请输入官网账号和密码`.
- Mine now exposes AOT top-bar actions for `兑换码`, `退出登录`, and `刷新`,
  and removes the duplicate Shop/Orders/Tickets body navigation controls.
- The expiry gate keeps the original child under an opaque full-screen overlay,
  prevents back navigation with `PopScope`, and routes `取消` through
  `SystemAction.handleExit`, matching the reconstructed AOT widget structure.
- Application disposal is asynchronous and follows the AOT cleanup order:
  destroy links, cancel the profile timer, close the core, then invoke the exit
  coordinator. The current fork's `close()` is the source-level equivalent of
  the fork interface's core destruction operation.


### API and models (`lib/common/dick_service_api.dart`, `lib/common/dick_service_models.dart`)

- Base URL: `https://airport.dicksupport.top`.
- Recovered AuroraDeck user agent (`AuroraDeck/7.4.2 (Android; ndk-aurora-74; rv:20260630)`),
  client ID (`ndk-aurora-74`), signing key (`c9f1f637772c44f72f6914d02db94f5e4e0d3d9a833af0d6c70ba0a6e56bb7a4`),
  header names `X-Client-Id/Ts/Nonce/Sign/Sign-Version`, and HMAC input order
  `method\npath?query\nts\nnonce\nsha256(canonicalBody)` from
  `aot-dick-full/asm/fl_clash/common/dick_service_api.dart`.
- UUID-v4 signing nonce and canonical body hashing.
- Login body `{email, password}` and `auth_data`/`accessToken` extraction.
- Endpoints as literals: `POST /api/v1/passport/auth/login`,
  `GET /api/v1/user/getSubscribe`, `GET /api/v1/user/info`,
  `GET /api/v1/guest/plan/fetch`, `GET /api/v1/user/order/fetch`,
  `POST /api/v1/user/order/save`, `POST /api/v1/user/order/checkout`,
  `POST /api/v1/user/order/cancel`, `GET /api/v1/user/ticket/fetch`,
  `POST /api/v1/user/ticket/save`, `POST /api/v1/user/gift-card/redeem`,
  `GET /api/v1/user/resetSecurity`.
- Outer `login` maps only HTTP 401 and 422 Dio responses to `账号或密码错误`
  (AOT `0x88ba8c` class `0xb52`, tagged `0x322`/`0x34c`). Server-level
  `fail`/`error` responses continue through `_throwIfFailed` (`0x67ac6c`) and
  preserve their server message.
- `fetchPlans` does not call `_throwIfFailed` before reading `data`; a
  `{status: fail}` response reaches `套餐列表返回格式异常` as in AOT `0x8b631c`.
- Plan, order, and ticket list mapping uses strict
  `Map<String, dynamic>.from` conversion. Non-map list elements are not
  silently filtered (AOT `LinkedHashMap.from` at `0x8b668c`, `0x90db00`,
  `0x920608`).
- Plan prices are period-keyed positive numeric values and preserve string
  price IDs (`DickServicePlan.fromJson` `0x8b66b0`).
- Order fetch supports `data.orders` and direct-list shapes
  (`0x90d8d4..0x90d9dc`); ticket fetch supports `data.tickets` and direct-list
  (`0x92048c..0x92058c`).
- Traffic reset retains the dedicated `createTrafficResetOrder` boundary
  (`0x8b3c60`) delegating to `createOrder` with period `reset_price`.
- Observed write bodies for order create/checkout/cancel, gift-card redeem,
  ticket create, and reset-security are implemented.
- Checkout response parsing supports URL and HTML branches without issuing an
  unverified payment request, preserving `支付链接返回为空`.
- `DickServiceSubscribe.resetTraffic` and `resetPrice` are derived from the
  selected `plan.prices` map only (`0x6867a4..0x686e64`). A payload with no
  `plan` map does not gain reset values from a root-level `prices` map.
- `validateStatus: (s) => s != null && s < 500` at `0x67b090` with false
  closure `0x67b754` is preserved; it gates the outer login 401/422 check.
- Tests cover signing, UUID-v4 nonce, typed list unwrapping, strict
  non-map rejection (`TypeError`), subscribe semantics, gift summary,
  checkout errors, login bodies/validation, and write bodies.

### Account and state

- Bound Dick profile marker:
  `https://dicksupport.top/__dick_service_user_bound_subscribe__`
  (`0x67bb6c`) and resolution via `fetchSubscribeUrlFromAuthData` (`0x67a64c`).
- Account pages: login, plans/shop, orders, tickets, gift-card redemption,
  payment WebView, cancellation, subscription reset, traffic reset, and logout.
- Bootstrap account-status refresh, persisted alert deduplication via
  `dick_service_last_account_alert`, and the observed 30-minute refresh timer
  (`0x6b49d200`/`0x973a88`) are represented.
- Expiry cache keys, millisecond local timestamps, 60-second rollback lock
  (`60000` ms), signature validation, missing/tampered-cache handling, and
  bootstrap auth dependency are represented.
- Traffic warning threshold is `< 0.1` (`0x88cbe4`/`0x88cc68`). The exact
  renewal window (`0x88cd38`), offline grace, and core-stop behavior remain
  unknown.
- Logout clears auth, alert, bootstrap, and expiry state. AOT also resolves
  the subscription URL and iterates profiles via predicate `0x8b5298`/`0x67bb44`;
  the fork currently keeps the strict static-bound cleanup until that predicate
  is captured.

### Built-in script and navigation

- `Script.builtInDickService()` uses ID `-10086`, label `Dick Service`,
  `DateTime(2026)`, and `assets/data/dick_rule.js`.
- Injected transiently by `Scripts.build()`; not persisted in the database.
- Null and `-10086` script-mode values use the recovered default.
- Dick account entries (Mine, Shop, Orders, Tickets) precede the original
  shared navigation entries (`0xc56b24..0xc57208`); shared order and
  conditional Proxies/Logs behavior remain unchanged.

### Android and branding

- Android application ID: `org.dickservice.client` (debug `.dev` preserved).
- Android label and service branding: `Dick Service`.
- `dickservice://` accepted alongside upstream configuration schemes.
- Firebase package entries match the release/debug/development application IDs
  (see native section for behavioral caveat).
- `assets/data/dick_rule.js` bundled byte-for-byte (hash above).
- Android implementation namespace remains `com.follow.clash.*`, matching
  the APK. Launcher/round icons, adaptive foreground, and TV banner are
  byte-for-byte from the Dick APK.

### Shared UI and startup

- Telegram link is `https://t.me/dickvpngroup` (AOT `0xab7ac8`).
- Project and reachable updater endpoint use `dickservice/dick-clash`
  (`Request::checkForUpdate` `0x9792bc`, `_checkGitHubReleaseUpdate`
  `0x979334`, endpoint `dick.libapp.strings:34393`).
- Dick startup wraps HomePage in the account/bootstrap gate
  (`Instance_DickServiceBootstrapGate`).
- VPN property defaults remain `enable=true`, `systemProxy=true`, unchanged.
- Effective external-controller config default remains closed; open enum
  address is `127.0.0.1:9090` (`0x67b090` mapping).

## Known provenance conflicts and residual gaps

- **About core link:** The fork now follows the APK closure at `0xab7774`
  and opens `https://github.com/chen08209/Clash.Meta/tree/FlClash`
  (`0xab7a70`). This changes only the displayed Core link, not the native
  core revision. Project/updater retain `dickservice/dick-clash`.
- **Logout URL reconciliation:** AOT Mine `_logout` (`0x8b40cc`) fetches the
  subscription URL and iterates profiles; the fork keeps strict static-bound
  matching until the predicate `0x8b5298` is captured from runtime/AOT detail.
- **Bootstrap/expiry:** exact warning strings/ordering, timer interval
  literal, offline grace, and core-stop operation (`handleExit` candidate)
  remain unverified. Bootstrap completion itself is now
  `bootstrap_done || hasDickServiceBound` per `0x97ad58` (auth only gates
  `_checkAccountStatus` at `0x97ad44`), and `normalizedExpiredAt` `0x6865f8`
  is `hasActivePlan && expiredAt<=0 ? -1 : expiredAt` (seconds).
- **Pagination/token refresh/payment callbacks/polling** remain unimplemented.

## Native residual audit (read-only)

Source: `reports/audit-native-residual.md` (no fork source edits).

- **Signing identity is a real difference.** Both APKs use APK Signature
  Scheme v2 with no JAR `META-INF`. FlClash signer DN `O=com.follow.clash`,
  cert SHA-256 `2859e236b6c1c6073773752678c52e8e902a9503ae9beed6729ca999c376841c`,
  pub-key SHA-256 `a258cd929c3074be1f99ac55c473383a55d24eee833b4c5d520e040e86dc2069`.
  Dick 1.0.15 signer DN `CN=Dick Service, OU=Dick Service, O=Dick Service`,
  cert SHA-256 `8b65aee39fd8bd5b0f6f11a7b4d71414d28e3948be94c7043f5702b0511304ea`,
  pub-key SHA-256 `d9ee415e63592ca7ed70d383048ef853bc8b2beb847e0333fd2ba518a5659905`.
  No `android/app/keystore.jks` is present in the checkout; no private key is
  inferred. Record `apksigner verify --print-certs` digests for any release.
- **Firebase resource removal is packaging-level, not proven disablement.**
  FlClash `res/values/strings.xml` contains `gcm_defaultSenderId`,
  `google_app_id`, `google_api_key`, etc.; Dick contains none of those values
  but retains the same Firebase component declarations, native libraries,
  `firebase-analytics.properties`, and keep files. Checked-in
  `google-services.json` is placeholder. Do not claim no-telemetry from
  resource deletion alone; remove dependencies or supply a valid Dick config
  and test merged manifest/runtime if that behavior is intended.
- **No additional Dick-only native service/permission.** Both APKs have 20
  uses-permissions, 2 signature permissions, 3 optional features, 4 activities,
  12 services, 4 receivers, 5 providers. Differences are package-derived
  authorities/actions, labels, and the `dickservice` scheme.
- **Core revision differs.** FlClash `libclash.so` is Go `go1.24.0`, VCS
  `45015f856b44cb52cca755c04c885d73c45ae6b9` (2026-05-29), modified. Dick is Go
  `go1.24.4`, module `core v0.8.94-0.20260705130944-5b6138390317+dirty`, VCS
  `5b6138390317a12ac977829eff9d00a21affb8ea` (2026-07-05), modified. The Dick
  revision/dirty diff is not present locally; Go/toolchain versions in fork
  workflows differ (fork Flutter 3.47.1 / Go 1.26.4 vs source 3.41.9 / 1.24.0).
  Exact reproduction is blocked by missing provenance, keystore, dirty diff,
  and toolchains.
- **Exact APK reproduction is not currently supported.** Both APK ZIPs have
  1981 timestamps, AGP `8.12.2`, v2-signed; entry counts differ (689 vs 687)
  due to `dick_rule.js`. No reproducible-build lock/container was found.

Do not make another native/source patch from these APK differences without
establishing release provenance (authorized key, Dick core source+diff,
build manifests/toolchains) and an explicit Firebase decision.

## Verification protocol

Before accepting the residual API patch as the new verified checkpoint:

1. Temporarily set both `hooks.user_defines.setup.build_assets` and
   `hooks.user_defines.rust_api.build_assets` to `false` in `pubspec.yaml`.
2. Run `dart format`, focused Dick Service tests, broader `flutter test` if
   available, and `flutter analyze --no-pub` via `/opt/flutter`.
3. Restore both hook values to `true` and verify the diff contains no hook
   changes (`git diff --check` clean except intended files).
4. Recheck `dick_rule.js` size and SHA-256.
5. Review `git diff --stat`, commit, push `main`, and verify a clean worktree
   with `HEAD == origin/main`.

Current AOT anchor addresses: `normalizedExpiredAt 0x6865f8`,
`isTimeBasedExpired 0x685f34`, `expireTime 0x685fdc`, `isExpired 0x685ecc`,
`shouldWarnTrafficReset 0x88cbe4`, `shouldWarnRenewal 0x88cd38`,
bootstrap `_load 0x97abd8` / closure `0x97ad58` / build `0x889464`,
`fetchSubscribeUrlFromAuthData 0x67a64c`, `isDickServiceBound 0x67bb44`.

Evidence is retained in:

- `work/flclash-diff/reports/audit-api-full.md`
- `work/flclash-diff/reports/audit-api-residual.md`
- `work/flclash-diff/reports/audit-apk-wide.md`
- `work/flclash-diff/reports/audit-lifecycle-residual.md`
- `work/flclash-diff/reports/audit-native-residual.md`
- `work/flclash-diff/reports/audit-pages-full.md`
- `work/flclash-diff/reports/audit-shared-aot.md`
- `work/flclash-diff/reports/audit-shared-residual.md`
- `work/flclash-diff/reports/audit-state-full.md`
