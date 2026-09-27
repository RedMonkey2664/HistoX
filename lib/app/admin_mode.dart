import 'package:flutter/foundation.dart';

/// Whether this build carries the admin panel.
///
/// **Why this is gated at all.** The panel unlocks Pro, clears progress and
/// opens every level. In a store build that is the paywall handed away to
/// anyone who finds the settings sheet — the same hole `kPreviewUnlockAllowed`
/// was added to close, and grounds for rejection besides.
///
/// So: on in debug and profile builds, off in release — unless the build was
/// made deliberately with
///
///     flutter build apk --release --dart-define=HISTOX_ADMIN=true
///
/// which exists for a signed demo or a device test where debug is impractical.
/// A build made that way must never be uploaded to a store.
abstract final class AdminMode {
  static const bool _forced = bool.fromEnvironment('HISTOX_ADMIN');

  static const bool enabled = !kReleaseMode || _forced;

  /// True when the panel is present *because* somebody asked for it in a
  /// release build. The panel says so on screen, so a demo build cannot be
  /// mistaken for a shippable one.
  static const bool isForcedIntoRelease = kReleaseMode && _forced;
}
