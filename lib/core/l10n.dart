import 'package:flutter/widgets.dart';

import '../l10n/gen/app_localizations.dart';

export '../l10n/gen/app_localizations.dart';

/// A PGN parser message in the user's language. The parser (and the
/// messages stored with imported games) are English; [text] may carry a
/// line number before the message and the offending token after it.
String localizedIssue(AppLocalizations l, String text) {
  final known = {
    'Illegal or unreadable move': l.issueIllegalMove,
    'Unread moves are kept in a comment': l.issueUnreadKept,
    'Unsupported variant': l.issueUnsupportedVariant,
    'Invalid FEN header': l.issueInvalidFen,
    'Malformed header': l.issueMalformedHeader,
    'Unterminated header': l.issueUnterminatedHeader,
    'Variation without a preceding move': l.issueVariationWithoutMove,
    'Unbalanced ")"': l.issueUnbalancedParen,
    'Unclosed variation': l.issueUnclosedVariation,
    'Unterminated comment': l.issueUnterminatedComment,
  };
  for (final e in known.entries) {
    if (text.contains(e.key)) return text.replaceFirst(e.key, e.value);
  }
  return text;
}

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
