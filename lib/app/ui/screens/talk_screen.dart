import 'package:flutter/material.dart';

import '../../models/connection_config.dart';
import '../../models/operation_mode.dart';
import '../../models/speech_message.dart';
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
  late final TextEditingController _hostController;

  @override
  void initState() {
    super.initState();
    final String host = widget.controller.connectionConfig.host;
    _hostController = TextEditingController(
      text: host.isEmpty ? '192.168.4.1' : host,
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;
    final ConnectionConfig config = controller.connectionConfig;
    final bool isHandsFree =
        controller.operationMode == OperationMode.continuous;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 74, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Team Mesh Network Card
            _buildTeamMeshCard(controller, config),
            const SizedBox(height: 12),

            // 2. Walkie-Talkie Operation Mode Switcher
            _buildModeSwitcher(controller, isHandsFree),
            const SizedBox(height: 16),

            // 3. Central Push-to-Talk Station
            _buildPttStation(controller, isHandsFree),
            const SizedBox(height: 16),

            // 4. Unified Transmission Monitor (Waveform + Live Transcript)
            _buildTransmissionMonitor(controller),
            const SizedBox(height: 16),

            // 5. Compact Emergency SOS Broadcast Trigger
            _buildEmergencySosBar(controller),
          ],
        ),
      ),
    );
  }

  /// Tactical Team Mesh control card directly on the operational talk screen
  Widget _buildTeamMeshCard(AppController controller, ConnectionConfig config) {
    final bool connected = controller.isConnected;

    if (connected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: <Widget>[
            const PulsingDot(color: AppColors.tertiary, size: 8, ping: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    config.runAsServer ? 'HOST MESH ACTIVE' : 'SQUAD LINKED',
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.tertiary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    config.runAsServer
                        ? 'Broadcasting on Port 7070'
                        : 'Connected to ${config.host}',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => controller.disconnect(),
                  child: Text(
                    'DISCONNECT',
                    style: AppTypography.labelCaps.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.wifi_tethering, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'TEAM MESH NETWORK',
                style: AppTypography.labelCaps.copyWith(fontSize: 11),
              ),
              const Spacer(),
              Text(
                'OFFLINE DIRECT',
                style: AppTypography.telemetrySm.copyWith(
                  fontSize: 10,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Segmented Role Toggle
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => controller.updateConnectionConfig(
                        config.copyWith(runAsServer: true),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: config.runAsServer
                                ? AppColors.tertiaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.hub,
                                size: 14,
                                color: config.runAsServer
                                    ? AppColors.onTertiaryContainer
                                    : AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'HOST MESH',
                                style: AppTypography.labelCaps.copyWith(
                                  color: config.runAsServer
                                      ? AppColors.onTertiaryContainer
                                      : AppColors.onSurfaceVariant,
                                  fontWeight: config.runAsServer
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => controller.updateConnectionConfig(
                        config.copyWith(runAsServer: false),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !config.runAsServer
                                ? AppColors.secondaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.link,
                                size: 14,
                                color: !config.runAsServer
                                    ? AppColors.onSecondaryContainer
                                    : AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'JOIN SQUAD',
                                style: AppTypography.labelCaps.copyWith(
                                  color: !config.runAsServer
                                      ? AppColors.onSecondaryContainer
                                      : AppColors.onSurfaceVariant,
                                  fontWeight: !config.runAsServer
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!config.runAsServer) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: TextField(
                controller: _hostController,
                style: AppTypography.telemetryMd.copyWith(fontSize: 13),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: 'Leader IP: 192.168.4.1',
                  prefixIcon: Icon(Icons.router, size: 16, color: AppColors.outlineVariant),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Connect Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: config.runAsServer
                    ? AppColors.tertiary
                    : AppColors.secondary,
                foregroundColor: config.runAsServer
                    ? AppColors.onTertiary
                    : AppColors.onSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                controller.updateConnectionConfig(
                  config.copyWith(
                    host: _hostController.text.trim().isEmpty
                        ? '192.168.4.1'
                        : _hostController.text.trim(),
                    port: ConnectionConfig.networkPort,
                  ),
                );
                await controller.connect();
              },
              icon: Icon(
                config.runAsServer ? Icons.sensors : Icons.link,
                size: 16,
                color: config.runAsServer
                    ? AppColors.onTertiary
                    : AppColors.onSecondary,
              ),
              label: Text(
                config.runAsServer ? 'START LEADER MESH' : 'CONNECT TO LEADER',
                style: AppTypography.labelCaps.copyWith(
                  color: config.runAsServer
                      ? AppColors.onTertiary
                      : AppColors.onSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ergonomic mode switcher between Push-to-Talk and continuous Hands-Free
  Widget _buildModeSwitcher(AppController controller, bool isHandsFree) {
    return Center(
      child: Container(
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
    );
  }

  /// Ergonomic, focused Push-to-Talk circular station
  Widget _buildPttStation(AppController controller, bool isHandsFree) {
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
  Widget _buildTransmissionMonitor(AppController controller) {
    final bool isListening = controller.isListening;
    final String transcript = controller.partialTranscript.trim();
    final SpeechMessage? lastMsg =
        controller.history.isNotEmpty ? controller.history.first : null;

    final String titleText = isListening
        ? 'LIVE TRANSMISSION • ${controller.userProfile.callsign.toUpperCase()}'
        : (lastMsg != null
            ? 'FROM: ${lastMsg.senderCallsign?.toUpperCase() ?? "REMOTE UNIT"} [${lastMsg.senderRole?.toUpperCase() ?? "RADIO"}]'
            : 'WHAT WAS HEARD');

    final String displayText = transcript.isNotEmpty
        ? '“$transcript”'
        : (lastMsg != null
            ? '“${lastMsg.message}”'
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
              Expanded(
                child: Row(
                  children: <Widget>[
                    Icon(
                      isListening ? Icons.graphic_eq : Icons.record_voice_over,
                      color: isListening ? AppColors.primary : AppColors.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        titleText,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelCaps.copyWith(
                          color: isListening ? AppColors.primary : AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayText,
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.onSurface,
                    height: 1.35,
                    fontSize: 15,
                    fontWeight: transcript.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (!isListening && lastMsg?.location != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.location_on, size: 13, color: AppColors.tertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'GPS: ${lastMsg!.location!.formattedCoordinates}${lastMsg.location!.accuracyLabel.isNotEmpty ? " • ${lastMsg.location!.accuracyLabel}" : ""}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.telemetrySm.copyWith(
                            color: AppColors.tertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isListening && controller.currentLocation != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.location_on, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'ATTACHED GPS: ${controller.currentLocation!.compactCoordinates}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.telemetrySm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact, high-contrast emergency broadcast button
  Widget _buildEmergencySosBar(AppController controller) {
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
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              child: ElevatedButton(
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
