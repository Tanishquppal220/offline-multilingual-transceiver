import 'dart:async';

import 'package:flutter/material.dart';

import '../models/benchmark_models.dart';
import '../models/connection_config.dart';
import '../models/gps_location.dart';
import '../models/language_option.dart';
import '../models/operation_mode.dart';
import '../models/speech_message.dart';
import '../models/user_profile.dart';
import '../services/benchmark_export_service.dart';
import '../services/benchmark_history_storage_service.dart';
import '../services/benchmark_tracker.dart';
import '../services/native_bridge_service.dart';
import '../services/tcp_message_service.dart';
import '../services/user_profile_storage_service.dart';

class AppController extends ChangeNotifier {
  static const int _maxBenchmarkHistory = 50;

  AppController({
    NativeBridgeService? nativeBridgeService,
    TcpMessageService? tcpMessageService,
    BenchmarkTracker? benchmarkTracker,
    BenchmarkExportService? benchmarkExportService,
    BenchmarkHistoryStorageService? benchmarkHistoryStorageService,
    UserProfileStorageService? userProfileStorageService,
  })  : _nativeBridgeService = nativeBridgeService ?? NativeBridgeService(),
        _tcpMessageService = tcpMessageService ?? TcpMessageService(),
        _benchmarkTracker = benchmarkTracker ?? BenchmarkTracker(),
        _benchmarkExportService =
            benchmarkExportService ?? const BenchmarkExportService(),
        _benchmarkHistoryStorageService =
            benchmarkHistoryStorageService ?? BenchmarkHistoryStorageService(),
        _userProfileStorageService =
            userProfileStorageService ?? UserProfileStorageService();

  final NativeBridgeService _nativeBridgeService;
  final TcpMessageService _tcpMessageService;
  final BenchmarkTracker _benchmarkTracker;
  final BenchmarkExportService _benchmarkExportService;
  final BenchmarkHistoryStorageService _benchmarkHistoryStorageService;
  final UserProfileStorageService _userProfileStorageService;

  StreamSubscription<NativeEvent>? _nativeEventsSub;
  bool _initialized = false;
  bool _isConnected = false;
  bool _isListening = false;
  bool _capturePending = false;
  bool _stopRequested = false;
  bool? _sttReady;
  Map<String, dynamic> _latestSttMetrics = <String, dynamic>{};
  Map<String, dynamic> _latestCaptureMetrics = <String, dynamic>{};
  String _status = 'Booting...';
  String _partialTranscript = '';
  OperationMode _operationMode = OperationMode.walkieTalkie;
  LanguageOption _selectedLanguage = kLanguageOptions.first;
  ConnectionConfig _connectionConfig = ConnectionConfig.initial;
  final List<SpeechMessage> _history = <SpeechMessage>[];
  final List<BenchmarkSnapshot> _benchmarkHistory = <BenchmarkSnapshot>[];
  final Map<String, SpeechMessage> _messageById = <String, SpeechMessage>{};
  BenchmarkSnapshot? _latestBenchmark;
  String? _activeMessageId;
  UserProfile _userProfile = UserProfile.initial;
  GpsLocation? _currentLocation;
  bool _profileSetupNeeded = false;
  String _sttModelName = 'NeMo CTC int8 (EN)';
  String _ttsModelName = 'Android System TTS (en-US)';
  bool _isModelLoading = false;
  String? _modelLoadingMessage;

  bool get isConnected => _isConnected;
  bool get isListening => _isListening;
  bool get isCapturePending => _capturePending;
  Map<String, dynamic> get latestSttMetrics =>
      Map<String, dynamic>.unmodifiable(_latestSttMetrics);
  Map<String, dynamic> get latestCaptureMetrics =>
      Map<String, dynamic>.unmodifiable(_latestCaptureMetrics);
  String get status => _status;
  String get partialTranscript => _partialTranscript;
  OperationMode get operationMode => _operationMode;
  LanguageOption get selectedLanguage => _selectedLanguage;
  ConnectionConfig get connectionConfig => _connectionConfig;
  UserProfile get userProfile => _userProfile;
  GpsLocation? get currentLocation => _currentLocation;
  bool get profileSetupNeeded => _profileSetupNeeded;
  String get sttModelName => _sttModelName;
  String get ttsModelName => _ttsModelName;
  bool get isModelLoading => _isModelLoading;
  String? get modelLoadingMessage => _modelLoadingMessage;
  List<SpeechMessage> get history => List<SpeechMessage>.unmodifiable(_history);

