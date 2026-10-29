import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:strongbody_buyer/modules/post_request/presentation/widgets/review/review_fields.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool removed}) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var removeTaps = 0;
    var undoTaps = 0;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ReviewVoiceNoteRow(
                duration: const Duration(seconds: 9),
                removed: removed,
                onRemove: () => removeTaps++,
                onUndo: () => undoTaps++,
              ),
            ),
          ),
        ),
      ),
    );
    if (removed) {
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      await tester.tap(find.byType(OutlinedButton));
      expect(undoTaps, 1);
    } else {
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      expect(removeTaps, 1);
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets('voice note row: trash', (t) => pump(t, removed: false));
  testWidgets('voice note row: undo remove', (t) => pump(t, removed: true));
}
