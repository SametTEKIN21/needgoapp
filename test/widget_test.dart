// NeedGO — temel smoke test.
// Uygulamanın tamamı Supabase.initialize gerektirdiği için burada sadece
// tema renklerinin/temel widget'ların derlendiğini doğruluyoruz.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uygulamam/tema.dart';

void main() {
  testWidgets('NeedGoYazi iki tonlu kelime markasını gösterir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: NeedGoYazi())),
      ),
    );

    expect(find.byType(NeedGoYazi), findsOneWidget);
    expect(renkZemin, const Color(0xFFEEF1EF));
  });
}
