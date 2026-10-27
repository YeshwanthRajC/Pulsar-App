import 'package:flutter/material.dart';
import 'package:alarm/model/alarm_settings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_control.dart';
import '../../core/widgets/pulsar_logo.dart';
import '../../services/alarm_service.dart';
import 'widgets/dual_swipe_slider.dart';

class AlarmRingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  final Future<void> Function()? onDismissAndComplete;

  const AlarmRingScreen({
    super.key,
    required this.alarmSettings,
    this.onDismissAndComplete,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    AlarmService.instance.getSnoozeMinutes().then((m) {
      if (mounted) setState(() => _snoozeMinutes = m);
    });
  }

  int _snoozeMinutes = 10;

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isExiting) return;
    _isExiting = true;
    AlarmService.instance.isDismissingWithoutComplete = true;
    await AlarmService.instance.stopRingingAlarm(
      widget.alarmSettings.id,
      markDone: false,
    );
    await _maybeCloseApp();
  }

  Future<void> _dismissAndComplete() async {
    if (_isExiting) return;
    _isExiting = true;
    if (widget.onDismissAndComplete != null) {
      await widget.onDismissAndComplete!();
    }
    await AlarmService.instance.stopRingingAlarm(
      widget.alarmSettings.id,
      markDone: true,
    );
    await _maybeCloseApp();
  }

  Future<void> _snooze() async {
    if (_isExiting) return;
    _isExiting = true;
    await AlarmService.instance.snoozeAlarm(
      widget.alarmSettings.id,
      minutes: _snoozeMinutes,
      title: widget.alarmSettings.notificationSettings.title,
    );
    await _maybeCloseApp();
  }

  Future<void> _maybeCloseApp() async {
    if (AlarmService.instance.openedForAlarm) {
      await AppControl.closeApp();
      AlarmService.instance.openedForAlarm = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.alarmSettings.notificationSettings.title
        .replaceFirst('⏰ Alarm: ', '')
        .replaceFirst('⏰ Snoozed: ', '');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.cosmicBlack,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top header
                Column(
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        PulsarLogo(size: 28),
                        SizedBox(width: 8),
                        Text(
                          'PULSAR ALARM',
                          style: TextStyle(
                            color: AppColors.pulsarCyan,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Center Pulsing Alarm Visual
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulseController.value * 0.12);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.pulsarCyan.withValues(alpha: 0.35),
                                  AppColors.cosmicBlack,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.pulsarCyan
                                      .withValues(alpha: 0.4 * _pulseController.value),
                                  blurRadius: 36,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.alarm_rounded,
                                size: 72,
                                color: AppColors.pulsarCyan,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 36),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.nebulaNavy,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.pulsarCyan.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Ringing Now',
                        style: TextStyle(
                          color: AppColors.pulsarCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                // Interactive Dual-Directional Swipe Slider
                Column(
                  children: [
                    DualSwipeSlider(
                      snoozeMinutes: _snoozeMinutes,
                      onSwipeRight: () => _dismissAndComplete(),
                      onSwipeLeft: () => _snooze(),
                    ),
                    const SizedBox(height: 18),
                    // High-contrast, clearly visible button to dismiss without marking done
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _dismiss(),
                        borderRadius: BorderRadius.circular(24),
                        splashColor: Colors.white.withValues(alpha: 0.1),
                        highlightColor: Colors.white.withValues(alpha: 0.05),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.nebulaNavy,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.moonlightGrey.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.starlightWhite,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Dismiss without completing',
                                style: TextStyle(
                                  color: AppColors.starlightWhite,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
