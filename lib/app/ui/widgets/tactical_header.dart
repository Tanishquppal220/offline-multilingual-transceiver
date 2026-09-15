import 'dart:ui';
import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import 'pulsing_dot.dart';

class TacticalHeader extends StatelessWidget {
  const TacticalHeader({
    super.key,
    required this.controller,
    required this.activeTabTitle,
  });

  final AppController controller;
  final String activeTabTitle;

  @override
  Widget build(BuildContext context) {
    final bool connected = controller.isConnected;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 4,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.90),
            border: const Border(
              bottom: BorderSide(color: AppColors.outline, width: 1),
            ),
          ),
          child: Row(
            children: <Widget>[
              // Tactical Voice Logo & App Title
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                ),
                child: const Icon(
                  Icons.sensors,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'OFFLINE VOICE',
                    style: AppTypography.headlineSm.copyWith(
                      fontSize: 14,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'CH 01 • RELIEF MESH',
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Status Connection Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: connected
                      ? AppColors.tertiaryFixed
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: connected
                        ? AppColors.tertiary.withValues(alpha: 0.5)
                        : AppColors.outline.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    PulsingDot(
                      color: connected
                          ? AppColors.onTertiaryFixed
                          : AppColors.outlineVariant,
                      size: 7,
                      ping: connected,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      connected ? 'MESH ONLINE' : 'LOCAL MESH',
                      style: AppTypography.labelCaps.copyWith(
                        color: connected
                            ? AppColors.onTertiaryFixed
                            : AppColors.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Tactical Person Avatar
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 20,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}