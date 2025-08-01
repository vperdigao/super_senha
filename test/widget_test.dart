// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:super_senha/main.dart';

void main() {
  testWidgets('App loads with Super Senha title', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1200, 2000);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(const SuperSenhaApp());

    expect(find.text('Super Senha'), findsOneWidget);
  });
}
