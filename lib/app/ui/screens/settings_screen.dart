import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/benchmark_models.dart';
import '../../models/connection_config.dart';
import '../../models/language_option.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hostController;
  bool _accordionOpen = false;
  double _volume = 85;
  bool _sirenEnabled = true;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(
      text: widget.controller.connectionConfig.host,
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

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 76, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header
            Text('DEVICE SETUP', style: AppTypography.labelCaps),
            Text('Settings & Connection', style: AppTypography.headlineLg),
            Text(
              'Simple controls to keep your team linked without internet access.',
              style: AppTypography.bodySm,
            ),
            // Section 1: Team Connection
            _buildTeamConnectionSection(controller, config),
            const SizedBox(height: 16),

            // Section 2: Voice & Language
            _buildLanguageSection(controller),
            const SizedBox(height: 16),

            // Section 3: Speaker Volume & Alerts
            _buildAudioSection(),
            const SizedBox(height: 16),

            // Section 4: Technician / Benchmark Tools Accordion
            _buildBenchmarkAccordion(controller),
            const SizedBox(height: 20),

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
    );
  }


  Widget _buildTeamConnectionSection(
    AppController controller,
    ConnectionConfig config,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.wifi_tethering, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('1. TEAM CONNECTION', style: AppTypography.headlineSm),
            ],
          ),
          const SizedBox(height: 12),

          // Segmented Role Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => controller.updateConnectionConfig(config.copyWith(runAsServer: true)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: config.runAsServer ? AppColors.tertiaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.hub,
                            size: 16,
                            color: config.runAsServer ? AppColors.onTertiaryContainer : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'HOST MESH',
                            style: AppTypography.labelCaps.copyWith(
                              color: config.runAsServer ? AppColors.onTertiaryContainer : AppColors.onSurfaceVariant,
                              fontWeight: config.runAsServer ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => controller.updateConnectionConfig(config.copyWith(runAsServer: false)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !config.runAsServer ? AppColors.secondaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.link,
                            size: 16,
                            color: !config.runAsServer ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'JOIN SQUAD',
                            style: AppTypography.labelCaps.copyWith(
                              color: !config.runAsServer ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                              fontWeight: !config.runAsServer ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (config.runAsServer) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.sensors, color: AppColors.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ready to broadcast as Host on Port 7070',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            Text('LEADER PHONE IP ADDRESS', style: AppTypography.labelCaps),
            const SizedBox(height: 6),
            TextField(
              controller: _hostController,
              style: AppTypography.telemetryMd,
              decoration: const InputDecoration(
                hintText: '192.168.4.1',
                prefixIcon: Icon(Icons.router, color: AppColors.outlineVariant),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hotspot gateway default: 192.168.4.1',
              style: AppTypography.bodySm.copyWith(fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: controller.isConnected
                    ? AppColors.error
                    : (config.runAsServer
                        ? AppColors.tertiary
                        : AppColors.secondary),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                controller.updateConnectionConfig(
                  config.copyWith(
                    host: _hostController.text.trim(),
                    port: ConnectionConfig.networkPort,
                  ),
                );
                if (controller.isConnected) {
                  await controller.disconnect();
                } else {
                  await controller.connect();
                }
              },
              icon: Icon(controller.isConnected ? Icons.link_off : Icons.link, size: 18),
              label: Text(
                controller.isConnected
                    ? 'DISCONNECT MESH'
                    : (config.runAsServer ? 'START LEADER MESH' : 'CONNECT TO LEADER'),
                style: AppTypography.labelCaps.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(AppController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.translate, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('2. VOICE & LANGUAGE', style: AppTypography.headlineSm),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select edge AI recognition language model',
            style: AppTypography.bodySm,
          ),
          const SizedBox(height: 12),

          // 2-Column Responsive Language Cards Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kLanguageOptions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (BuildContext context, int index) {
              final LanguageOption opt = kLanguageOptions[index];
              final bool selected = controller.selectedLanguage.code == opt.code;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => controller.setLanguage(opt),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.outline,
                        width: selected ? 1.5 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          opt.code.toUpperCase(),
                          style: AppTypography.labelCaps.copyWith(
                            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            opt.label,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMd.copyWith(
                              color: selected ? AppColors.primary : AppColors.onSurface,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.volume_up, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('3. SPEAKER VOLUME & ALERTS', style: AppTypography.headlineSm),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Incoming Voice Volume', style: AppTypography.bodyLg),
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
          const Divider(color: AppColors.outline, height: 20),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Play Emergency Siren on Loudspeaker', style: AppTypography.bodyLg),
              subtitle: Text(
                'Overrides silent mode when someone broadcasts emergency SOS.',
                style: AppTypography.bodySm,
              ),
              value: _sirenEnabled,
              onChanged: (bool v) => setState(() => _sirenEnabled = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenchmarkAccordion(AppController controller) {
    final BenchmarkSnapshot? snap = controller.latestBenchmark;
    final ResourceBenchmark res = controller.resourceBenchmark;

    String ms(Duration? d) => d == null ? '-' : '${d.inMilliseconds} ms';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: ListTile(
              leading: const Icon(Icons.tune, color: AppColors.secondary),
              title: Text(
                'Technician / Benchmark Tools',
                style: AppTypography.headlineSm,
              ),
              trailing: Icon(
                _accordionOpen ? Icons.expand_less : Icons.expand_more,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: () => setState(() => _accordionOpen = !_accordionOpen),
            ),
          ),
          if (_accordionOpen) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Precision telemetry for offline voice transmission benchmarks (T0..T6).',
                    style: AppTypography.bodySm,
                  ),
                  const SizedBox(height: 12),
                  // Metric grid
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
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final String? json = controller.exportLatestBenchmarkAsJson();
                            if (json != null) {
                              Clipboard.setData(ClipboardData(text: json));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Benchmark JSON copied')),
                              );
                            }
                          },
                          icon: const Icon(Icons.data_object, size: 18),
                          label: const Text('Export JSON'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final String? csv = controller.exportLatestBenchmarkAsCsv();
                            if (csv != null) {
                              Clipboard.setData(ClipboardData(text: csv));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Benchmark CSV copied')),
                              );
                            }
                          },
                          icon: const Icon(Icons.table_chart, size: 18),
                          label: const Text('Export CSV'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
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
