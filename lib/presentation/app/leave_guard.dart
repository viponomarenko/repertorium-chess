/// Unsaved work on a screen that lives inside a tab.
///
/// A route pop is covered by `PopScope`, but two ways of leaving replace
/// the screen without popping it: tapping the current tab again (back to
/// the tab's first screen) and a link from another tab that opens a
/// different screen in this one. Both ask the guard first.
class LeaveGuard {
  LeaveGuard._();

  /// The same screen can be open twice (in its tab and pushed over it from
  /// a report), so the checks are kept as a stack; the newest one answers.
  static final List<Future<bool> Function()> _checks = [];

  /// Registers the check of the screen that is now on top.
  static void set(Future<bool> Function() check) => _checks.add(check);

  /// Removes [check].
  static void clear(Future<bool> Function() check) => _checks.remove(check);

  /// True when nothing is unsaved, or the user agreed to leave.
  static Future<bool> canLeave() async => _checks.isEmpty || await _checks.last();
}
