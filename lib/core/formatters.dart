/// Locale-aware number formatting (T-18): in Ukrainian the thousands
/// separator is a non-breaking space and the decimal separator a comma.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

String _tag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();

extension NumberFormatting on BuildContext {
  String fmtInt(num n) => NumberFormat.decimalPattern(_tag(this)).format(n);

  String fmtCompact(num n) => NumberFormat.compact(locale: _tag(this)).format(n);

  /// [value] in 0..1.
  String fmtPercent(double value, {int digits = 0}) {
    final f = NumberFormat.percentPattern(_tag(this))..maximumFractionDigits = digits;
    return f.format(value);
  }

  String fmtDecimal(num n, {int digits = 1}) =>
      NumberFormat.decimalPatternDigits(locale: _tag(this), decimalDigits: digits).format(n);

  /// Engine evaluation in pawns with sign: +0,32 / −1,50 / #3.
  String fmtEval({int? cp, int? mate}) {
    if (mate != null) return '#$mate';
    final v = (cp ?? 0) / 100;
    final s = NumberFormat.decimalPatternDigits(locale: _tag(this), decimalDigits: 2).format(v.abs());
    return '${v > 0 ? '+' : (v < 0 ? '−' : '')}$s';
  }

  String fmtShortDate(DateTime d) => DateFormat.yMMMd(_tag(this)).format(d);

  String fmtDayMonth(DateTime d) => DateFormat.MMMd(_tag(this)).format(d);

  String fmtDateTime(DateTime d) => DateFormat.yMMMd(_tag(this)).add_Hm().format(d);
}
