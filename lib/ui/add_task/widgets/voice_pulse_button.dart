import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class VoicePulseButton extends StatefulWidget {
  final bool isListening;
  final bool isProcessing;
  final VoidCallback onTap;

  const VoicePulseButton({
    super.key,
    required this.isListening,
    required this.isProcessing,
    required this.onTap,
  });

  @override
  State<VoicePulseButton> createState() => _VoicePulseButtonState();
}

class _VoicePulseButtonState extends State<VoicePulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseVal = _pulseController.value;
            final isActive = widget.isListening || widget.isProcessing;

            return SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Pulsing Wave 2
                  if (isActive)
                    Container(
                      width: 130 + (40 * pulseVal),
                      height: 130 + (40 * pulseVal),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.pulsarCyan.withValues(alpha: 0.3 * (1 - pulseVal)),
                          width: 2,
                        ),
                      ),
                    ),

                  // Outer Pulsing Wave 1
                  if (isActive)
                    Container(
                      width: 110 + (25 * pulseVal),
                      height: 110 + (25 * pulseVal),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.nebulaViolet.withValues(alpha: 0.5 * (1 - pulseVal)),
                          width: 2.5,
                        ),
                      ),
                    ),

                  // Middle Halo Orbit
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isListening
                            ? AppColors.pulsarCyan
                            : (widget.isProcessing
                                ? AppColors.nebulaViolet
                                : (isDark
                                    ? AppColors.pulsarCyan.withValues(alpha: 0.3)
                                    : AppColors.lightCyan.withValues(alpha: 0.4))),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isListening
                                  ? AppColors.pulsarCyan
                                  : AppColors.nebulaViolet)
                              .withValues(alpha: isActive ? 0.35 : 0.1),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  // Main Core Microphone Button
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.isListening
                            ? [AppColors.pulsarCyan, AppColors.pulsarCyanDark]
                            : (widget.isProcessing
                                ? [AppColors.nebulaViolet, AppColors.nebulaVioletDark]
                                : [
                                    isDark ? AppColors.nebulaNavy : AppColors.lightCard,
                                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  ]),
                      ),
                    ),
                    child: Center(
                      child: widget.isProcessing
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.mic,
                              size: 40,
                              color: widget.isListening
                                  ? AppColors.cosmicBlack
                                  : (isDark ? AppColors.pulsarCyan : AppColors.lightCyan),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