  @visibleForTesting
  void addTestMessage(SpeechMessage message) {
    _history.insert(0, message);
    notifyListeners();
  }
  List<BenchmarkSnapshot> get benchmarkHistory =>
      List<BenchmarkSnapshot>.unmodifiable(_benchmarkHistory);
  BenchmarkSnapshot? get latestBenchmark => _latestBenchmark;
  ResourceBenchmark get resourceBenchmark =>
      _benchmarkTracker.resourceBenchmark;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _tcpMessageService.onMessage = _handleIncomingMessage;
    _tcpMessageService.onStatus = (String status) {
      _status = status;
      notifyListeners();
    };

    _nativeEventsSub = _nativeBridgeService.events.listen(_handleNativeEvent);
    await _nativeBridgeService.initialize(languageCode: _selectedLanguage.code);

    final UserProfile? persistedProfile =
        await _userProfileStorageService.load(
      appDataPathProvider: _nativeBridgeService.getAppDataDirectoryPath,
    );
    if (persistedProfile != null && persistedProfile.isConfigured) {
      _userProfile = persistedProfile;
      _profileSetupNeeded = false;
    } else {
      _profileSetupNeeded = true;
    }

    try {
      await _nativeBridgeService.startLocationUpdates();
      _currentLocation = await _nativeBridgeService.getCurrentLocation();
    } catch (_) {}

    final PersistedBenchmarkHistory persistedHistory =
        await _benchmarkHistoryStorageService.load(
      appDataPathProvider: _nativeBridgeService.getAppDataDirectoryPath,
    );
    _restorePersistedBenchmarkHistory(persistedHistory);

