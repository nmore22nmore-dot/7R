import 'package:flutter_test/flutter_test.dart';
import 'package:n_app/app.dart';
void main(){
 testWidgets('N config screen', (tester) async {
  await tester.pumpWidget(const NApp(configured:false));
  expect(find.text('N'), findsOneWidget);
 });
}
