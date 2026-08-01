import 'package:ecole_primaire/data/app_state.dart';
import 'package:ecole_primaire/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EcoleApp renders the login screen', (tester) async {
    final state = AppState();

    await tester.pumpWidget(EcoleApp(state: state));

    expect(find.text('Se connecter'), findsOneWidget);
  });
}
