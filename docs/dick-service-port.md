# Dick Service port status

## Scope and evidence boundary

This fork ports Dick Service v1.0.15 differences that are supported by the
available APK resources, reconstructed Dick AOT, reachable AOT call sites, and
source comparison. It is not a claim of byte-for-byte or exhaustive behavioral
parity. The original FlClash AOT was not reconstructed, and the Dick APK was
not executed on a device in this workspace.

Static evidence does not establish pagination, token refresh, payment
callback/polling, offline grace, exact core behavior, Firebase telemetry
behavior, or the complete native/device behavior. Those items remain explicitly
unimplemented or marked unknown rather than guessed.

## Release-signed emulator checkpoint (f37f8ff)

A self-generated PKCS12 release key now signs the release build, so the
artifacts are genuine `release` (v2-signed, `applicationId org.dickservice.client`,
no `.dev` suffix) rather than debug-signed. The keystore and its passwords live
in gitignored `android/app/keystore.jks` and `android/local.properties`; they are
not committed and must not be.

Emulator functional testing surfaced a real branding-port defect: the Dart
`packageName` constant (Android MethodChannel base) had been changed to
`org.dickservice.client`, while the Kotlin `Components.PACKAGE_NAME` and the
original Dick AOT both use `com.follow.clash`. The release build therefore
failed `service`/`app`/`tile` channel calls with `MissingPluginException`
(`Core.init`, `getLastExitInfo`, `updateExcludeFromRecents`). Fixing the
constant to `com.follow.clash` removed every channel error; a lint test
(`test/lint/android_channel_test.dart`) now pins the Dart base to the Kotlin
`PACKAGE_NAME`.

Verified on 2026-10-07:

- Full Flutter suite after the channel fix: **1,893 passed, 3 skipped, 0 failed**.
- `flutter analyze --no-pub`: **No issues found**.
- Release APK build: **successful** for `android-arm64` and `android-x64`.
- Built `libapp.so` channel base confirmed `com.follow.clash/{service,app,tile}`.
- On `emulator-5554` the release APK installed, launched, walked Disclaimer and
  the Firebase notice, and reached the login screen with **no**
  `MissingPluginException`; the emitted package is `org.dickservice.client`.
- In-place install over the original APK fails with
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (correct: only the original private key
  could update it).

Release artifact hashes (self-signed):

- `app-arm64-v8a-release.apk` SHA-256
  `87dd4ec805de4eaf3c7679e6ab7b97c2c01064f56cdf16290e738d963da07741`.
- `app-x86_64-release.apk` SHA-256
  `9203ec096144b4f61dd831f4d9be95dbd55e38197bfbfb2ee9c9826652fcf4b0`.

Still not established, and not claimable from this evidence:

- **Original signature.** The Dick certificate is `SHA-256 8b65aee3…`; the
  self-signed release is `0bd4400e…`. Only the original private key (CI
  `KEYSTORE`/`KEY_ALIAS`/`STORE_PASSWORD`) can produce an upgrade-compatible
  artifact or a byte-identical signature. A private key cannot be recovered
  from the published certificate.
- **Exact Dick core rebuild.** The embedded core reports
  `v0.8.94-0.20260705130944-5b6138390317+dirty`; revision `5b613839` is not
  present in the mihomo upstream or the local release mirror, and the `dirty`
  source diff was never published, so the binary cannot be reproduced exactly.
- **Physical-device acceptance.** Only `emulator-5554` is available. Real TUN
  routing, Always-on VPN, system revoke, and live payment callbacks still need a
  physical device.

## Integrated audit checkpoint (lifecycle/native closure)

The source checkpoint now includes the regression closure at `6c059a8` plus
Android lifecycle/native fixes currently being validated. `CoreLib` serializes
start/stop work, coalesces concurrent starts, invalidates delayed continuations
after stop/close, and keeps connection waiters tied to their operation. Android
JNI now raises `IllegalStateException` when native TUN startup returns false,
so a failed native start cannot be reported as a successful VPN startup.
`ApplicationState.dispose()` is synchronous, captures provider-owned shutdown
closures before unmount, calls `super.dispose()` synchronously, and preserves
Core-close then exit ordering even when either operation fails.

