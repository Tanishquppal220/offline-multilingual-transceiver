import 'package:flutter/material.dart';

import '../../models/operation_mode.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/language_picker_sheet.dart';

class TalkScreen extends StatelessWidget {
  const TalkScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final bool isHandsFree =
        controller.operationMode == OperationMode.continuous;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 74, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Tactical Quick Controls Bar (Interactive Language Chip & Mode Switcher)
            _buildControlBar(context, isHandsFree),
            const SizedBox(height: 18),

            // 2. Central Push-to-Talk Station
            _buildPttStation(isHandsFree),
            const SizedBox(height: 18),

            // 3. Unified Transmission Monitor (Waveform + Live Transcript)
            _buildTransmissionMonitor(),
            const SizedBox(height: 16),

            // 4. Compact Emergency SOS Broadcast Trigger
            _buildEmergencySosBar(),
          ],
        ),
      ),
    );
  }

  /// Compact top bar combining 1-tap language selector and walkie-talkie mode switch
  Widget _buildControlBar(BuildContext context, bool isHandsFree) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // Interactive Language Picker Chip
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => LanguagePickerSheet.show(context, controller),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.translate,
                      color: AppColors.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.selectedLanguage.label,
                      style: AppTypography.labelCaps.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.onSurfaceVariant,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Walkie-Talkie Mode Switcher
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ModePill(
                label: 'PTT',
                active: !isHandsFree,
                onTap: () => controller.setOperationMode(
                  OperationMode.walkieTalkie,
                ),
              ),
              _ModePill(
                label: 'HANDS-FREE',
                active: isHandsFree,
                onTap: () => controller.setOperationMode(
                  OperationMode.continuous,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Ergonomic, focused Push-to-Talk circular station
  Widget _buildPttStation(bool isHandsFree) {
    final bool active = controller.isListening;

    return Center(
      child: Column(
        children: <Widget>[
          Semantics(
            button: true,
            label: 'Push to talk button',
            hint: isHandsFree
                ? 'Tap once to begin speech broadcast'
                : 'Press and hold to broadcast voice, release when finished',
            value: active ? 'Transmitting audio live' : 'Ready',
            child: GestureDetector(
              onTap: isHandsFree
                  ? () {
                      if (active) {
                        controller.stopPushToTalk();
                      } else {
                        controller.startPushToTalk();
                      }
                    }
                  : null,
              onTapDown:
                  isHandsFree ? null : (_) => controller.startPushToTalk(),
              onTapUp:
                  isHandsFree ? null : (_) => controller.stopPushToTalk(),
              onTapCancel:
                  isHandsFree ? null : () => controller.stopPushToTalk(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.primary
                      : AppColors.tertiaryFixed,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (active
                              ? AppColors.primary
                              : AppColors.tertiary)
                          .withValues(alpha: active ? 0.65 : 0.28),
                      blurRadius: active ? 36 : 18,
                      spreadRadius: active ? 6 : 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: (active
                                ? AppColors.onPrimary
                                : AppColors.onTertiaryFixed)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        active ? Icons.radio_button_checked : Icons.mic,
                        size: 40,
                        color: active
                            ? AppColors.onPrimary
                            : AppColors.onTertiaryFixed,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      active
                          ? 'TRANSMITTING'
                          : (isHandsFree ? 'TAP TO SPEAK' : 'HOLD TO TALK'),
                      style: AppTypography.headlineLg.copyWith(
                        color: active
                            ? AppColors.onPrimary
                            : AppColors.onTertiaryFixed,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active
                          ? (isHandsFree ? 'Tap to stop' : 'Release when done')
                          : (isHandsFree ? 'Tap once to begin' : 'Release to send'),
                      style: AppTypography.labelCaps.copyWith(
                        color: (active
                                ? AppColors.onPrimary
                                : AppColors.onTertiaryFixed)
                            .withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isHandsFree
                ? 'Hands-Free: Tap once to start, tap again to finalize'
                : 'Hold anywhere on circle to speak • Release to send',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Unified card showing real-time audio waveform and live STT transcription
  Widget _buildTransmissionMonitor() {
    final bool isListening = controller.isListening;
    final String transcript = controller.partialTranscript.trim();

    final String displayText = transcript.isNotEmpty
        ? '“$transcript”'
        : (controller.history.isNotEmpty
            ? '“${controller.history.first.message}”'
            : '“Team standby. Ready for voice mesh transmission.”');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    isListening ? Icons.graphic_eq : Icons.record_voice_over,
                    color: isListening ? AppColors.primary : AppColors.secondary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isListening ? 'LIVE AUDIO' : 'WHAT WAS HEARD',
                    style: AppTypography.labelCaps.copyWith(
                      color: isListening ? AppColors.primary : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              // Live waveform equalizer bars
              Row(
                children: List<Widget>.generate(6, (int i) {
                  final double height = isListening ? (6.0 + ((i % 3 + 1) * 4.5)) : 5.0;

                  return Container(
                    width: 3.5,
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: isListening
                          ? AppColors.primary
                          : AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isListening
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              displayText,
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.onSurface,
                height: 1.35,
                fontSize: 15,
                fontWeight: transcript.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact, high-contrast emergency broadcast button
  Widget _buildEmergencySosBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'EMERGENCY SOS',
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Broadcast urgent distress beacon',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => controller.sendEmergencyPreset(),
            child: Text(
              'BROADCAST',
              style: AppTypography.labelCaps.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? AppColors.surfaceContainerHighest : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: AppTypography.labelCaps.copyWith(
                color: active ? AppColors.onSurface : AppColors.onSurfaceVariant,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
