import 'package:flutter/material.dart';

import '../../models/benchmark_models.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/telemetry_metric_card.dart';

/// Telemetry tab — benchmark metrics dashboard.
class TelemetryScreen extends StatelessWidget {
  const TelemetryScreen({super.key, required this.controller});

  final AppController controller;

  String _ms(Duration? value) {
    return value == null ? '-' : '${value.inMilliseconds} ms';
  }

  String _mb(double? value) {
    return value == null ? '-' : value.toStringAsFixed(2);
  }

  String _pct(double? value) {
    return value == null ? '-' : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final BenchmarkSnapshot? snapshot = controller.latestBenchmark;
    final ResourceBenchmark resource = controller.resourceBenchmark;
    final bool canExport = snapshot != null;
    final bool hasHistory = controller.benchmarkHistory.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 76, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'TELEMETRY DASHBOARD',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.outline,
                letterSpacing: 0.14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${controller.benchmarkHistory.length} / 50 samples',
              style: AppTypography.telemetrySm.copyWith(
                color: AppColors.tertiary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    controller.selectedSttEngine == 'whisper'
                        ? Icons.auto_awesome
                        : Icons.bolt,
                    size: 20,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'ACTIVE AI ENGINE',
                          style: AppTypography.labelCaps.copyWith(
                            color: AppColors.outlineVariant,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          controller.selectedSttEngine == 'whisper'
                              ? 'OpenAI Whisper (Multilingual Tiny)'
                              : 'NeMo Conformer-CTC (int8)',
                          style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final String next = controller.selectedSttEngine == 'whisper'
                          ? 'conformer'
                          : 'whisper';
                      controller.setSttEngine(next);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.secondary),
                      ),
                      child: Text(
                        'SWAP',
                        style: AppTypography.labelCaps.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('LATENCY (T0..T6)'),
            const SizedBox(height: 8),
            _MetricGrid(
              children: <Widget>[
                TelemetryMetricCard(
                  label: 'STT',
                  value: _ms(snapshot?.sttLatency),
                ),
                TelemetryMetricCard(
                  label: 'Network',
                  value: _ms(snapshot?.networkLatency),
                ),
                TelemetryMetricCard(
                  label: 'TTS',
                  value: _ms(snapshot?.ttsLatency),
                ),
                TelemetryMetricCard(
                  label: 'End-to-End',
                  value: _ms(snapshot?.endToEndLatency),
                  color: AppColors.primary,
                ),
                TelemetryMetricCard(
                  label: 'RTF',
                  value: snapshot?.rtf == null
                      ? '-'
                      : snapshot!.rtf!.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle('RESOURCE USAGE'),
            const SizedBox(height: 8),
            _MetricGrid(
              children: <Widget>[
                TelemetryMetricCard(
                  label: 'Idle RAM',
                  value: _mb(resource.idleRamMb),
                  unit: 'MB',
                ),
                TelemetryMetricCard(
                  label: 'Peak RAM',
                  value: _mb(resource.peakRamMb),
                  unit: 'MB',
                  color: AppColors.primary,
                ),
                TelemetryMetricCard(
                  label: 'STT RAM',
                  value: _mb(resource.sttRamMb),
                  unit: 'MB',
                ),
                TelemetryMetricCard(
                  label: 'TTS RAM',
                  value: _mb(resource.ttsRamMb),
                  unit: 'MB',
                ),
                TelemetryMetricCard(
                  label: 'Idle CPU',
                  value: _pct(resource.idleCpuPct),
                  unit: '%',
                ),
                TelemetryMetricCard(
                  label: 'STT CPU',
                  value: _pct(resource.sttCpuPct),
                  unit: '%',
                ),
                TelemetryMetricCard(
                  label: 'TTS CPU',
                  value: _pct(resource.ttsCpuPct),
                  unit: '%',
                ),
                TelemetryMetricCard(
                  label: 'STT Model',
                  value: _mb(resource.sttModelSizeMb),
                  unit: 'MB',
                ),
                TelemetryMetricCard(
                  label: 'TTS Model',
                  value: _mb(resource.ttsModelSizeMb),
                  unit: 'MB',
                ),
                TelemetryMetricCard(
                  label: 'APK Size',
                  value: _mb(resource.apkSizeMb),
                  unit: 'MB',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle('EXPORT'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: <Widget>[
                  _ExportRow(
                    enabled: canExport,
                    onCopy: () => controller.exportLatestBenchmarkAsJson(),
                  ),
                  const SizedBox(height: 8),
                  _ExportRow(
                    enabled: hasHistory,
                    onCopy: () => controller.exportBenchmarkHistoryAsJson(),
                    history: true,
                  ),
                  if (!canExport) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Run one message to enable export.',
                      style: AppTypography.telemetrySm.copyWith(
                        color: AppColors.outlineVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelCaps.copyWith(color: AppColors.outline),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: children,
    );
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.enabled,
    required this.onCopy,
    this.history = false,
  });

  final bool enabled;
  final VoidCallback onCopy;
  final bool history;

  @override
  Widget build(BuildContext context) {
    final String label = history ? 'HISTORY JSON' : 'LATEST JSON';

    return Row(
      children: <Widget>[
        Expanded(
          child: Material(
            color: enabled
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: enabled ? onCopy : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.data_object,
                      size: 16,
                      color: enabled
                          ? AppColors.secondary
                          : AppColors.outlineVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: AppTypography.labelCaps.copyWith(
                        color: enabled
                            ? AppColors.secondary
                            : AppColors.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}