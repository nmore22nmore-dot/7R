import 'package:flutter_test/flutter_test.dart';
import 'package:n_app/app.dart';

void main() {
  testWidgets('N config screen', (tester) async {
    await tester.pumpWidget(const NApp(configError: true));
    expect(find.textContaining('إعداد Supabase'), findsOneWidget);
  });
}
