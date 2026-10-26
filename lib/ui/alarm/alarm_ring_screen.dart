import 'package:flutter/material.dart';
import 'package:alarm/model/alarm_settings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/pulsar_logo.dart';
import '../../services/alarm_service.dart';

class AlarmRingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  final VoidCallback? onDismissAndComplete;

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

  void _dismiss(BuildContext context) {
    AlarmService.instance.stopRingingAlarm(widget.alarmSettings.id);
  }

  void _dismissAndComplete(BuildContext context) {
    widget.onDismissAndComplete?.call();
    _dismiss(context);
  }

  void _snooze(BuildContext context) {
    AlarmService.instance.snoozeAlarm(
      widget.alarmSettings.id,
      minutes: _snoozeMinutes,
      title: widget.alarmSettings.notificationSettings.title,
    );
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

                // Bottom Action Buttons
                Column(
                  children: [
                    // Dismiss and complete task button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.black, size: 22),
                        label: const Text(
                          'Dismiss & Mark as Done',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pulsarCyan,
                          elevation: 6,
                          shadowColor: AppColors.pulsarCyan.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _dismissAndComplete(context),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dismiss only & Snooze row
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.moonlightGrey, size: 20),
                              label: const Text(
                                'Dismiss',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => _dismiss(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.snooze_rounded,
                                  color: Colors.white, size: 20),
                              label: Text(
                                'Snooze ${_snoozeMinutes}m',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.nebulaNavy,
                                side: BorderSide(
                                  color: AppColors.nebulaViolet.withValues(alpha: 0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => _snooze(context),
                            ),
                          ),
                        ),
                      ],
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
