import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

class DualSwipeSlider extends StatefulWidget {
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final int snoozeMinutes;

  const DualSwipeSlider({
    super.key,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.snoozeMinutes,
  });

  @override
  State<DualSwipeSlider> createState() => _DualSwipeSliderState();
}

class _DualSwipeSliderState extends State<DualSwipeSlider>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isTriggered = false;

  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  static const double _trackHeight = 64.0;
  static const double _thumbWidth = 72.0;
  static const double _thumbHeight = 52.0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        setState(() {
          _dragOffset = _resetAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxTravel) {
    if (_isTriggered || maxTravel <= 0) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(-maxTravel, maxTravel);
    });

    final progress = _dragOffset / maxTravel;
    if (progress >= 0.75) {
      _isTriggered = true;
      HapticFeedback.heavyImpact();
      widget.onSwipeRight();
    } else if (progress <= -0.75) {
      _isTriggered = true;
      HapticFeedback.heavyImpact();
      widget.onSwipeLeft();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxTravel) {
    if (_isTriggered || maxTravel <= 0) return;
    final progress = _dragOffset / maxTravel;
    final velocity = details.primaryVelocity ?? 0;

    if (progress >= 0.5 || velocity > 300) {
      _isTriggered = true;
      HapticFeedback.heavyImpact();
      widget.onSwipeRight();
      return;
    } else if (progress <= -0.5 || velocity < -300) {
      _isTriggered = true;
      HapticFeedback.heavyImpact();
      widget.onSwipeLeft();
      return;
    }

    _resetAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutCubic,
    ));
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final maxTravel = (totalWidth - _thumbWidth - 12) / 2;
        final progress = maxTravel > 0 ? (_dragOffset / maxTravel).clamp(-1.0, 1.0) : 0.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, maxTravel),
              onHorizontalDragEnd: (d) => _onHorizontalDragEnd(d, maxTravel),
              child: Container(
                width: totalWidth,
                height: _trackHeight,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: progress > 0
                        ? AppColors.pulsarCyan.withValues(alpha: 0.4 + (progress.abs() * 0.5))
                        : (progress < 0
                            ? AppColors.warningOrange.withValues(alpha: 0.4 + (progress.abs() * 0.5))
                            : const Color(0xFF334155)),
                    width: progress.abs() > 0.2 ? 1.8 : 1.2,
                  ),
                  boxShadow: [
                    if (progress > 0.3)
                      BoxShadow(
                        color: AppColors.pulsarCyan.withValues(alpha: 0.25 * progress),
                        blurRadius: 16,
                        spreadRadius: 1,
                      )
                    else if (progress < -0.3)
                      BoxShadow(
                        color: AppColors.warningOrange.withValues(alpha: 0.25 * progress.abs()),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Left side cue: Snooze
                    Positioned(
                      left: 12,
                      child: Opacity(
                        opacity: (0.4 + (progress < 0 ? progress.abs() * 0.6 : 0.0)).clamp(0.2, 1.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.keyboard_double_arrow_left_rounded,
                                color: AppColors.warningOrange, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              'Snooze ${widget.snoozeMinutes}m',
                              style: const TextStyle(
                                color: AppColors.warningOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right side cue: Complete
                    Positioned(
                      right: 12,
                      child: Opacity(
                        opacity: (0.4 + (progress > 0 ? progress * 0.6 : 0.0)).clamp(0.2, 1.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Done',
                              style: TextStyle(
                                color: AppColors.pulsarCyan,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.keyboard_double_arrow_right_rounded,
                                color: AppColors.pulsarCyan, size: 20),
                          ],
                        ),
                      ),
                    ),

                    // Draggable Center Thumb Handle
                    Transform.translate(
                      offset: Offset(_dragOffset, 0),
                      child: Container(
                        width: _thumbWidth,
                        height: _thumbHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: progress > 0.1
                                ? [
                                    AppColors.pulsarCyan,
                                    const Color(0xFF06B6D4),
                                  ]
                                : (progress < -0.1
                                    ? [
                                        AppColors.warningOrange,
                                        const Color(0xFFEA580C),
                                      ]
                                    : [
                                        const Color(0xFF1E293B),
                                        const Color(0xFF0F172A),
                                      ]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: progress.abs() > 0.1
                                ? Colors.white.withValues(alpha: 0.6)
                                : AppColors.pulsarCyan.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            progress > 0.3
                                ? Icons.check_circle_rounded
                                : (progress < -0.3
                                    ? Icons.snooze_rounded
                                    : Icons.drag_handle_rounded),
                            color: progress.abs() > 0.1 ? Colors.black : AppColors.starlightWhite,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Instruction caption (Wrap-safe for all screen widths and test fonts)
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, size: 12, color: AppColors.warningOrange),
                    const SizedBox(width: 4),
                    Text(
                      'Swipe left to snooze',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.moonlightGrey.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text('•', style: TextStyle(color: AppColors.moonlightGrey.withValues(alpha: 0.5))),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Swipe right to complete',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.pulsarCyan.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 12, color: AppColors.pulsarCyan),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
