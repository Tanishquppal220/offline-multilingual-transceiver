import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sih_voice_bridge/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.sih.voicebridge/native'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.sih.voicebridge/native_events'),
      (MethodCall methodCall) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.sih.voicebridge/native'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.sih.voicebridge/native_events'),
      null,
    );
  });

  testWidgets('App meets core Flutter accessibility guidelines', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(const SihVoiceBridgeApp());
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Android 48x48 tap target guideline
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

    // 2. iOS 44x44 tap target guideline
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

    // 3. WCAG text contrast guideline
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    // 4. Labeled tap targets for screen readers
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });
}
