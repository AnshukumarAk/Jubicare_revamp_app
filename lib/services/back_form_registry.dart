/// Back-button → inline-form bridge (user bug 2026-08-21: "back from the
/// screen mark check-out goes to the last opened screen instead of the
/// attend list").
///
/// The role shells keep every tab alive in an IndexedStack and their
/// PopScope rewinds through tab HISTORY on back. When a tab hosts an
/// inline form (attendance check-in/out), the form must consume the first
/// back press — close and show the tab's list — before the shell starts
/// switching tabs.
///
/// Each form state registers a closer under a stable key in initState and
/// unregisters in dispose. The shell asks `close(key)` for its ACTIVE tab
/// only; the closer returns true when it actually closed something (the
/// back press is then absorbed).
class BackFormRegistry {
  BackFormRegistry._();

  static final Map<String, bool Function()> _closers = {};

  static void register(String key, bool Function() closer) =>
      _closers[key] = closer;

  static void unregister(String key) => _closers.remove(key);

  /// Returns true if a registered closer absorbed the back press.
  static bool close(String key) => _closers[key]?.call() ?? false;
}
