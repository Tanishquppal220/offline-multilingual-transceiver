import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/gps_location.dart';
import '../models/operation_mode.dart';

enum NativeEventType {
  partial,
  finalSentence,
  ttsStarted,
  audioStarted,
  resourceMetrics,
  captureState,
  sttReady,
  sttMetrics,
  captureMetrics,
  modelLoading,
  modelReady,
  status,
  error,
}

NativeEventType nativeEventTypeFromWire(String rawType) {
  switch (rawType) {
    case 'partial':
      return NativeEventType.partial;
    case 'final_sentence':
      return NativeEventType.finalSentence;
    case 'tts_started':
      return NativeEventType.ttsStarted;
    case 'audio_started':
      return NativeEventType.audioStarted;
    case 'resource_metrics':
      return NativeEventType.resourceMetrics;
    case 'capture_state':
      return NativeEventType.captureState;
    case 'stt_ready':
      return NativeEventType.sttReady;
    case 'stt_metrics':
      return NativeEventType.sttMetrics;
    case 'capture_metrics':
      return NativeEventType.captureMetrics;
    case 'model_loading':
      return NativeEventType.modelLoading;
    case 'model_ready':
      return NativeEventType.modelReady;
    case 'error':
      return NativeEventType.error;
    default:
      return NativeEventType.status;
  }
}

class NativeEvent {
  NativeEvent({
    required this.type,
    this.text,
    this.messageId,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final NativeEventType type;
  final String? text;
  final String? messageId;
  final Map<dynamic, dynamic>? payload;
  final DateTime timestamp;

  factory NativeEvent.fromMap(Map<dynamic, dynamic> raw) {
    final String rawType = (raw['type'] ?? 'status').toString();
    return NativeEvent(
      type: nativeEventTypeFromWire(rawType),
      text: raw['text']?.toString(),
      messageId: raw['messageId']?.toString(),
      payload: raw,
      timestamp: raw['timestampEpochMs'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (raw['timestampEpochMs'] as num).toInt())
          : DateTime.now(),
    );
  }
}

class NativeBridgeService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.sih.voicebridge/native',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.sih.voicebridge/native_events',
  );

  final StreamController<NativeEvent> _eventsController =
      StreamController<NativeEvent>.broadcast();

  StreamSubscription<dynamic>? _nativeEventSubscription;
  bool _nativeAvailable = true;
  String? _activeMessageId;

  Stream<NativeEvent> get events => _eventsController.stream;
  bool get nativeAvailable => _nativeAvailable;

  Future<void> initialize({required String languageCode}) async {
    await _subscribeToEventStream();
    await _invoke('initializePipelines', <String, dynamic>{
      'languageCode': languageCode,
    });
  }

  Future<void> setLanguage(String languageCode) async {
    await _invoke('setLanguage', <String, dynamic>{
      'languageCode': languageCode,
    });
  }

  Future<void> setOperationMode(OperationMode mode) async {
    await _invoke('setOperationMode', <String, dynamic>{
      'mode': operationModeToWire(mode),
    });
  }

  Future<bool> startListening({
    required bool ptt,
    required String languageCode,
    required String messageId,
    int? pressedAtEpochMs,
  }) async {
    _activeMessageId = messageId;
    return _invoke('startListening', <String, dynamic>{
      'ptt': ptt,
      'languageCode': languageCode,
      'messageId': messageId,
      'pressedAtEpochMs':
          pressedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> stopListening() async {
    await _invoke(
        'stopListening', <String, dynamic>{'messageId': _activeMessageId});
  }

  Future<void> speakText({
    required String text,
    required bool emergency,
    required String languageCode,
    required String messageId,
  }) async {
    await _invoke('speakText', <String, dynamic>{
      'text': text,
      'emergency': emergency,
      'languageCode': languageCode,
      'messageId': messageId,
    });
  }

  Future<void> setEmergencyOverride(bool enabled) async {
    await _invoke('setEmergencyOverride', <String, dynamic>{
      'enabled': enabled,
    });
  }

  Future<String?> getAppDataDirectoryPath() async {
    try {
      final String? path = await _methodChannel.invokeMethod<String>(
        'getAppDataDirectory',
      );
      if (path == null || path.trim().isEmpty) {
        return null;
      }
      return path.trim();
    } on MissingPluginException {
      _nativeAvailable = false;
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<GpsLocation?> getCurrentLocation() async {
    try {
      final Object? raw =
          await _methodChannel.invokeMethod<dynamic>('getLocation');
      if (raw is Map) {
        return GpsLocation.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasLocationPermission() async {
    try {
      final bool? res =
          await _methodChannel.invokeMethod<bool>('hasLocationPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> startLocationUpdates() async {
    try {
      await _methodChannel.invokeMethod<dynamic>('startLocationUpdates');
    } catch (_) {}
  }

  Future<void> stopLocationUpdates() async {
    try {
      await _methodChannel.invokeMethod<dynamic>('stopLocationUpdates');
    } catch (_) {}
  }

  Future<String?> getWifiGatewayIp() async {
    try {
      final String? ip =
          await _methodChannel.invokeMethod<String>('getWifiGatewayIp');
      if (ip != null && ip.trim().isNotEmpty && ip != '0.0.0.0') {
        return ip.trim();
      }
    } catch (_) {}

    // Pure Dart local network fallback when native channel is unavailable
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final NetworkInterface iface in interfaces) {
        final String name = iface.name.toLowerCase();
        if (name.contains('wlan') ||
            name.contains('wifi') ||
            name.contains('swlan')) {
          for (final InternetAddress addr in iface.addresses) {
            final List<String> parts = addr.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}.1';
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<bool> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _methodChannel.invokeMethod<void>(method, args);
      return true;
    } on MissingPluginException {
      _nativeAvailable = false;
      _emitInvocationError(method,
          'Native pipeline unavailable; no recognition or playback was performed.');
      return false;
    } on PlatformException catch (error) {
      _emitInvocationError(method, error.message ?? error.code);
      return false;
    }
  }

  void _emitInvocationError(String method, String text) {
    if (_eventsController.isClosed) return;
    _eventsController.add(NativeEvent(
      type: NativeEventType.error,
      text: text,
      messageId: _activeMessageId,
      payload: <String, dynamic>{
        'operation': method,
        'captureId': _activeMessageId,
        'captureError': method == 'startListening' || method == 'stopListening',
      },
    ));
  }

  Future<void> _subscribeToEventStream() async {
    if (_nativeEventSubscription != null) {
      return;
    }

    try {
      _nativeEventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic payload) {
          if (payload is Map<dynamic, dynamic>) {
            if (payload['type'] == 'capture_state' &&
                payload['state'] == 'stopped' &&
                payload['captureId'] == _activeMessageId) {
              _activeMessageId = null;
            }
            _eventsController.add(NativeEvent.fromMap(payload));
          }
        },
        onError: (Object error) {
          _eventsController.add(
            NativeEvent(
              type: NativeEventType.error,
              text: error.toString(),
              messageId: _activeMessageId,
            ),
          );
        },
      );
    } on MissingPluginException {
      _nativeAvailable = false;
    }
  }

  Future<void> dispose() async {
    if (_activeMessageId != null) await stopListening();
    await _nativeEventSubscription?.cancel();
    await _eventsController.close();
  }
}
