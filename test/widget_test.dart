import 'package:flutter_test/flutter_test.dart';
import 'package:ink_splash/main.dart';

void main() {
  testWidgets('shows V1 account entrypoint', (WidgetTester tester) async {
    await tester.pumpWidget(const InkSplashApp());

    expect(find.text('InkSplash'), findsOneWidget);
    expect(find.text('Cloud account'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
