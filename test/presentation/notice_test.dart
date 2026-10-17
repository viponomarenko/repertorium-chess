import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/theme/app_theme.dart';
import 'package:tabiya/presentation/widgets/ui/notice.dart';

Widget _app() => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => NoticeHost(child: child!),
  home: const Scaffold(body: Center(child: Text('screen'))),
);

void main() {
  testWidgets('a notice falls in at the top, offers its action and leaves', (tester) async {
    await tester.pumpWidget(_app());
    var undone = 0;
    showNotice('Move added', actionLabel: 'Undo', onAction: () => undone++);
    await tester.pump();
    await tester.pumpAndSettle();

    final text = find.text('Move added');
    expect(text, findsOneWidget);
    // In the top part of the screen, clear of the thumb.
    expect(tester.getCenter(text).dy, lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio / 4));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(text, findsNothing);
  });

  testWidgets('a notice goes away by itself, a new one replaces the old', (tester) async {
    await tester.pumpWidget(_app());
    showNotice('First');
    await tester.pumpAndSettle();
    showNotice('Second');
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.pump(NoticeHost.plain);
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('a flick up puts the notice away', (tester) async {
    await tester.pumpWidget(_app());
    showNotice('Saved');
    await tester.pumpAndSettle();
    await tester.fling(find.text('Saved'), const Offset(0, -80), 800);
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('without motion the notice simply appears', (tester) async {
    await tester.pumpWidget(MediaQuery(data: const MediaQueryData(disableAnimations: true), child: _app()));
    showNotice('Instant');
    await tester.pump();
    expect(find.text('Instant'), findsOneWidget);
    await tester.pump(NoticeHost.plain);
    await tester.pump();
    expect(find.text('Instant'), findsNothing);
  });

  testWidgets('a notice is as wide as its words, at most 90 % of the screen', (tester) async {
    await tester.pumpWidget(_app());
    final screen = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    Finder capsule(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(ClipPath)).first;

    showNotice('Ok');
    await tester.pumpAndSettle();
    final short = tester.getSize(capsule('Ok'));
    expect(short.width, lessThan(screen / 3), reason: 'a short notice is a small capsule');

    final long = List.filled(30, 'word').join(' ');
    showNotice(long, actionLabel: 'Undo', onAction: () {});
    await tester.pumpAndSettle();
    final wide = tester.getSize(capsule(long));
    expect(wide.width, lessThanOrEqualTo(screen * NoticeHost.maxWidthShare + 0.5));
    expect(wide.height, greaterThan(short.height), reason: 'long text wraps onto more lines');
    expect(find.text('Undo'), findsOneWidget);
    hideNotice();
    await tester.pumpAndSettle();
  });
}
