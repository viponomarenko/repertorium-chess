import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/theme/app_icons.dart';
import 'package:tabiya/presentation/theme/app_theme.dart';
import 'package:tabiya/presentation/widgets/comment_text.dart';

/// A comment under the board stands out (D-109): an icon and full ink, not
/// the grey of hints.
void main() {
  Future<ThemeData> pump(WidgetTester tester, Widget child) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: theme, home: Scaffold(body: child)),
      ),
    );
    return theme;
  }

  testWidgets('icon and text in the strongest ink', (tester) async {
    final theme = await pump(tester, const CommentText('Тут головне - тиснути на e5.'));
    final icon = tester.widget<Icon>(find.byIcon(AppIcons.comment));
    expect(icon.color, theme.colorScheme.onSurface);
    final rich = tester.widget<RichText>(find.descendant(of: find.byType(CommentText), matching: find.byType(RichText)).last);
    expect(rich.text.style?.color, theme.colorScheme.onSurface);
    expect(find.textContaining('тиснути на e5', findRichText: true), findsOneWidget);
  });

  testWidgets('on a coloured card both take the card ink', (tester) async {
    const ink = Color(0xFF123456);
    await pump(tester, const CommentText('Коментар', color: ink));
    expect(tester.widget<Icon>(find.byIcon(AppIcons.comment)).color, ink);
  });
}