Verified on 2026-10-07:

- Core/lifecycle and disposal focused tests: **30 passed**.
- Full Flutter suite after the lifecycle changes: **1,891 passed, 3 skipped,
  0 failed**.
- `flutter analyze --no-pub`: **No issues found**.
- JNI TUN success/failure injection test: **passed**.
- Release APK build with both native asset hooks enabled: **successful** for
  `android-arm64` and `android-x64`; artifacts are test-signed `.dev` packages.
- x86_64 test APK installed and launched on `emulator-5554`; process remained
  alive and no fatal Android exception or native-link error was observed.

Artifact hashes:

- `app-arm64-v8a-release.apk` SHA-256
  `09374ddd21673eab4e1b1ae71406ed27cda637c74e44daae0ca0b3e2ec59d599`.
- `app-x86_64-release.apk` SHA-256
  `23ef3974d8a01696d822f65f08df3c12bde39a2c72d1a628d8f5baebda7c8321`.

This remains a test-signed emulator validation, not original-signature or
physical-device acceptance. The original release keystore, exact Dick core
dirty-source diff, and reconstructed original FlClash AOT remain unavailable.

## Integrated audit checkpoint (04f9226 + regression closure)

The source checkpoint `04f9226` includes the `dab78a2..04f9226` model/API,
expiry lifecycle, payment/purchase/ticket, Android logging, and cross-language
core callback ABI corrections described below. Historical audit reports are
snapshots of earlier worktrees, not a current list of unfixed defects.

Regression closure on 2026-10-07 additionally aligns Linux protocol, user-agent,
and Android notification tests with Dick branding; decodes request paths in
the local WebDAV test origin (the branded collection contains a space); teaches
the dead-file lint to recognize public top-level entry functions, with a
regression test; and tests ownership reclamation correctly for both root and
non-root callers. These are test/harness changes, not new app behavior.

Verified in this workspace with Flutter 3.47.1 / Dart 3.13.1:

- Focused API/cache/script tests: **24 passed**.
- Full Flutter suite: **1,875 passed, 3 skipped, 0 failed**.
- `flutter analyze --no-pub`: **No issues found**.
- `go test ./...`: **passed** for `core` (platform has no tests).
- Android app/common/service unit tests: **111 passed** (58/30/23), all
  tasks rerun offline; Gradle reported `BUILD SUCCESSFUL`.
- Both native asset hooks restored to `true`; no `pubspec.yaml` diff.
- Rule asset: **55,840 bytes**, SHA-256
  `d2b761ac9b854c16fe4df2108e1c34c3fd889d7a55c867a306227de8aa0df55c`.
- Formatter and `git diff --check` pass. Detailed command outputs are retained
  under the workspace's `work/flclash-diff/verification/` directory.

This checkpoint does not establish release/device parity: `adb devices` found
no connected device, the release keystore is absent, and the exact Dick native
core revision plus dirty-source diff remains unavailable. Do not invent
pagination, refresh tokens, payment polling, offline grace, or a telemetry
policy to fill those evidence gaps.

## Previous integrated audit checkpoint (dab78a2)

The verified page/lifecycle parity batch was committed and pushed as `a979e7c`
(`fix: align Dick Service pages and lifecycle with APK`). The exact AOT logout
predicate was aligned in `8cd7bce`: remove only profiles whose URL equals the
URL returned by `fetchSubscribeUrlFromAuthData`. The cache rollback-lock correction was committed as `53df5fb`: both an invalid
signature and a clock rollback greater than 60 seconds persist
`dick_service_expired_lock=true`, exactly matching AOT `0x687a88–0x687ab0`.

Subsequent verified page/model checkpoints are now integrated through
`dab78a2`:

- `7e469c7`–`af678a3`: separated page lists, empty/error actions, Shop
  navigation, and order payment/cancellation loading states.
