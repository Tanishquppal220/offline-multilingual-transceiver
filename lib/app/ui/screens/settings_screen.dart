import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/benchmark_models.dart';
import '../../models/connection_config.dart';
import '../../models/language_option.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/pulsing_dot.dart';

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
            const SizedBox(height: 16),

            // Active Mesh Banner Card
            _buildMeshStatusCard(controller),
            const SizedBox(height: 16),

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

  Widget _buildMeshStatusCard(AppController controller) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cell_tower,
              color: AppColors.onSecondaryContainer,
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
                    PulsingDot(
                      color: controller.isConnected
                          ? AppColors.tertiary
                          : AppColors.outlineVariant,
                      size: 8,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      controller.isConnected ? 'MESH RADIO ACTIVE' : 'RADIO STANDBY',
                      style: AppTypography.labelCaps.copyWith(
                        color: controller.isConnected
                            ? AppColors.tertiary
                            : AppColors.outlineVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Relaying voice locally over direct Wi-Fi signals.',
                  style: AppTypography.bodySm,
                ),
              ],
            ),
          ),
        ],
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
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'This phone is the Group Leader (Host)',
                style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Turn this ON if creating the squad group. Turn OFF if joining another phone.',
                style: AppTypography.bodySm,
              ),
              value: config.runAsServer,
              onChanged: (bool val) {
                controller.updateConnectionConfig(config.copyWith(runAsServer: val));
              },
            ),
          ),
          const Divider(color: AppColors.outline, height: 24),
          if (config.runAsServer) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.share, color: AppColors.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Broadcasting as Group Leader on Port 7070',
                      style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            Text('LEADER PHONE IP ADDRESS', style: AppTypography.labelCaps),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _hostController,
                    style: AppTypography.telemetryMd,
                    decoration: const InputDecoration(
                      hintText: '192.168.4.1',
                      prefixIcon: Icon(Icons.router, color: AppColors.outlineVariant),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Default is 192.168.4.1 for most portable hotspots.',
              style: AppTypography.bodySm,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
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
              icon: Icon(controller.isConnected ? Icons.link_off : Icons.link),
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
          const SizedBox(height: 6),
          Text(
            'Select speech model engine and recognition language',
            style: AppTypography.bodySm,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.psychology, color: AppColors.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI ENGINE (HOT-SWAP)',
                      style: AppTypography.labelCaps.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Switch between AI speech backends at runtime to test accuracy vs latency.',
                  style: AppTypography.bodySm,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _EngineSelectCard(
                        title: 'Conformer CTC',
                        subtitle: 'Ultra-Fast • 46MB',
                        icon: Icons.bolt,
                        selected: controller.selectedSttEngine == 'conformer',
                        onTap: () => controller.setSttEngine('conformer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _EngineSelectCard(
                        title: 'Whisper Tiny',
                        subtitle: 'High Accuracy • 99MB',
                        icon: Icons.auto_awesome,
                        selected: controller.selectedSttEngine == 'whisper',
                        onTap: () => controller.setSttEngine('whisper'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('LANGUAGE SELECTION', style: AppTypography.labelCaps),
          const SizedBox(height: 8),
          Column(
            children: kLanguageOptions.map((LanguageOption opt) {
              final bool selected = controller.selectedLanguage.code == opt.code;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.secondary.withValues(alpha: 0.15)
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? AppColors.secondary : AppColors.outline,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(
                      opt.label,
                      style: AppTypography.bodyLg.copyWith(
                        color: selected ? AppColors.secondary : AppColors.onSurface,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: opt.sttSupported
                              ? AppColors.tertiaryFixed
                              : AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          opt.status.toUpperCase(),
                          style: AppTypography.labelCaps.copyWith(
                            color: opt.sttSupported
                                ? AppColors.onTertiaryFixed
                                : AppColors.onSecondaryContainer,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected ? AppColors.secondary : AppColors.outlineVariant,
                      ),
                    ],
                  ),
                  onTap: () => controller.setLanguage(opt),
                ),
              ),
            );
            }).toList(),
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

class _EngineSelectCard extends StatelessWidget {
  const _EngineSelectCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondary.withValues(alpha: 0.15)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.secondary : AppColors.outlineVariant,
                ),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle, size: 16, color: AppColors.secondary)
                else
                  const Icon(Icons.circle_outlined, size: 16, color: AppColors.outlineVariant),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppTypography.bodyLg.copyWith(
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                color: selected ? AppColors.secondary : AppColors.onSurface,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.telemetrySm.copyWith(
                fontSize: 10,
                color: selected ? AppColors.secondary : AppColors.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

