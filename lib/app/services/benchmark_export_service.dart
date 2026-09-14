import 'dart:convert';

import '../models/benchmark_models.dart';
import '../models/speech_message.dart';

class BenchmarkExportService {
  const BenchmarkExportService();

  String toJson({
    required BenchmarkSnapshot snapshot,
    required ResourceBenchmark resource,
    SpeechMessage? message,
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      _jsonPayload(snapshot: snapshot, resource: resource, message: message),
    );
  }

  String historyToJson({
    required List<BenchmarkSnapshot> snapshots,
    required SpeechMessage? Function(String messageId) messageLookup,
    int? limit,
  }) {
    final List<BenchmarkSnapshot> selected = limit == null
        ? snapshots
        : snapshots.take(limit).toList(growable: false);

    final Map<String, dynamic> payload = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'sampleCount': selected.length,
      'samples': selected
          .map(
            (BenchmarkSnapshot snapshot) => _jsonPayload(
              snapshot: snapshot,
              resource: snapshot.resource,
              message: messageLookup(snapshot.messageId),
            ),
          )
          .toList(growable: false),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String toCsv({
    required BenchmarkSnapshot snapshot,
    required ResourceBenchmark resource,
    SpeechMessage? message,
  }) {
    final Map<String, String> row = _csvRow(
      snapshot: snapshot,
      resource: resource,
      message: message,
    );
    return _csvFromRows(<Map<String, String>>[row]);
  }

  String historyToCsv({
    required List<BenchmarkSnapshot> snapshots,
    required SpeechMessage? Function(String messageId) messageLookup,
    int? limit,
  }) {
    final List<BenchmarkSnapshot> selected = limit == null
        ? snapshots
        : snapshots.take(limit).toList(growable: false);
    final List<Map<String, String>> rows = selected
        .map(
          (BenchmarkSnapshot snapshot) => _csvRow(
            snapshot: snapshot,
            resource: snapshot.resource,
            message: messageLookup(snapshot.messageId),
          ),
        )
        .toList(growable: false);
    return _csvFromRows(rows);
  }

  Map<String, dynamic> _jsonPayload({
    required BenchmarkSnapshot snapshot,
    required ResourceBenchmark resource,
    SpeechMessage? message,
  }) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'messageId': snapshot.messageId,
      'sttEngine': snapshot.sttEngine,
      'timeline': <String, dynamic>{
        't0SpeechStart': _iso(snapshot.marks.t0SpeechStart),
        't1SpeechEnd': _iso(snapshot.marks.t1SpeechEnd),
        't2SttFinal': _iso(snapshot.marks.t2SttFinal),
        't3MessageSent': _iso(snapshot.marks.t3MessageSent),
        't4MessageReceived': _iso(snapshot.marks.t4MessageReceived),
        't5TtsStart': _iso(snapshot.marks.t5TtsStart),
        't6AudioFirstFrame': _iso(snapshot.marks.t6AudioFirstFrame),
      },
      'latencyMs': <String, int?>{
        'stt': snapshot.sttLatency?.inMilliseconds,
        'network': snapshot.networkLatency?.inMilliseconds,
        'tts': snapshot.ttsLatency?.inMilliseconds,
        'endToEnd': snapshot.endToEndLatency?.inMilliseconds,
      },
      'audioDurationMs': snapshot.audioDuration?.inMilliseconds,
      'processingDurationMs': snapshot.processingDuration?.inMilliseconds,
      'rtf': _roundDouble(snapshot.rtf),
      'resources': <String, double?>{
        'idleRamMb': _roundDouble(resource.idleRamMb),
        'sttRamMb': _roundDouble(resource.sttRamMb),
        'ttsRamMb': _roundDouble(resource.ttsRamMb),
        'peakRamMb': _roundDouble(resource.peakRamMb),
        'idleCpuPct': _roundDouble(resource.idleCpuPct),
        'sttCpuPct': _roundDouble(resource.sttCpuPct),
        'ttsCpuPct': _roundDouble(resource.ttsCpuPct),
        'sttModelSizeMb': _roundDouble(resource.sttModelSizeMb),
        'ttsModelSizeMb': _roundDouble(resource.ttsModelSizeMb),
        'apkSizeMb': _roundDouble(resource.apkSizeMb),
      },
    };

