import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_splash/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('starts at the English login page when signed out', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(const InkSplashApp());
    await tester.pumpAndSettle();

    expect(find.text('InkSplash'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('No account? Create one'), findsOneWidget);
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('register and forgot password are secondary auth views', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(const InkSplashApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('No account? Create one'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);

    await tester.tap(find.text('Forgot password'));
    await tester.pumpAndSettle();
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('6-character code'), findsNothing);
    expect(find.text('Reset code'), findsOneWidget);
    expect(
      find.text('Enter the 6 letters or digits from your email.'),
      findsOneWidget,
    );
  });

  testWidgets('follows Chinese system locale on the login page', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('zh')];
    tester.platformDispatcher.localeTestValue = const Locale('zh');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const InkSplashApp());
    await tester.pumpAndSettle();

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('没有账号？去注册'), findsOneWidget);
    expect(find.text('忘记密码'), findsOneWidget);
  });
}
