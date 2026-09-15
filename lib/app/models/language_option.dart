class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.label,
    required this.sttSupported,
    required this.ttsSupported,
    this.notes,
  });

  final String code;
  final String label;
  final bool sttSupported;
  final bool ttsSupported;
  final String? notes;

  String get status {
    if (sttSupported && ttsSupported) {
      return 'Ready';
    }
    return notes ?? 'Pending';
  }
}

const List<LanguageOption> kLanguageOptions = <LanguageOption>[
  LanguageOption(
    code: 'en',
    label: 'English',
    sttSupported: true,
    ttsSupported: true,
  ),
  LanguageOption(
    code: 'hi',
    label: 'Hindi',
    sttSupported: true,
    ttsSupported: true,
  ),
  LanguageOption(
    code: 'gu',
    label: 'Gujarati',
    sttSupported: true,
    ttsSupported: false,
    notes: 'TTS model pending evaluation',
  ),
  LanguageOption(
    code: 'mr',
    label: 'Marathi',
    sttSupported: true,
    ttsSupported: false,
    notes: 'TTS model pending evaluation',
  ),
  LanguageOption(
    code: 'kn',
    label: 'Kannada',
    sttSupported: true,
    ttsSupported: false,
    notes: 'TTS model pending evaluation',
  ),
  LanguageOption(
    code: 'ml',
    label: 'Malayalam',
    sttSupported: true,
    ttsSupported: false,
    notes: 'TTS model pending evaluation',
  ),
  LanguageOption(
    code: 'ta',
    label: 'Tamil',
    sttSupported: true,
    ttsSupported: false,
    notes: 'TTS model pending evaluation',
  ),
  LanguageOption(
    code: 'te',
    label: 'Telugu',
    sttSupported: true,
    ttsSupported: false,
    notes: 'TTS model pending evaluation',
  ),
  LanguageOption(
    code: 'bn',
    label: 'Bengali',
    sttSupported: true,
    ttsSupported: false,
    notes: 'TTS model pending evaluation',
  ),
  LanguageOption(
    code: 'or',
    label: 'Odia',
    sttSupported: false,
    ttsSupported: false,
    notes: 'Odia STT/TTS model integration pending',
  ),
];
