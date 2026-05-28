import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_contest/widgets/gradient_button.dart';

void main() {
  testWidgets('GradientButton renders uppercase label and handles tap', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradientButton(
            label: 'Login with Google',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('LOGIN WITH GOOGLE'), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
