import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/gps_location.dart';
import '../../models/user_profile.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import 'pulsing_dot.dart';

/// Modal bottom sheet allowing users to register or edit their tactical operator identity
/// and inspect offline GPS telemetry.
class OperatorProfileSheet extends StatefulWidget {
  const OperatorProfileSheet({
    super.key,
    required this.controller,
    this.isFirstLaunch = false,
  });

  final AppController controller;
  final bool isFirstLaunch;

  static Future<void> show(
    BuildContext context,
    AppController controller, {
    bool isFirstLaunch = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !isFirstLaunch,
      enableDrag: !isFirstLaunch,
      builder: (BuildContext ctx) => OperatorProfileSheet(
        controller: controller,
        isFirstLaunch: isFirstLaunch,
      ),
    );
  }

  @override
  State<OperatorProfileSheet> createState() => _OperatorProfileSheetState();
}

class _OperatorProfileSheetState extends State<OperatorProfileSheet> {
  late final TextEditingController _callsignCtrl;
  late final TextEditingController _squadCtrl;
  late String _selectedRole;
  late bool _shareLocation;
  bool _isRefreshingGps = false;

  @override
  void initState() {
    super.initState();
    final UserProfile profile = widget.controller.userProfile;
    _callsignCtrl = TextEditingController(
      text: widget.isFirstLaunch && !profile.isConfigured
          ? ''
          : profile.callsign,
    );
    _squadCtrl = TextEditingController(text: profile.squad);
    _selectedRole = profile.role;
    _shareLocation = profile.shareLocation;
  }

  @override
  void dispose() {
    _callsignCtrl.dispose();
    _squadCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshGps() async {
    setState(() => _isRefreshingGps = true);
    await widget.controller.refreshLocation();
    if (mounted) {
      setState(() => _isRefreshingGps = false);
    }
  }

  Future<void> _save() async {
    final String callsign = _callsignCtrl.text.trim();
    if (callsign.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an operator callsign or name'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final UserProfile updated = widget.controller.userProfile.copyWith(
      callsign: callsign,
      role: _selectedRole,
      squad: _squadCtrl.text.trim().isEmpty ? 'Alpha Squad' : _squadCtrl.text.trim(),
      shareLocation: _shareLocation,
      isConfigured: true,
    );

    await widget.controller.saveUserProfile(updated);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;
    final GpsLocation? location = controller.currentLocation;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.90,
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
                if (!widget.isFirstLaunch)
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
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_pin,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.isFirstLaunch
                                ? 'FIRST-TIME OPERATOR SETUP'
                                : 'OPERATOR IDENTITY & TELEMETRY',
                            style: AppTypography.labelCaps.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            widget.isFirstLaunch
                                ? 'Initialize Callsign & Role'
                                : 'Radio Identity Settings',
                            style: AppTypography.headlineSm,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Callsign / Name field
                Text(
                  'OPERATOR CALLSIGN / NAME',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _callsignCtrl,
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    hintText: 'e.g. Bravo-6, Tanishq, Medic-1',
                    hintStyle: AppTypography.bodyLg.copyWith(
                      color: AppColors.outlineVariant,
                    ),
                    prefixIcon: const Icon(
                      Icons.badge,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tactical Role selection
                Text(
                  'TACTICAL ROLE',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: UserProfile.standardRoles.map((String role) {
                    final bool isSelected = _selectedRole == role;
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: 'Role $role',
                      child: InkWell(
                        onTap: () => setState(() => _selectedRole = role),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.outline,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.outlineVariant,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                role,
                                style: AppTypography.bodySm.copyWith(
                                  color: isSelected
                                      ? AppColors.onSurface
                                      : AppColors.onSurfaceVariant,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Squad Name field
                Text(
                  'SQUAD / UNIT NAME',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _squadCtrl,
                  style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    hintText: 'Alpha Squad',
                    hintStyle: AppTypography.bodyMd.copyWith(
                      color: AppColors.outlineVariant,
                    ),
                    prefixIcon: const Icon(
                      Icons.groups,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // GPS Telemetry Card
                Container(
                  padding: const EdgeInsets.all(12),
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
                              Icon(
                                Icons.satellite_alt,
                                color: _shareLocation
                                    ? AppColors.tertiary
                                    : AppColors.outlineVariant,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'OFFLINE GPS TELEMETRY',
                                style: AppTypography.labelCaps.copyWith(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Semantics(
                            label: 'Attach GPS coordinates to transmissions',
                            child: Switch.adaptive(
                              value: _shareLocation,
                              onChanged: (bool val) =>
                                  setState(() => _shareLocation = val),
                              activeTrackColor: AppColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Direct satellite coordinates are attached to your outgoing transmissions for emergency location and team coordination.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          children: <Widget>[
                            PulsingDot(
                              color: location != null
                                  ? AppColors.tertiary
                                  : AppColors.primary,
                              size: 7,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                location != null
                                    ? '📍 ${location.formattedCoordinates} (${location.accuracyLabel})'
                                    : '📍 Acquiring satellite coordinates...',
                                style: AppTypography.telemetrySm.copyWith(
                                  color: location != null
                                      ? AppColors.onSurface
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: _isRefreshingGps
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                              tooltip: 'Refresh GPS Fix',
                              onPressed: _isRefreshingGps ? null : _refreshGps,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                Semantics(
                  button: true,
                  label: widget.isFirstLaunch
                      ? 'Save and enter transceiver'
                      : 'Save profile changes',
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _save,
                      child: Text(
                        widget.isFirstLaunch
                            ? 'CONFIRM & ENTER TRANSCEIVER'
                            : 'SAVE PROFILE CHANGES',
                        style: AppTypography.labelCaps.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.onPrimary,
                        ),
                      ),
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
