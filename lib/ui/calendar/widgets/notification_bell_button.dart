import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/notification_settings_provider.dart';

/// Bell icon that toggles app notifications on/off. On first launch it shows a
/// small hint bubble next to the icon that disappears after 5 seconds.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _hintEntry;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<NotificationSettingsProvider>();
      if (settings.shouldShowHint) {
        _showHint();
        settings.markHintShown();
      }
    });
  }

  void _showHint() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _hintEntry = OverlayEntry(
      builder: (_) => Positioned(
        width: 230,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 4),
          child: Material(
            color: Colors.transparent,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.pulsarCyan.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pulsarCyan.withValues(alpha: 0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  'Turn notifications on or off here',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_hintEntry!);
    _hintTimer = Timer(const Duration(seconds: 5), _removeHint);
  }

  void _removeHint() {
    _hintTimer?.cancel();
    _hintEntry?.remove();
    _hintEntry = null;
  }

  @override
  void dispose() {
    _removeHint();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<NotificationSettingsProvider>();

    return CompositedTransformTarget(
      link: _link,
      child: IconButton(
        tooltip: settings.enabled ? 'Notifications on' : 'Notifications off',
        icon: Icon(
          settings.enabled
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          size: 24,
        ),
        color: settings.enabled
            ? (isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary)
            : (isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary),
        onPressed: () async {
          _removeHint();
          final messenger = ScaffoldMessenger.of(context);
          final nowOn = await settings.toggle();
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark
                      ? (nowOn
                          ? AppColors.pulsarCyan.withValues(alpha: 0.6)
                          : AppColors.nebulaNavyBorder)
                      : (nowOn ? AppColors.lightCyan : AppColors.lightBorder),
                  width: 1.2,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
              duration: const Duration(seconds: 2),
              content: Row(
                children: [
                  Icon(
                    nowOn
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    color: nowOn
                        ? AppColors.pulsarCyan
                        : (isDark
                            ? AppColors.moonlightGrey
                            : AppColors.lightTextSecondary),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nowOn
                          ? 'Notifications turned on'
                          : 'Notifications turned off',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.starlightWhite
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
