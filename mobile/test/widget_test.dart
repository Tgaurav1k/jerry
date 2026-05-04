import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jerry_app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  testWidgets('Splash shows jerry title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: JerryApp()));
    await tester.pump();
    expect(find.text('jerry'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
