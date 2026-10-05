// Port of AOT ProfileExtension.isDickServiceBound — static reconstruction.
// Evidence: aot-dick-full/asm/fl_clash/models/profile.dart
// addr 0x67bb44 (isDickServiceBound) + 0x66c17c dick_service_auth_data + 0x67bb6c bound URL
// Do NOT treat as production contract until capture.

import 'package:fl_clash/models/profile.dart';

/// AOT constant: https://dicksupport.top/__dick_service_user_bound_subscribe__
const kDickServiceBoundSubscribeUrl =
    'https://dicksupport.top/__dick_service_user_bound_subscribe__';

/// SharedPreferences key where login saves raw auth JSON/string
const kDickServiceAuthDataKey = 'dick_service_auth_data';

/// Pure predicate for the AOT logout reconciliation helper.
/// AOT fetches the current subscription URL before deleting profiles
/// (0x8b40cc / 0x8b41d4 -> 0x8b42d0 iterator / 0x8b5298 predicate).
/// The exact predicate (static marker vs URL equality vs both) is not yet
/// fully recovered, so callers must pass both signals explicitly; no
/// deletion decisions are made inside the API/profile layer itself.
bool shouldRemoveDickServiceProfileOnLogout({
  required Profile profile,
  required String? resolvedSubscribeUrl,
}) {
  if (profile.isDickServiceBound) return true;
  if (resolvedSubscribeUrl != null &&
      resolvedSubscribeUrl.isNotEmpty &&
      profile.url == resolvedSubscribeUrl) {
    return true;
  }
  return false;
}

extension DickServiceProfileExtension on Profile {
  /// AOT: ProfileExtension.isDickServiceBound — string equality on url
  /// addr: 0x67bb44, size 0x58: loads url field and compares to bound URL via ==.
  bool get isDickServiceBound => url == kDickServiceBoundSubscribeUrl;
}

extension DickServiceProfileListExtension on List<Profile> {
  Profile? get dickServiceBoundProfile {
    for (final p in this) {
      if (p.isDickServiceBound) return p;
    }
    return null;
  }

  bool get hasDickServiceBound => dickServiceBoundProfile != null;

  List<Profile> dickServiceLogoutCandidates(String? resolvedSubscribeUrl) =>
      where(
        (p) => shouldRemoveDickServiceProfileOnLogout(
          profile: p,
          resolvedSubscribeUrl: resolvedSubscribeUrl,
        ),
      ).toList();
}
