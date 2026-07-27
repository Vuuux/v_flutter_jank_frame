// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_jank_frame/main.dart';

void main() {
  testWidgets('Comparison demo renders and switches modes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Not Optimized vs Optimized List'), findsOneWidget);
    expect(find.text('Not Optimized'), findsOneWidget);
    expect(find.text('Optimized'), findsOneWidget);
    expect(find.text('Use compute() precomputed data (both lists)'), findsOneWidget);
    expect(find.text('Item #0'), findsOneWidget);
    expect(find.textContaining('Expensive score:'), findsWidgets);

    await tester.tap(find.text('Optimized'));
    await tester.pumpAndSettle();

    expect(find.text('Item #0'), findsOneWidget);
  });
}