- `8cae4d2`: Mine renewal alerts include `remainingTimeText()`.
- `8170f8d`: Mine uses the APK card hierarchy: plan summary, conditional
  account alert, traffic card, and three-item account action card. The exact
  10% traffic-warning boundary and two-stage reset-subscription confirmation
  are restored.
- `784b48a`: ticket list and creation submit share the AOT `_authData`
  callback and missing-auth guidance.
- `e250526`: Dick Service empty/error views are `ListView` based and strip the
  leading `Exception: ` exactly like the APK, preserving pull-to-refresh on
  short content.
- `fdf1ed4`: renewal uses non-negative `Duration.inDays <= 3`, and traffic
  formatting switches to zero decimals at 100 units, matching AOT
  `0x88cdb8` and `0xab0bf8`.
- `dab78a2`: expiry-time equality counts as expired and negative expiry values
  map to the Unix epoch, matching `0x685fa0` and `0x685ff8`.
- The remaining-time label checks whether the full duration is negative before
  truncating to days, so an expiry from earlier today is `已过期` rather than
  `今天到期` (`0x8f4ca8–0x8f4cd4`).
- Purchase recovery now matches the APK's `_findLatestPayableTradeNo`
  fallback (`0x91f174–0x91f670`): when `order/save` returns no trade number,
  re-fetch orders and select a non-empty, status-0 order with the selected
  plan and period before calling checkout.

The focused Dick Service API/cache/script suites pass 18 tests after these
changes, targeted analysis is clean, both native asset hooks are restored to
`true`, and the rule asset hash remains unchanged. This is still static
evidence-supported parity rather than release/device or signed-binary parity.

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
Since then the residual audit corrections (login's outer DioException mapping
`0x88ba8c`, plan fetch without `_throwIfFailed` `0x8b631c`, strict `Map.from`
list conversion, `plan.prices`-only reset provenance `0x6867a4`, and
logout/profile gate alignment) were integrated and verified before `5e9c9d6`
was pushed.

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


### Android Crashlytics state logging (`android/common/.../GlobalState.kt`)

- Dick's remote-service Binder method `G(Z)` emits the exact log
  `crashlytics disabled for AuroraDeck` when passed `true`, and emits no such
  log for `false` (`decoded-dick/smali/I1/t.smali`, lines 64-78). The same
  true-branch is also reachable from the service state synchronization path in
  `decoded-dick/smali/E1/a0.smali`. The fork preserves the APK's counterintuitive
  branch in `GlobalState.setCrashlytics`; the actual Firebase collection toggle
  and the default-enabled state remain unchanged.
- Dick's Binder `n(IEventInterface?)` logs `RemoveEventListener <true|false>`
  before updating the core listener (`decoded-dick/smali/I1/t.smali`, lines
  191-251). The fork preserves this observable logging in
  `ServiceController.setEventListener`; `true` is emitted when the callback is
  null and `false` when a listener is installed.
- The identical native/Firebase libraries and manifest components do not prove
  a different telemetry policy, so no Firebase dependency or resource change is
  made from static APK evidence alone.

### Android core callback ABI (`android/core`, `core`)

- APK smali gives the native `Core` contract: `startTun(...)` returns `Unit`,
  the action entry is named `invokeAction`, and `TunInterface` exposes
  `protect(Int): Unit` plus
  `resolverProcess(protocol, source, target, uid): String`.
- The decoded APK `VpnService` invokes `resolverProcess` with the procfs UID on
  pre-Q Android and resolves the connection owner through
  `ConnectivityManager` on Q and later. Its address adapter uses
  `URL("https://$address")` before constructing `InetSocketAddress`.
- The fork had drifted to a different JNI/Go ABI (`invokeMethod`, Boolean
  `startTun`, `protect(): Boolean`, and separate UID/package callbacks). This
  was a real compatibility risk, not a naming-only difference: the JNI method
  descriptors and native callback function signatures differed. The fork now
  matches the APK contract across Kotlin, JNI C++, C bridge, Go callback code,
  and `VpnService`, while retaining the fork's independently tested TUN
  locking and callback-release protections.