    _status = !_nativeBridgeService.nativeAvailable
        ? 'Native speech unavailable; typed messaging remains available'
        : _sttReady == false
            ? 'Offline STT unavailable; typed messaging remains available'
            : _sttReady == true
                ? 'Ready'
                : 'Preparing offline speech recognition...';
    _initialized = true;
    notifyListeners();
  }

  void updateConnectionConfig(ConnectionConfig config) {
    _connectionConfig = config;
    notifyListeners();
  }

  /// Automatically retrieves the active Wi-Fi Gateway / Hotspot Leader IP
  /// from the native platform and populates client connection settings.
  Future<String?> fetchWifiGatewayIp() async {
    final String? gateway = await _nativeBridgeService.getWifiGatewayIp();
    if (gateway != null && gateway.isNotEmpty) {
      updateConnectionConfig(
        _connectionConfig.copyWith(
          host: gateway,
          runAsServer: false,
        ),
      );
      return gateway;
    }
    return null;
  }

  Future<void> connect() async {
    const int port = ConnectionConfig.networkPort;

    debugPrint(
      'TCP CONNECT: host=${_connectionConfig.host}, '
      'port=$port, '
      'server=${_connectionConfig.runAsServer}',
    );

    try {
      if (_connectionConfig.runAsServer) {
        await _tcpMessageService.startServer(
          port: port,
        );
      } else {
        await _tcpMessageService.connect(
          host: _connectionConfig.host,
          port: port,
        );
      }

      _isConnected = true;

      _status = _connectionConfig.runAsServer
          ? 'Server listening on port $port'
          : 'Connected to ${_connectionConfig.host}:$port';
    } catch (error) {
      _isConnected = false;
      _status = 'Connection failed: $error';

      debugPrint('TCP CONNECTION ERROR: $error');
    }

    notifyListeners();
  }

  Future<void> disconnect() async {
    await _tcpMessageService.close();
    _isConnected = false;
    _status = 'Disconnected';
    notifyListeners();
  }

  Future<void> setLanguage(LanguageOption language) async {
    _selectedLanguage = language;
    _isModelLoading = true;
    _modelLoadingMessage = 'Loading ${language.label} speech model... Please wait 1-2s';
    _sttModelName = 'NeMo CTC (${language.code.toUpperCase()})';
    _ttsModelName = 'Android System TTS (${language.code})';
    _status = 'Loading ${language.label} model...';
    notifyListeners();

    await _nativeBridgeService.setLanguage(language.code);
  }

  Future<void> setOperationMode(OperationMode mode) async {
    _operationMode = mode;
    await _nativeBridgeService.setOperationMode(mode);
    _status = mode == OperationMode.walkieTalkie
        ? 'Walkie-talkie mode'
        : 'Continuous mode';
    notifyListeners();
  }

  Future<void> startPushToTalk() async {
    final DateTime pressedAt = DateTime.now();
    if (_capturePending) {
      return;
    }
    if (_isModelLoading) {
      _status = 'Speech model is loading. Please wait 1-2 seconds...';
      notifyListeners();
      return;
    }
    if (_sttReady == false) {
      _status = 'Offline STT unavailable; no fallback transcript will be sent';
      notifyListeners();
      return;
    }

    final String messageId = _newMessageId();
    _activeMessageId = messageId;
    _capturePending = true;
    _stopRequested = false;
    _isListening = false;
    _partialTranscript = '';
    _status = 'Starting microphone... wait for Listening';
    _benchmarkTracker.mark(messageId, BenchmarkEvent.t0SpeechStart,
        at: pressedAt);

    notifyListeners();
    final bool accepted = await _nativeBridgeService.startListening(
      ptt: _operationMode == OperationMode.walkieTalkie,
      languageCode: _selectedLanguage.code,
      messageId: messageId,
      pressedAtEpochMs: pressedAt.millisecondsSinceEpoch,
    );
    if (!accepted && _activeMessageId == messageId) {
      _capturePending = false;
      _activeMessageId = null;
      _status = 'Could not start native speech capture';
    }
    notifyListeners();
  }

  Future<void> stopPushToTalk() async {
    if (!_capturePending || _stopRequested) {
      return;
    }

    _isListening = false;
    _stopRequested = true;
    _status = 'Finishing captured audio and recognizing speech...';
    notifyListeners();
    await _nativeBridgeService.stopListening();
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    _userProfile = profile.copyWith(isConfigured: true);
    _profileSetupNeeded = false;
    notifyListeners();
    await _userProfileStorageService.save(
      profile: _userProfile,
      appDataPathProvider: _nativeBridgeService.getAppDataDirectoryPath,
    );
  }

  Future<void> refreshLocation() async {
    try {
      final GpsLocation? loc = await _nativeBridgeService.getCurrentLocation();
      if (loc != null) {
        _currentLocation = loc;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> sendTypedMessage(String text, {bool emergency = false}) async {
    final String cleaned = text.trim();
    if (cleaned.isEmpty) {
      return;
    }

    final String messageId = _newMessageId();
    _benchmarkTracker
      ..mark(messageId, BenchmarkEvent.t0SpeechStart)
      ..mark(messageId, BenchmarkEvent.t1SpeechEnd)
      ..mark(messageId, BenchmarkEvent.t2SttFinal);

    final SpeechMessage message = SpeechMessage(
      id: messageId,
      type: emergency ? MessageType.emergency : MessageType.speech,
      languageCode: _selectedLanguage.code,
      message: cleaned,
      timestamp: DateTime.now(),
      origin: MessageOrigin.local,
      senderCallsign: _userProfile.callsign,
      senderRole: _userProfile.role,
      senderSquad: _userProfile.squad,
      location: _userProfile.shareLocation ? _currentLocation : null,
    );

    await _sendOutgoingMessage(message);
  }

  Future<void> sendEmergencyPreset() {
    final String locStr = _currentLocation != null
        ? ' [GPS: ${_currentLocation!.compactCoordinates}]'
        : '';
    final String callsign = _userProfile.callsign;
    final String role = _userProfile.role;

    final String messageText = switch (_selectedLanguage.code.toLowerCase()) {
      'mr' => '$callsign ($role) साठी वैद्यकीय मदत आवश्यक आहे$locStr',
      'hi' => '$callsign ($role) के लिए चिकित्सा सहायता आवश्यक है$locStr',
      'gu' => '$callsign ($role) માટે તબીબી સહાય જરૂરી છે$locStr',
      'ta' => '$callsign ($role) க்கு மருத்துவ உதவி தேவை$locStr',
      'te' => '$callsign ($role) కొరకు వైద్య సహాయం అవసరం$locStr',
      'kn' => '$callsign ($role) ಗೆ ವೈದ್ಯಕೀಯ ನೆರವು ಅಗತ್ಯವಿದೆ$locStr',
      'ml' => '$callsign ($role) ന് അടിയന്തര വൈദ്യസഹായം ആവശ്യമാണ്$locStr',
      'bn' => '$callsign ($role) এর জন্য জরুরি চিকিৎসা সহায়তা প্রয়োজন$locStr',
      'or' => '$callsign ($role) ପାଇଁ ଡାକ୍ତରୀ ସହାୟତା ଆବଶ୍ୟକ$locStr',
      _ => 'Medical assistance required for $callsign ($role)$locStr',
    };

    return sendTypedMessage(messageText, emergency: true);
  }

  void clearHistory() {
    final Set<String> messageIds = <String>{
      ..._history.map((SpeechMessage message) => message.id),
      ..._benchmarkHistory
          .map((BenchmarkSnapshot snapshot) => snapshot.messageId),
    };
    for (final String messageId in messageIds) {
      _benchmarkTracker.clear(messageId);
    }

    _history.clear();
    _benchmarkHistory.clear();
    _messageById.clear();
    _latestBenchmark = null;
    unawaited(
      _benchmarkHistoryStorageService.clear(
        appDataPathProvider: _nativeBridgeService.getAppDataDirectoryPath,
      ),
    );
    notifyListeners();
  }

  String? exportLatestBenchmarkAsJson() {
    final BenchmarkSnapshot? snapshot = _latestBenchmark;
    if (snapshot == null) {
      return null;
    }

    return _benchmarkExportService.toJson(
      snapshot: snapshot,
      resource: _benchmarkTracker.resourceBenchmark,
      message: _lookupMessage(snapshot.messageId),
    );
  }

  String? exportLatestBenchmarkAsCsv() {
    final BenchmarkSnapshot? snapshot = _latestBenchmark;
    if (snapshot == null) {
      return null;
    }

    return _benchmarkExportService.toCsv(
      snapshot: snapshot,
      resource: _benchmarkTracker.resourceBenchmark,
      message: _lookupMessage(snapshot.messageId),
    );
  }

  String? exportBenchmarkHistoryAsJson({int? limit}) {
    if (_benchmarkHistory.isEmpty) {
      return null;
    }

    return _benchmarkExportService.historyToJson(
      snapshots: _benchmarkHistory,
      limit: limit,
      messageLookup: _lookupMessage,
    );
  }

  String? exportBenchmarkHistoryAsCsv({int? limit}) {
    if (_benchmarkHistory.isEmpty) {
      return null;
    }

    return _benchmarkExportService.historyToCsv(
      snapshots: _benchmarkHistory,
      limit: limit,
      messageLookup: _lookupMessage,
    );
  }

  Future<void> _sendOutgoingMessage(SpeechMessage message) async {
    _history.insert(0, message);
    _rememberMessage(message);
    _benchmarkTracker.mark(message.id, BenchmarkEvent.t3MessageSent);

    if (_isConnected) {
      try {
        await _tcpMessageService.send(message);
        _status = 'Message sent';
      } catch (error) {
        _status = 'Send failed: $error';
      }
    } else {
      _status = 'No peer connected. Running one-phone loop.';
      final SpeechMessage loopback = message.copyWith(
        origin: MessageOrigin.remote,
      );
      await _playIncomingMessage(loopback);
    }

    _recordBenchmark(
      _benchmarkTracker.snapshotFor(
        message.id,
        audioDuration: _estimateAudioDuration(message.message),
      ),
    );
    _partialTranscript = '';
    notifyListeners();
  }

  Future<void> _handleIncomingMessage(SpeechMessage message) async {
    await _playIncomingMessage(message.copyWith(origin: MessageOrigin.remote));
    notifyListeners();
  }

  Future<void> _playIncomingMessage(SpeechMessage message) async {
    _history.insert(0, message);
    _rememberMessage(message);
    _benchmarkTracker.mark(message.id, BenchmarkEvent.t4MessageReceived);

    await _nativeBridgeService.speakText(
      text: message.message,
      emergency: message.type == MessageType.emergency,
      languageCode: message.languageCode,
      messageId: message.id,
    );

    _recordBenchmark(
      _benchmarkTracker.snapshotFor(
        message.id,
        audioDuration: _estimateAudioDuration(message.message),
      ),
    );

    _status = message.type == MessageType.emergency
        ? 'Emergency alert queued'
        : 'Message queued for playback';
  }

  void _handleNativeEvent(NativeEvent event) {
    switch (event.type) {
      case NativeEventType.partial:
        _partialTranscript = event.text ?? _partialTranscript;
        notifyListeners();
        break;
      case NativeEventType.finalSentence:
        if (event.payload?['recognitionValid'] != true ||
            event.payload?['fallback'] == true) {
          _status = 'Rejected unverified or fallback speech result';
          notifyListeners();
          break;
        }
        final String transcript = (event.text ?? '').trim();
        if (transcript.isNotEmpty) {
          final String messageId =
              event.messageId ?? _activeMessageId ?? _newMessageId();
          if (_benchmarkTracker.snapshotFor(messageId).marks.t2SttFinal ==
              null) {
            _benchmarkTracker.mark(messageId, BenchmarkEvent.t2SttFinal);
          }
          final SpeechMessage outgoing = SpeechMessage(
            id: messageId,
            type: MessageType.speech,
            languageCode: event.payload?['languageCode']?.toString() ??
                _selectedLanguage.code,
            message: transcript,
            timestamp: DateTime.now(),
            origin: MessageOrigin.local,
            senderCallsign: _userProfile.callsign,
            senderRole: _userProfile.role,
            senderSquad: _userProfile.squad,
            location: _userProfile.shareLocation ? _currentLocation : null,
          );
          unawaited(_sendOutgoingMessage(outgoing));
        }
        break;
      case NativeEventType.ttsStarted:
        if (event.messageId != null) {
          _benchmarkTracker.mark(event.messageId!, BenchmarkEvent.t5TtsStart);
          _status = 'TTS started';
          notifyListeners();
        }
        break;
      case NativeEventType.audioStarted:
        if (event.messageId != null) {
          _benchmarkTracker.mark(
            event.messageId!,
            BenchmarkEvent.t6AudioFirstFrame,
          );
          _recordBenchmark(
            _benchmarkTracker.snapshotFor(
              event.messageId!,
              audioDuration: _estimateAudioDuration(event.text ?? ''),
            ),
          );

          final SpeechMessage? message = _lookupMessage(event.messageId!);
          if (message != null) {
            _status = message.type == MessageType.emergency
                ? 'Emergency alert played'
                : 'Message played';
          }

          notifyListeners();
        }
        break;
      case NativeEventType.resourceMetrics:
        final ResourceBenchmark? resource =
            _parseResourceBenchmark(event.payload);
        if (resource != null) {
          _benchmarkTracker.updateResourceUsage(resource);
          final BenchmarkSnapshot? snapshot = _latestBenchmark;
          if (snapshot != null) {
            _recordBenchmark(
              _benchmarkTracker.snapshotFor(
                snapshot.messageId,
                audioDuration: snapshot.audioDuration,
                processingDuration: snapshot.processingDuration,
              ),
            );
          }
          notifyListeners();
        }
        break;
      case NativeEventType.captureState:
        if (event.payload?['captureId'] != _activeMessageId) break;
        if (event.payload?['state'] == 'recording') {
          _isListening = !_stopRequested;
          if (!_stopRequested) {
            _status = event.text ?? 'Listening';
          }
          if (event.messageId != null) {
            _benchmarkTracker.mark(
                event.messageId!, BenchmarkEvent.t0SpeechStart,
                at: event.timestamp);
          }
        } else if (event.payload?['state'] == 'stopped') {
          _capturePending = false;
          _isListening = false;
          _stopRequested = false;
          _activeMessageId = null;
          if (event.payload?['failed'] == true ||
              _status.startsWith('Finishing') ||
              _status.startsWith('Starting')) {
            _status = event.text ?? 'Recording finished';
          }
        }
        notifyListeners();
        break;
      case NativeEventType.sttReady:
        _sttReady = event.payload?['available'] == true;
        _status = event.text ?? (_sttReady! ? 'STT ready' : 'STT unavailable');
        notifyListeners();
        break;
      case NativeEventType.sttMetrics:
        _latestSttMetrics = Map<String, dynamic>.from(
            event.payload ?? const <String, dynamic>{});
        debugPrint('STT AUDIO: $_latestSttMetrics');
        _recordMeasuredAudio(event);
        notifyListeners();
        break;
      case NativeEventType.captureMetrics:
        _latestCaptureMetrics = Map<String, dynamic>.from(
            event.payload ?? const <String, dynamic>{});
        debugPrint('CAPTURE AUDIO: $_latestCaptureMetrics');
        notifyListeners();
        break;
      case NativeEventType.modelLoading:
        _isModelLoading = true;
        _modelLoadingMessage = event.payload?['message']?.toString() ??
            'Loading speech model... Please wait 1-2s';
        if (event.payload?['sttModel'] != null) {
          _sttModelName = event.payload!['sttModel'].toString();
        }
        if (event.payload?['ttsModel'] != null) {
          _ttsModelName = event.payload!['ttsModel'].toString();
        }
        _status = _modelLoadingMessage!;
        notifyListeners();
        break;
      case NativeEventType.modelReady:
        _isModelLoading = false;
        _modelLoadingMessage = null;
        if (event.payload?['sttModel'] != null) {
          _sttModelName = event.payload!['sttModel'].toString();
        }
        if (event.payload?['ttsModel'] != null) {
          _ttsModelName = event.payload!['ttsModel'].toString();
        }
        if (event.payload?['sttAvailable'] != null) {
          _sttReady = event.payload!['sttAvailable'] == true;
        }
        _status = event.payload?['message']?.toString() ?? 'Speech models ready';
        notifyListeners();
        break;
      case NativeEventType.status:
        if ((event.text ?? '').isNotEmpty) {
          _status = event.text!;
          notifyListeners();
        }
        break;
      case NativeEventType.error:
        if (event.payload?['captureError'] == true &&
            event.payload?['captureId'] == _activeMessageId) {
          _capturePending = false;
          _isListening = false;
          _stopRequested = false;
          _activeMessageId = null;
        }
        _status = 'Native error: ${event.text ?? 'unknown'}';
        notifyListeners();
        break;
    }
  }

  void _recordMeasuredAudio(NativeEvent event) {
    final Map<dynamic, dynamic>? metrics = event.payload;
    final String? messageId = event.messageId;
    if (messageId == null ||
        metrics == null ||
        metrics['recognitionValid'] != true) {
      return;
    }
    final double? audioMs = _parseMetric(metrics['audioDurationMs']);
    final double? processingMs = _parseMetric(metrics['processingDurationMs']);
    if (audioMs == null || processingMs == null) return;
    _benchmarkTracker.recordAudioTiming(
      messageId,
      audioDuration: Duration(microseconds: (audioMs * 1000).round()),
      processingDuration: Duration(microseconds: (processingMs * 1000).round()),
    );
    final Map<BenchmarkEvent, String> marks = <BenchmarkEvent, String>{
      BenchmarkEvent.t0SpeechStart: 'audioStartEpochMs',
      BenchmarkEvent.t1SpeechEnd: 'audioEndEpochMs',
      BenchmarkEvent.t2SttFinal: 'recognitionFinishedEpochMs',
    };
    for (final MapEntry<BenchmarkEvent, String> mark in marks.entries) {
      final double? at = _parseMetric(metrics[mark.value]);
      if (at != null) {
        _benchmarkTracker.mark(messageId, mark.key,
            at: DateTime.fromMillisecondsSinceEpoch(at.round()));
      }
    }
    _recordBenchmark(_benchmarkTracker.snapshotFor(messageId));
  }

  Duration _estimateAudioDuration(String text) {
    final int wordCount = text
        .split(RegExp(r'\s+'))
        .where((String token) => token.trim().isNotEmpty)
        .length;
    final int estimatedMs = (wordCount * 350).clamp(500, 15000).toInt();
    return Duration(milliseconds: estimatedMs);
  }

  String _newMessageId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  SpeechMessage? _lookupMessage(String messageId) {
    final SpeechMessage? cached = _messageById[messageId];
    if (cached != null) {
      return cached;
    }

    for (final SpeechMessage message in _history) {
      if (message.id == messageId) {
        _messageById[messageId] = message;
        return message;
      }
    }

    return null;
  }

  void _rememberMessage(SpeechMessage message) {
    _messageById[message.id] = message;
  }

  Future<void> _persistBenchmarkHistory() async {
    await _benchmarkHistoryStorageService.save(
      snapshots: _benchmarkHistory,
      messageLookup: _lookupMessage,
      appDataPathProvider: _nativeBridgeService.getAppDataDirectoryPath,
    );
  }

  void _restorePersistedBenchmarkHistory(PersistedBenchmarkHistory persisted) {
    _benchmarkHistory.clear();
    _messageById.clear();

    final List<BenchmarkSnapshot> limitedSnapshots =
        persisted.snapshots.take(_maxBenchmarkHistory).toList(growable: false);

    _benchmarkHistory.addAll(limitedSnapshots);
    _latestBenchmark =
        _benchmarkHistory.isEmpty ? null : _benchmarkHistory.first;

    for (final BenchmarkSnapshot snapshot in limitedSnapshots) {
      final SpeechMessage? message = persisted.messagesById[snapshot.messageId];
      if (message != null) {
        _messageById[snapshot.messageId] = message;
      }
    }
  }

  void _recordBenchmark(BenchmarkSnapshot snapshot) {
    _latestBenchmark = snapshot;

    final int existingIndex = _benchmarkHistory.indexWhere(
      (BenchmarkSnapshot item) => item.messageId == snapshot.messageId,
    );
    if (existingIndex >= 0) {
      _benchmarkHistory.removeAt(existingIndex);
    }

    _benchmarkHistory.insert(0, snapshot);
    if (_benchmarkHistory.length > _maxBenchmarkHistory) {
      final List<BenchmarkSnapshot> removed =
          _benchmarkHistory.sublist(_maxBenchmarkHistory);
      for (final BenchmarkSnapshot item in removed) {
        _messageById.remove(item.messageId);
        _benchmarkTracker.clear(item.messageId);
      }
      _benchmarkHistory.removeRange(
        _maxBenchmarkHistory,
        _benchmarkHistory.length,
      );
    }

    unawaited(_persistBenchmarkHistory());
  }

  ResourceBenchmark? _parseResourceBenchmark(Map<dynamic, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    return ResourceBenchmark(
      sttRamMb: _parseMetric(payload['sttRamMb']),
      ttsRamMb: _parseMetric(payload['ttsRamMb']),
      idleRamMb: _parseMetric(payload['idleRamMb']),
      peakRamMb: _parseMetric(payload['peakRamMb']),
      idleCpuPct: _parseMetric(payload['idleCpuPct']),
      sttCpuPct: _parseMetric(payload['sttCpuPct']),
      ttsCpuPct: _parseMetric(payload['ttsCpuPct']),
      sttModelSizeMb: _parseMetric(payload['sttModelSizeMb']),
      ttsModelSizeMb: _parseMetric(payload['ttsModelSizeMb']),
      apkSizeMb: _parseMetric(payload['apkSizeMb']),
    );
  }

  double? _parseMetric(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  @override
  void dispose() {
    final StreamSubscription<NativeEvent>? nativeEventsSub = _nativeEventsSub;
    if (nativeEventsSub != null) {
      unawaited(nativeEventsSub.cancel());
    }
    unawaited(_nativeBridgeService.stopLocationUpdates());
    unawaited(_nativeBridgeService.dispose());
    unawaited(_tcpMessageService.close());
    super.dispose();
  }
}
