import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diemsoluong/main.dart';

void main() {
  testWidgets('App loads HomeScreen successfully with title', (WidgetTester tester) async {
    // Build our app and trigger a frame, wrapped in ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Verify that the title 'AI Đếm Số Lượng Vật Thể' is displayed.
    expect(find.text('AI Đếm Số Lượng Vật Thể'), findsOneWidget);
    
    // Verify that the gallery and camera pick buttons exist.
    expect(find.text('Thư viện'), findsOneWidget);
    expect(find.text('Chụp ảnh'), findsOneWidget);
  });
}
