import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('renders VAE generator screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('VAE Digit Generator'), findsOneWidget);
    expect(find.text('Número a generar'), findsOneWidget);
    expect(find.text('Generar imagen'), findsOneWidget);
  });
}
