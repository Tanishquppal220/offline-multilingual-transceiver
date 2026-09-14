import 'package:flutter/material.dart';

import '../../models/operation_mode.dart';

import '../../state/app_controller.dart';

import '../../theme/app_theme.dart';

import '../widgets/pulsing_dot.dart';

class TalkScreen extends StatefulWidget {
  const TalkScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  final TextEditingController _quickTextController =
      TextEditingController();

  @override
  void dispose() {
    _quickTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;
    final bool connected = controller.isConnected;
    final bool isHandsFree =
        controller.operationMode == OperationMode.continuous;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 76, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Mission Status Banner
            _buildStatusBanner(connected),
            const SizedBox(height: 12),

            // 2. Language Picker & Active Unit Strip
            _buildQuickInfoStrip(controller),
            const SizedBox(height: 12),

            // 3. Audio Waveform Live Visualizer
            _buildWaveformBar(controller),
            const SizedBox(height: 16),

            // 4. Mode Switcher (Hold to Talk vs Hands-Free)
            _buildModeSwitcher(isHandsFree, controller),
            const SizedBox(height: 20),

            // 5. Giant Push-to-Talk Station
            _buildPttStation(controller, isHandsFree),
            const SizedBox(height: 20),

            // 6. Live Transcript Card
            _buildLiveTranscriptCard(controller),
            const SizedBox(height: 12),

            // 7. Quick Message Input Field
            _buildQuickInput(controller),
            const SizedBox(height: 12),

            // 8. Big Red Emergency SOS Safety Trigger
            _buildSosTrigger(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(bool connected) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: connected ? 'Connected to Team' : 'Offline. Standalone Mode',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: connected
              ? AppColors.tertiaryFixed
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: connected
                    ? AppColors.onTertiaryFixed
                    : AppColors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                connected ? Icons.check_circle : Icons.sensors_off,
                color: connected
                    ? AppColors.tertiaryFixed
                    : AppColors.outlineVariant,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (connected) ...<Widget>[
                        const PulsingDot(
                          color: AppColors.onTertiaryFixed,
                          size: 8,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        connected ? 'CONNECTED TO TEAM' : 'OFFLINE MODE',
                        style: AppTypography.headlineSm.copyWith(
                          color: connected
                              ? AppColors.onTertiaryFixed
                              : AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connected
                        ? 'You can talk and receive messages.'
                        : 'Tap Settings to connect or run offline radio.',
                    style: AppTypography.bodySm.copyWith(
                      color: connected
                          ? AppColors.onTertiaryFixed.withValues(alpha: 0.8)
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInfoStrip(AppController controller) {
    return Row(
      children: <Widget>[
        // Language card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.translate,
                  color: AppColors.secondary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'SPEAKING IN',
                        style: AppTypography.labelCaps,
                      ),
                      Text(
                        controller.selectedLanguage.label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Active unit card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups,
                    size: 18,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'ACTIVE UNIT',
                        style: AppTypography.labelCaps,
                      ),
                      Text(
                        controller.isConnected
                            ? 'Mesh Connected'
                            : 'Solo Local',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformBar(AppController controller) {
    final bool isListening = controller.isListening;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.graphic_eq,
                color: AppColors.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'CHANNEL 01 : RELIEF MESH',
                style: AppTypography.labelCaps.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            children: List<Widget>.generate(5, (int i) {
              final double height =
                  isListening ? (8.0 + (i * 3.5)) : 6.0;

              return Container(
                width: 4,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isListening
                      ? AppColors.secondary
                      : AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher(
    bool isHandsFree,
    AppController controller,
  ) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ModePill(
              label: 'HOLD TO TALK',
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
    );
  }

  Widget _buildPttStation(
    AppController controller,
    bool isHandsFree,
  ) {
    final bool active = controller.isListening;

    return Column(
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Push to talk button',
          hint: isHandsFree
              ? 'Tap once to begin speech broadcast'
              : 'Press and hold to broadcast voice, release when finished',
          value: active ? 'Transmitting audio live' : 'Ready',
          child: GestureDetector(
            // Hands-free mode keeps tap-to-toggle behavior.
            onTap: isHandsFree
                ? () {
                    if (active) {
                      controller.stopPushToTalk();
                    } else {
                      controller.startPushToTalk();
                    }
                  }
                : null,

            // Walkie-talkie mode starts immediately on finger-down.
            onTapDown:
                isHandsFree ? null : (_) => controller.startPushToTalk(),

            // Walkie-talkie mode finalizes on finger-up.
            onTapUp:
                isHandsFree ? null : (_) => controller.stopPushToTalk(),

            // Also finalize safely if Flutter cancels the gesture.
            onTapCancel:
                isHandsFree ? null : () => controller.stopPushToTalk(),

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 220,
              height: 220,
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
                        .withValues(
                          alpha: active ? 0.6 : 0.25,
                        ),
                    blurRadius: active ? 36 : 16,
                    spreadRadius: active ? 6 : 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: (active
                              ? AppColors.onPrimary
                              : AppColors.onTertiaryFixed)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      active
                          ? Icons.radio_button_checked
                          : Icons.mic,
                      size: 44,
                      color: active
                          ? AppColors.onPrimary
                          : AppColors.onTertiaryFixed,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    active
                        ? 'TRANSMITTING'
                        : (isHandsFree
                            ? 'TAP TO SPEAK'
                            : 'HOLD TO TALK'),
                    style: AppTypography.headlineLg.copyWith(
                      color: active
                          ? AppColors.onPrimary
                          : AppColors.onTertiaryFixed,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active
                        ? (isHandsFree
                            ? 'Tap circle to stop'
                            : 'Release when done')
                        : (isHandsFree
                            ? 'Tap once to begin'
                            : 'Release when finished'),
                    style: AppTypography.labelCaps.copyWith(
                      color: (active
                              ? AppColors.onPrimary
                              : AppColors.onTertiaryFixed)
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isHandsFree
              ? 'Hands-Free: Tap circle once to start, tap again to finalize'
              : 'Press and hold anywhere on the circle to transmit voice',
          textAlign: TextAlign.center,
          style: AppTypography.bodySm,
        ),
      ],
    );
  }

  Widget _buildLiveTranscriptCard(AppController controller) {
    final String transcript =
        controller.partialTranscript.trim();

    final String displayText = transcript.isNotEmpty
        ? '“$transcript”'
        : (controller.history.isNotEmpty
            ? '“${controller.history.first.message}”'
            : '“Team standby. Route clear for voice mesh.”');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
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
                  const Icon(
                    Icons.record_voice_over,
                    color: AppColors.secondary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'WHAT WAS HEARD',
                    style: AppTypography.labelCaps,
                  ),
                ],
              ),
              Text(
                transcript.isNotEmpty
                    ? 'Transcribing...'
                    : 'Latest',
                style: AppTypography.telemetrySm,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              displayText,
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInput(AppController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.keyboard,
            color: AppColors.outlineVariant,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _quickTextController,
              decoration: const InputDecoration(
                hintText: 'Type text if too noisy to speak...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (String val) {
                if (val.trim().isNotEmpty) {
                  controller.sendTypedMessage(val.trim());
                  _quickTextController.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.send,
              color: AppColors.primary,
            ),
            onPressed: () {
              final String val =
                  _quickTextController.text.trim();

              if (val.isNotEmpty) {
                controller.sendTypedMessage(val);
                _quickTextController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSosTrigger(AppController controller) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'EMERGENCY SOS',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Broadcasts urgent priority medical alert',
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () =>
                  controller.sendEmergencyPreset(),
              icon: const Icon(
                Icons.emergency_share,
                size: 20,
              ),
              label: Text(
                'TAP TO BROADCAST EMERGENCY',
                style: AppTypography.labelCaps.copyWith(
                  color: Colors.white,
                ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.surfaceContainerHighest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: AppTypography.labelCaps.copyWith(
            color: active
                ? AppColors.onSurface
                : AppColors.onSurfaceVariant,
            fontWeight:
                active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