- This is a static ABI restoration. No Android device or Dick APK/fork
  end-to-end traffic comparison is available, so exact native core behavior,
  callback timing, and platform-specific socket ownership remain unverified.

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
- Outer `login` maps only caught DioExceptions with HTTP 401 or 422 to
  `账号或密码错误` (AOT `0x88ba8c`, class `0xb52`, tagged `0x322`/`0x34c`).
  The global `<500` status validator remains in effect for the login request,
  so ordinary HTTP 401/422 response bodies follow `_asMap`/`_unwrap`; there is
  no login-specific 2xx validator. Server-level `fail`/`error` responses
  continue through `_throwIfFailed` (`0x67ac6c`) and preserve their message.
- `fetchPlans` does not call `_throwIfFailed` before reading `data`; a
  `{status: fail}` response reaches `套餐列表返回格式异常` as in AOT `0x8b631c`.
- Plan, order, and ticket list mapping uses strict
  `Map<String, dynamic>.from` conversion. Non-map list elements are not
  silently filtered (AOT `LinkedHashMap.from` at `0x8b668c`, `0x90db00`,
  `0x920608`).
- Plan prices are period-keyed positive numeric values. The APK reads the
  seven root keys `month_price` through `onetime_price`, maps them to the
  labels `月付` through `一次性`, and filters plans whose `show` value is
  exactly `false` (`0x8b6a0c`, `0x8b650c`; period map at `pp+0x2fad8`).
- Order fetch supports `data.orders` and direct-list shapes
  (`0x90d8d4..0x90d9dc`); ticket fetch supports `data.tickets` and direct-list
  (`0x92048c..0x92058c`).
- User-order identifiers fall back through `trade_no`, `tradeNo`, and `id`;
  plan names fall back through `plan_name`, `planName`, and nested
  `plan.name` (`0x90dc84..0x90e02c`). Ticket cards use `updated_at`, matching
  APK ticket object's selected timestamp (`0x9209a4..0x920acc`), with
  `created_at` as the fallback when `updated_at` is absent.
- Gift-card `rewards` and `invite_rewards` are maps, not lists. The APK drops
  entries with null/empty values and formats each as `key: value`, preserving
  the message, optional template name, and invitation prefix
  (`0x90c084..0x90c568`, `0x90c7d8..0x90cba0`).
- Traffic reset retains the dedicated `createTrafficResetOrder` boundary
  (`0x8b3c60`) delegating to `createOrder` with period `reset_price`.
- Observed write bodies for order create/checkout/cancel, gift-card redeem,
  ticket create, and reset-security are implemented.
- Checkout response parsing supports URL and HTML branches without issuing an
  unverified payment request, preserving `支付链接返回为空`.
- Purchase submission has the APK's early busy-state return, preventing a
  second tap from creating another order while the first request is running
  (`0x91ef40..0x91ef50`).
- Ticket creation has the same AOT submit-state guard: repeated submission
  while the request is active returns before reading or sending the form
  (`0x921478..0x921488`).
- Order-card payment and cancellation actions use expanded controls that fill
  the available action row, matching the APK's `Expanded` wrappers around the
  `继续支付` and `取消支付` buttons (`0xab23ec..0xab2410`,
  `0xab25b4..0xab25d8`).
- The payment WebView reports navigation progress into state and renders a
  determinate `LinearProgressIndicator` while progress is below 100
  (`0x985268..0x985324`, `0x90efe4..0x90f088`). Its order number is shown in
  the body header, and the AOT conditional `返回` text button appears only
  when WebView history can go back; it calls `goBack()` and refreshes that
  state (`0x90ee04..0x90ee48`, `0x91d864..0x91d8f0`).
- The APK has one subscription reset-price field. Its intentionally preserved
  lookup is `plan.prices.reset_traffic ?? plan.reset_price`, followed by
  integer coercion (`0x686d24..0x686ea0`); Mine then uses that field as the
  traffic-reset order price (`0x8b2f5c`). A root-level `prices` map and
  `plan.prices.reset_price` are ignored.
