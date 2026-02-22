import "package:flutter_test/flutter_test.dart";
import "package:now_mobile/main.dart";

void main() {
  testWidgets("NOW baslangic ekranini aciyor", (tester) async {
    await tester.pumpWidget(const NowApp());

    expect(find.text("NOW | 24 Saatlik Sosyallesme"), findsOneWidget);
    expect(find.text("1) Kayit"), findsOneWidget);
    expect(find.text("Kayit Ol ve Devam Et"), findsOneWidget);
  });
}
