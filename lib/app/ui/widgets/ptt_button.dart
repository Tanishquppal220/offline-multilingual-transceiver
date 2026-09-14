import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import 'pulsing_dot.dart';

/// Massive tactical PTT button with concentric radar rings and glow states.
class PttButton extends StatefulWidget {
  const PttButton({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton> {
  bool _pressed = false;

  void _handlePressChanged(bool pressed) {
    if (!mounted) {
      return;
    }

    setState(() {
      _pressed = pressed;
    });

    if (pressed) {
      unawaited(widget.controller.startPushToTalk());
    } else {
      unawaited(widget.controller.stopPushToTalk());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _pressed || widget.controller.isListening;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const _TopWatermark(),
          const SizedBox(height: 12),
          _RingCore(
            active: active,
            pressed: _pressed,
            onPressChanged: _handlePressChanged,
          ),
          const SizedBox(height: 12),
          const _ChannelBar(),
        ],
      ),
    );
  }
}

class _TopWatermark extends StatelessWidget {
  const _TopWatermark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'RX: 7070.00 kHz',
              style: AppTypography.telemetrySm.copyWith(
                color: AppColors.tertiary,
              ),
            ),
            Text(
              '  |  ',
              style: AppTypography.telemetrySm.copyWith(
                color: AppColors.outlineVariant,
              ),
            ),
            Text(
              'BANDWIDTH 16kHz',
              style: AppTypography.telemetrySm.copyWith(
                color: AppColors.outline,
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            const PulsingDot(
              color: AppColors.tertiary,
              size: 6,
            ),
            const SizedBox(width: 6),
            Text(
              'TX READY',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.tertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RingCore extends StatefulWidget {
  const _RingCore({
    required this.active,
    required this.pressed,
    required this.onPressChanged,
  });

  final bool active;
  final bool pressed;
  final ValueChanged<bool> onPressChanged;

  @override
  State<_RingCore> createState() => _RingCoreState();
}

class _RingCoreState extends State<_RingCore> {
  bool _engaged = false;

  void _setEngaged(bool value) {
    if (_engaged != value && mounted) {
      setState(() {
        _engaged = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.active || _engaged;

    return Center(
      child: SizedBox(
        width: 224,
        height: 224,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 224 : 200,
              height: active ? 224 : 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (active
                        ? AppColors.primaryContainer
                        : AppColors.tertiary)
                    .withValues(alpha: 0.05),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 184 : 168,
              height: active ? 184 : 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (active
                        ? AppColors.primaryContainer
                        : AppColors.tertiary)
                    .withValues(alpha: 0.1),
              ),
            ),

            // IMPORTANT:
            // Start recording immediately on finger-down.
            // Do NOT use onLongPressStart here.
            GestureDetector(
              behavior: HitTestBehavior.opaque,

              onTapDown: (_) {
                _setEngaged(true);
                widget.onPressChanged(true);
              },

              onTapUp: (_) {
                widget.onPressChanged(false);
                _setEngaged(false);
              },

              onTapCancel: () {
                widget.onPressChanged(false);
                _setEngaged(false);
              },

              child: AnimatedScale(
                scale: widget.pressed ? 0.96 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: _CoreBody(
                  active: active,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoreBody extends StatelessWidget {
  const _CoreBody({
    required this.active,
  });

  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        active ? AppColors.primaryContainer : AppColors.tertiary;

    final Color fg =
        active ? AppColors.onPrimaryContainer : AppColors.onSurface;

    return Container(
      width: 144,
      height: 144,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? <Color>[
                  AppColors.primaryContainer,
                  AppColors.primaryContainer,
                ]
              : <Color>[
                  AppColors.surfaceBright,
                  AppColors.surfaceContainer,
                ],
        ),
        boxShadow: active
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(
                    alpha: 0.8,
                  ),
                  blurRadius: 24,
                ),
              ]
            : const <BoxShadow>[
                BoxShadow(
                  color: Color(0xB3000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            active ? Icons.mic : Icons.mic_none,
            size: 44,
            color: accent,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              active ? 'TRANSMITTING' : 'HOLD TO\nTRANSMIT',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: 13,
                height: 1.15,
              ),
            ),
          ),
          if (active)
            Text(
              'HOT MIC ACTIVE',
              style: AppTypography.telemetrySm.copyWith(
                color: fg.withValues(alpha: 0.9),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelBar extends StatelessWidget {
  const _ChannelBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.sensors,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'CHANNEL 01',
              style: AppTypography.telemetrySm.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            Text(
              'VOX GAIN',
              style: AppTypography.telemetrySm.copyWith(
                color: AppColors.outline,
              ),
            ),
            const SizedBox(width: 6),
            Row(
              children: List<Widget>.generate(
                5,
                (int i) {
                  final bool lit = i < 3;

                  return Container(
                    width: 6,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: lit
                          ? AppColors.tertiary
                          : AppColors.tertiary.withValues(
                              alpha: 0.3,
                            ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}