- Numeric coercion preserves the APK split: general `_intValue` accepts
  integer strings only (`0x686ff0`), while nullable subscription fields may
  fall back through double parsing (`0x6871b4..0x6871c4`). The plan-ID helper
  prefers a positive candidate but retains the first non-null non-positive
  value when neither candidate is positive (`0x687230..0x6872e8`).
- Login preserves the AOT exhaustion path (`0x88ba8c..0x88bb78`): only HTTP
  401/422 immediately become `账号或密码错误`; every other thrown value is kept
  as `lastError`, and the final message appends that value without an endpoint
  list. `_asMap` also keeps the APK's validation-page/format error wording
  (`0x67adfc..0x67afec`). Recursive auth, URL, and checkout-HTML lookup walks
  maps but intentionally does not descend into lists (`0x67a78c`, `0x88be9c`,
  `0x8b3634`).
- Subscription loading requires the `getSubscribe` response, but wraps the
  subsequent `/api/v1/user/info` fetch in the APK's broad catch and passes
  `null` account info to `DickServiceSubscribe.fromJson` on failure
  (`0x686710..0x686794`).
- User-order `period` remains nullable and is stringified only when present,
  matching `DickServiceUserOrder.fromJson` at `0x90e208..0x90e27c`; the order
  card omits a null or empty period instead of normalizing the model to `''`.
- Ticket display time follows the APK factory fallback: stringify
  `created_at`, then use stringified `updated_at` when present, otherwise the
  created value (`0x9209a4..0x920a90`).
- Expiry refresh preserves the AOT control flow at `0x685a50..0x685ec0`:
  concurrent checks return instead of queuing a forced retry; a fetch failure
  reloads the cache and is otherwise swallowed; and a refreshed subscription
  uses full `isExpired` semantics, including no active plan. A valid,
  non-expired cache clears any stale overlay before `shouldRefresh` can return
  early (`0x685c60..0x685cc8`). The APK's counterintuitive expired-cache split
  is retained: a normal check proceeds to fetch immediately, while a forced
  check first applies the non-forced `shouldRefresh()` result
  (`0x685c1c..0x685c5c`).
- Expiry-gate startup registers the initial check as a post-frame callback
  before creating the periodic timer (`0x973b50..0x973c60`). The timer duration
  object `Duration@c14d31` is `1,800,000,000µs` (30 minutes). Disposal removes
  the lifecycle observer and cancels that timer without closing the API client
  (`0x99a6bc..0x99a718`).
- The expiry overlay's renewal action clears the current overlay/message before
  pushing `DickServiceShopPage` and does not force-refresh on route return
  (`0x83b420..0x83b4f8`). Later resume/timer checks retain responsibility for
  revalidation.
- `validateStatus: (s) => s != null && s < 500` at `0x67b090` with false
  closure `0x67b754` is preserved globally, including the login request; the
  outer 401/422 mapping applies only when a DioException is actually thrown.
- Tests cover signing, UUID-v4 nonce, typed list unwrapping, strict
  non-map rejection (`TypeError`), subscribe semantics, map-based gift
  summary, plan visibility/root price keys,
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
  bootstrap bound-profile/auth boundaries are represented.
- Traffic warning threshold is `< 0.1` (`0x88cbe4`/`0x88cc68`). Renewal
  uses a non-negative remaining duration with `inDays <= 3` (`0x88cd38`).
  Offline grace and core-stop behavior remain unverified.
- Logout clears auth, alert, bootstrap, and expiry state. AOT also resolves
  the subscription URL and iterates profiles via predicate `0x8b5298`/`0x67bb44`;
  the fork resolves that URL and removes every profile whose URL exactly
  matches it. The static bound marker remains the separate profile-creation and
  account-bound predicate.

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
  subscription URL and filters profiles with the exact `0x8b5298` predicate
  `profile.url == resolvedSubscribeUrl`; the fork now matches this behavior.
- **Bootstrap/expiry:** exact warning strings/ordering, offline grace, and
  core-stop semantics remain unverified. The lifecycle identity is resolved:
  `AppLifecycleState@c14061` is `resumed`, matching the fork force-refresh
  callback; timer intervals and async application disposal are also aligned. Bootstrap completion itself is now
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
