import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/benchmark_models.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';

import 'operator_profile_sheet.dart';
import 'pulsing_dot.dart';

/// Modal bottom sheet for secondary radio controls and technician benchmarks.
class RadioSettingsSheet extends StatefulWidget {
  const RadioSettingsSheet({super.key, required this.controller});

  final AppController controller;

  static Future<void> show(BuildContext context, AppController controller) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => RadioSettingsSheet(controller: controller),
    );
  }

  @override
  State<RadioSettingsSheet> createState() => _RadioSettingsSheetState();
}

class _RadioSettingsSheetState extends State<RadioSettingsSheet> {
  double _volume = 85;
  bool _sirenEnabled = true;

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;
    final BenchmarkSnapshot? snap = controller.latestBenchmark;
    final ResourceBenchmark res = controller.resourceBenchmark;

    String ms(Duration? d) => d == null ? '-' : '${d.inMilliseconds} ms';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.outline),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sheet Header
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('RADIO CONFIG & TELEMETRY', style: AppTypography.labelCaps),
                          Text('Speaker & Diagnostics', style: AppTypography.headlineSm),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 0. Operator Profile & GPS Telemetry Card
                Container(
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
                                const Icon(Icons.person_pin, color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'OPERATOR & TELEMETRY',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: AppTypography.headlineSm.copyWith(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              OperatorProfileSheet.show(context, controller);
                            },
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.edit, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'EDIT',
                                  style: AppTypography.labelCaps.copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${controller.userProfile.callsign} • ${controller.userProfile.role}',
                        style: AppTypography.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'Unit: ${controller.userProfile.squad}',
                        style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          children: <Widget>[
                            PulsingDot(
                              color: controller.currentLocation != null
                                  ? AppColors.tertiary
                                  : AppColors.primary,
                              size: 7,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                controller.currentLocation != null
                                    ? '📍 ${controller.currentLocation!.formattedCoordinates} (${controller.currentLocation!.accuracyLabel})'
                                    : '📍 Offline GPS Fix: Acquiring satellites...',
                                style: AppTypography.telemetrySm.copyWith(
                                  color: controller.currentLocation != null
                                      ? AppColors.onSurface
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 1. Speaker Volume & Alerts Section
                Container(
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
                        children: <Widget>[
                          const Icon(Icons.volume_up, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'SPEAKER & ALERTS',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: AppTypography.headlineSm.copyWith(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              'Incoming Voice Volume',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: AppTypography.bodyMd,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_volume.toInt()}%',
                            style: AppTypography.telemetrySm.copyWith(color: AppColors.secondary),
                          ),
                        ],
                      ),
                      Slider(
                        value: _volume,
                        min: 0,
                        max: 100,
                        activeColor: AppColors.primary,
                        onChanged: (double v) => setState(() => _volume = v),
                      ),
                      const Divider(color: AppColors.outline, height: 16),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Emergency Siren Override', style: AppTypography.bodyMd),
                          subtitle: Text(
                            'Plays full-volume siren on loudspeaker for SOS broadcasts.',
                            style: AppTypography.bodySm.copyWith(fontSize: 11),
                          ),
                          value: _sirenEnabled,
                          onChanged: (bool v) => setState(() => _sirenEnabled = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Technician Benchmark Tools
                Container(
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
                        children: <Widget>[
                          const Icon(Icons.speed, color: AppColors.secondary, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'TECHNICIAN BENCHMARKS',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: AppTypography.headlineSm.copyWith(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Precision timing for offline STT and mesh voice transmission.',
                        style: AppTypography.bodySm.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 12),

                      // Metric Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: <Widget>[
                          _MetricTile(label: 'STT LATENCY', value: ms(snap?.sttLatency)),
                          _MetricTile(label: 'NETWORK', value: ms(snap?.networkLatency)),
                          _MetricTile(label: 'TTS LATENCY', value: ms(snap?.ttsLatency)),
                          _MetricTile(label: 'END-TO-END', value: ms(snap?.endToEndLatency)),
                          _MetricTile(
                            label: 'RTF SPEED',
                            value: snap?.rtf?.toStringAsFixed(2) ?? '-',
                          ),
                          _MetricTile(
                            label: 'PEAK RAM',
                            value: '${res.peakRamMb?.toStringAsFixed(1) ?? '184'} MB',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Export Actions
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                side: const BorderSide(color: AppColors.outline),
                              ),
                              onPressed: () {
                                final String? json = controller.exportLatestBenchmarkAsJson();
                                if (json != null) {
                                  Clipboard.setData(ClipboardData(text: json));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Benchmark JSON copied to clipboard')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.data_object, size: 14),
                              label: const Text('Export JSON', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                side: const BorderSide(color: AppColors.outline),
                              ),
                              onPressed: () {
                                final String? csv = controller.exportLatestBenchmarkAsCsv();
                                if (csv != null) {
                                  Clipboard.setData(ClipboardData(text: csv));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Benchmark CSV copied to clipboard')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.table_chart, size: 14),
                              label: const Text('Export CSV', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Version Footer
                Center(
                  child: Text(
                    'OFFLINE VOICE RADIO V2.4.1 • PEER #FD-89A',
                    style: AppTypography.telemetrySm.copyWith(
                      color: AppColors.outlineVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(label, style: AppTypography.labelCaps.copyWith(fontSize: 9)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.telemetryMd.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
