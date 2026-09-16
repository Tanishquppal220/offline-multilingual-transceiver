import 'package:flutter/material.dart';

import '../../models/speech_message.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _msgInputController = TextEditingController();

  @override
  void dispose() {
    _msgInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;
    final List<SpeechMessage> messages = controller.history;

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          // Scrollable messages stream
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 76, 16, 12),
              children: <Widget>[
                // Header Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'RECENT DISPATCHES',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headlineSm,
                          ),
                          Text(
                            messages.isEmpty
                                ? 'Offline radio storage clear'
                                : '${messages.length} message${messages.length == 1 ? '' : 's'} recorded',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (messages.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.onSurfaceVariant,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          minimumSize: const Size(40, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: controller.clearHistory,
                        icon: const Icon(Icons.delete_sweep, size: 16),
                        label: Text('Clear', style: AppTypography.bodySm.copyWith(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Message bubbles stream
                if (messages.isEmpty)
                  _buildEmptyState()
                else
                  for (final SpeechMessage msg in messages) ...<Widget>[
                    _buildMessageCard(msg, controller),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),

          // Sticky Bottom Compose Bar
          _buildStickyCompose(controller),
        ],
      ),
    );
  }


  Widget _buildMessageCard(SpeechMessage msg, AppController controller) {
    final bool isEmergency = msg.type == MessageType.emergency;
    final bool isLocal = msg.origin == MessageOrigin.local;

    if (isEmergency) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: const Icon(Icons.warning, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        msg.senderCallsign != null
                            ? '${msg.senderCallsign!.toUpperCase()} • ${msg.senderRole?.toUpperCase() ?? "EMERGENCY"}'
                            : 'CRITICAL EMERGENCY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Broadcast • ${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.telemetrySm,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'URGENT',
                    style: AppTypography.labelCaps.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                msg.message,
                style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            if (msg.location != null) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.location_on, size: 14, color: AppColors.error),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'LOCATION: ${msg.location!.formattedCoordinates}',
                            style: AppTypography.telemetrySm.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          if (msg.location!.accuracyLabel.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              'ACCURACY: ${msg.location!.accuracyLabel}',
                              style: AppTypography.telemetrySm.copyWith(
                                color: AppColors.error.withValues(alpha: 0.85),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (!isLocal) {
      // Incoming transmission
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
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            msg.languageCode.toUpperCase(),
                            style: AppTypography.labelCaps.copyWith(
                              color: AppColors.onSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              msg.senderCallsign ?? 'Remote Unit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.headlineSm,
                            ),
                            Text(
                              '${msg.senderRole != null ? "${msg.senderRole} • " : ""}${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.telemetrySm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'VOICE NOTE',
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.onSecondaryContainer,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '“${msg.message}”',
              style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
            ),
            if (msg.location != null) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.location_on, size: 13, color: AppColors.tertiary),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${msg.location!.formattedCoordinates}${msg.location!.accuracyLabel.isNotEmpty ? " • ${msg.location!.accuracyLabel}" : ""}',
                      style: AppTypography.telemetrySm.copyWith(
                        color: AppColors.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Outgoing transmission
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Text(
                    'YOU (${controller.userProfile.callsign.toUpperCase()})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelCaps.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: AppTypography.telemetrySm,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              msg.message,
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (msg.location != null)
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.location_on, size: 12, color: AppColors.outlineVariant),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            msg.location!.compactCoordinates,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.telemetrySm.copyWith(color: AppColors.outlineVariant),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.done_all, size: 14, color: AppColors.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      'Delivered to mesh',
                      style: AppTypography.telemetrySm.copyWith(color: AppColors.tertiary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: <Widget>[
            const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.outlineVariant),
            const SizedBox(height: 8),
            Text('No messages yet', style: AppTypography.headlineSm),
            const SizedBox(height: 4),
            Text('Mesh transmissions will log here offline', style: AppTypography.bodySm),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyCompose(AppController controller) {
    const List<String> presets = <String>[
      '👍 I am OK',
      '🆘 Need Help',
      '📍 Arrived at Location',
      '📡 Check In',
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Horizontal Presets Action Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: presets.map((String text) {
                final bool isSos = text.contains('Need Help');
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: isSos
                        ? AppColors.errorContainer.withValues(alpha: 0.45)
                        : AppColors.surfaceContainerLow,
                    side: BorderSide(
                      color: isSos
                          ? AppColors.error
                          : AppColors.outline.withValues(alpha: 0.7),
                      width: isSos ? 1.2 : 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    label: Text(
                      text,
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 12,
                        fontWeight: isSos ? FontWeight.w700 : FontWeight.w500,
                        color: isSos ? AppColors.error : AppColors.onSurface,
                      ),
                    ),
                    onPressed: () {
                      if (isSos) {
                        controller.sendEmergencyPreset();
                      } else {
                        controller.sendTypedMessage(text);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Message Input Field
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              2,
              16,
              MediaQuery.paddingOf(context).bottom + 10,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: TextField(
                      controller: _msgInputController,
                      decoration: const InputDecoration(
                        hintText: 'Type a dispatch message...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (String val) {
                        if (val.trim().isNotEmpty) {
                          controller.sendTypedMessage(val.trim());
                          _msgInputController.clear();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final String val = _msgInputController.text.trim();
                      if (val.isNotEmpty) {
                        controller.sendTypedMessage(val);
                        _msgInputController.clear();
                      }
                    },
                    child: const Icon(Icons.arrow_upward, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
