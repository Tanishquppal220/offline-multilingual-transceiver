enum BenchmarkEvent {
  t0SpeechStart,
  t1SpeechEnd,
  t2SttFinal,
  t3MessageSent,
  t4MessageReceived,
  t5TtsStart,
  t6AudioFirstFrame,
}

class BenchmarkMarks {
  DateTime? t0SpeechStart;
  DateTime? t1SpeechEnd;
  DateTime? t2SttFinal;
  DateTime? t3MessageSent;
  DateTime? t4MessageReceived;
  DateTime? t5TtsStart;
  DateTime? t6AudioFirstFrame;

  void set(BenchmarkEvent event, DateTime at) {
    switch (event) {
      case BenchmarkEvent.t0SpeechStart:
        t0SpeechStart = at;
      case BenchmarkEvent.t1SpeechEnd:
        t1SpeechEnd = at;
      case BenchmarkEvent.t2SttFinal:
        t2SttFinal = at;
      case BenchmarkEvent.t3MessageSent:
        t3MessageSent = at;
      case BenchmarkEvent.t4MessageReceived:
        t4MessageReceived = at;
      case BenchmarkEvent.t5TtsStart:
        t5TtsStart = at;
      case BenchmarkEvent.t6AudioFirstFrame:
        t6AudioFirstFrame = at;
    }
  }

  BenchmarkMarks clone() {
    return BenchmarkMarks()
      ..t0SpeechStart = t0SpeechStart
      ..t1SpeechEnd = t1SpeechEnd
      ..t2SttFinal = t2SttFinal
      ..t3MessageSent = t3MessageSent
      ..t4MessageReceived = t4MessageReceived
      ..t5TtsStart = t5TtsStart
      ..t6AudioFirstFrame = t6AudioFirstFrame;
  }
}

class ResourceBenchmark {
  const ResourceBenchmark({
    this.sttRamMb,
    this.ttsRamMb,
    this.idleRamMb,
    this.peakRamMb,
    this.idleCpuPct,
    this.sttCpuPct,
    this.ttsCpuPct,
    this.sttModelSizeMb,
    this.ttsModelSizeMb,
    this.apkSizeMb,
  });

  final double? sttRamMb;
  final double? ttsRamMb;
  final double? idleRamMb;
  final double? peakRamMb;
  final double? idleCpuPct;
  final double? sttCpuPct;
  final double? ttsCpuPct;
  final double? sttModelSizeMb;
  final double? ttsModelSizeMb;
  final double? apkSizeMb;

  ResourceBenchmark copyWith({
    double? sttRamMb,
    double? ttsRamMb,
    double? idleRamMb,
    double? peakRamMb,
    double? idleCpuPct,
    double? sttCpuPct,
    double? ttsCpuPct,
    double? sttModelSizeMb,
    double? ttsModelSizeMb,
    double? apkSizeMb,
  }) {
    return ResourceBenchmark(
      sttRamMb: sttRamMb ?? this.sttRamMb,
      ttsRamMb: ttsRamMb ?? this.ttsRamMb,
      idleRamMb: idleRamMb ?? this.idleRamMb,
      peakRamMb: peakRamMb ?? this.peakRamMb,
      idleCpuPct: idleCpuPct ?? this.idleCpuPct,
      sttCpuPct: sttCpuPct ?? this.sttCpuPct,
      ttsCpuPct: ttsCpuPct ?? this.ttsCpuPct,
      sttModelSizeMb: sttModelSizeMb ?? this.sttModelSizeMb,
      ttsModelSizeMb: ttsModelSizeMb ?? this.ttsModelSizeMb,
      apkSizeMb: apkSizeMb ?? this.apkSizeMb,
    );
  }
}

class BenchmarkSnapshot {
  const BenchmarkSnapshot({
    required this.messageId,
    required this.marks,
    required this.resource,
    this.sttEngine = 'conformer',
    this.audioDuration,
    this.processingDuration,
  });

  final String messageId;
  final BenchmarkMarks marks;
  final ResourceBenchmark resource;
  final String sttEngine;
  final Duration? audioDuration;
  final Duration? processingDuration;

  Duration? get sttLatency => _between(marks.t1SpeechEnd, marks.t2SttFinal);
  Duration? get networkLatency =>
      _between(marks.t3MessageSent, marks.t4MessageReceived);
  Duration? get ttsLatency =>
      _between(marks.t4MessageReceived, marks.t6AudioFirstFrame);
  Duration? get endToEndLatency =>
      _between(marks.t0SpeechStart, marks.t6AudioFirstFrame);

  double? get rtf {
    if (audioDuration == null || processingDuration == null) {
      return null;
    }
    final int audioMs = audioDuration!.inMilliseconds;
    if (audioMs <= 0) {
      return null;
    }
    return processingDuration!.inMilliseconds / audioMs;
  }

  Duration? _between(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return null;
    }
    if (end.isBefore(start)) {
      return null;
    }
    return end.difference(start);
  }
}