    if (message != null) {
      payload['message'] = <String, dynamic>{
        'type': messageTypeToWire(message.type),
        'origin': _messageOriginToWire(message.origin),
        'language': message.languageCode,
        'text': message.message,
        'timestamp': message.timestamp.toIso8601String(),
      };
    }

    return payload;
  }

  Map<String, String> _csvRow({
    required BenchmarkSnapshot snapshot,
    required ResourceBenchmark resource,
    SpeechMessage? message,
  }) {
    return <String, String>{
      'exported_at': DateTime.now().toIso8601String(),
      'message_id': snapshot.messageId,
      'stt_engine': snapshot.sttEngine,
      'message_type': message == null ? '' : messageTypeToWire(message.type),
      'message_origin':
          message == null ? '' : _messageOriginToWire(message.origin),
      'language': message?.languageCode ?? '',
      'message_text': message?.message ?? '',
      'message_timestamp': message?.timestamp.toIso8601String() ?? '',
      't0_speech_start': _iso(snapshot.marks.t0SpeechStart) ?? '',
      't1_speech_end': _iso(snapshot.marks.t1SpeechEnd) ?? '',
      't2_stt_final': _iso(snapshot.marks.t2SttFinal) ?? '',
      't3_message_sent': _iso(snapshot.marks.t3MessageSent) ?? '',
      't4_message_received': _iso(snapshot.marks.t4MessageReceived) ?? '',
      't5_tts_start': _iso(snapshot.marks.t5TtsStart) ?? '',
      't6_audio_first_frame': _iso(snapshot.marks.t6AudioFirstFrame) ?? '',
      'stt_latency_ms': _durationMs(snapshot.sttLatency),
      'network_latency_ms': _durationMs(snapshot.networkLatency),
      'tts_latency_ms': _durationMs(snapshot.ttsLatency),
      'end_to_end_latency_ms': _durationMs(snapshot.endToEndLatency),
      'audio_duration_ms': _durationMs(snapshot.audioDuration),
      'processing_duration_ms': _durationMs(snapshot.processingDuration),
      'rtf': _decimal(snapshot.rtf),
      'idle_ram_mb': _decimal(resource.idleRamMb),
      'stt_ram_mb': _decimal(resource.sttRamMb),
      'tts_ram_mb': _decimal(resource.ttsRamMb),
      'peak_ram_mb': _decimal(resource.peakRamMb),
      'idle_cpu_pct': _decimal(resource.idleCpuPct),
      'stt_cpu_pct': _decimal(resource.sttCpuPct),
      'tts_cpu_pct': _decimal(resource.ttsCpuPct),
      'stt_model_size_mb': _decimal(resource.sttModelSizeMb),
      'tts_model_size_mb': _decimal(resource.ttsModelSizeMb),
      'apk_size_mb': _decimal(resource.apkSizeMb),
    };
  }

  String _csvFromRows(List<Map<String, String>> rows) {
    if (rows.isEmpty) {
      return '';
    }

    final List<String> headers = rows.first.keys.toList(growable: false);
    final String headerLine = headers.map(_csvCell).join(',');
    final List<String> valueLines = rows
        .map(
          (Map<String, String> row) =>
              headers.map((String key) => _csvCell(row[key] ?? '')).join(','),
        )
        .toList(growable: false);
    return <String>[headerLine, ...valueLines].join('\n');
  }

  String _durationMs(Duration? value) {
    return value == null ? '' : value.inMilliseconds.toString();
  }

  String _decimal(double? value) {
    return value == null ? '' : value.toStringAsFixed(2);
  }

  double? _roundDouble(double? value) {
    if (value == null) {
      return null;
    }
    return double.parse(value.toStringAsFixed(2));
  }

  String? _iso(DateTime? value) {
    return value?.toIso8601String();
  }

  String _csvCell(String value) {
    final String escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _messageOriginToWire(MessageOrigin origin) {
    switch (origin) {
      case MessageOrigin.local:
        return 'local';
      case MessageOrigin.remote:
        return 'remote';
      case MessageOrigin.system:
        return 'system';
    }
  }
}
