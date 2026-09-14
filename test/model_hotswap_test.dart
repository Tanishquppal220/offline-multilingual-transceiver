import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_voice_bridge/app/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('STT Model Hot-Swap Tests', () {
    final List<MethodCall> methodCalls = <MethodCall>[];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.sih.voicebridge/native'),
        (MethodCall call) async {
          methodCalls.add(call);
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.sih.voicebridge/native_events'),
        (MethodCall call) async => null,
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

    test('Initial STT engine defaults to conformer or whisper and can be hot-swapped', () async {
      final AppController controller = AppController();

      expect(controller.selectedSttEngine, isIn(<String>['conformer', 'whisper']));

      // Hot swap to whisper
      await controller.setSttEngine('whisper');
      expect(controller.selectedSttEngine, 'whisper');
      expect(controller.status, contains('Whisper'));

      // Check method channel invocation
      final MethodCall whisperCall = methodCalls.firstWhere(
        (MethodCall call) => call.method == 'setSttEngine',
      );
      expect(whisperCall.arguments, <String, dynamic>{'engineType': 'whisper'});

      // Hot swap to conformer
      await controller.setSttEngine('conformer');
      expect(controller.selectedSttEngine, 'conformer');
      expect(controller.status, contains('Conformer'));

      final List<MethodCall> conformerCalls = methodCalls
          .where((MethodCall call) => call.method == 'setSttEngine')
          .toList();
      expect(conformerCalls.last.arguments, <String, dynamic>{'engineType': 'conformer'});

      controller.dispose();
    });
  });
}
