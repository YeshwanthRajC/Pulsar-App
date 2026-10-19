import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ClarificationDialog extends StatefulWidget {
  final String question;
  final String ambiguousField;
  final String? pendingTitle;
  final Function(String response) onSubmitClarification;
  final VoidCallback? onSaveWithoutReminder;
  final VoidCallback onDismiss;

  const ClarificationDialog({
    super.key,
    required this.question,
    required this.ambiguousField,
    this.pendingTitle,
    required this.onSubmitClarification,
    this.onSaveWithoutReminder,
    required this.onDismiss,
  });

  @override
  State<ClarificationDialog> createState() => _ClarificationDialogState();
}

class _ClarificationDialogState extends State<ClarificationDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final clean = text.trim();
    if (clean.isNotEmpty) {
      widget.onSubmitClarification(clean);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.nebulaNavy : AppColors.lightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.nebulaViolet.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.nebulaViolet.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge & Dismiss
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.nebulaViolet.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.nebulaViolet.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_center_outlined, color: AppColors.nebulaViolet, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'MORE INFO NEEDED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.nebulaViolet,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onDismiss,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Question Prompt
          Text(
            widget.question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 14),

          // Quick Suggestion Chips for Fast Clarification
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.onSaveWithoutReminder != null)
                ActionChip(
                  avatar: const Icon(Icons.flash_on, size: 14, color: AppColors.pulsarCyan),
                  label: const Text(
                    'Save without reminder',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: AppColors.pulsarCyan.withValues(alpha: 0.15),
                  side: BorderSide(color: AppColors.pulsarCyan.withValues(alpha: 0.4)),
                  labelStyle: TextStyle(
                    color: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
                  ),
                  onPressed: widget.onSaveWithoutReminder,
                ),
              if (widget.ambiguousField == 'time') ...[
                _buildSuggestionChip('Today at 7:00 PM', isDark),
                _buildSuggestionChip('Today at 9:00 PM', isDark),
                _buildSuggestionChip('Tomorrow at 10:00 AM', isDark),
                _buildSuggestionChip('Tomorrow at 6:00 PM', isDark),
                _buildSuggestionChip('Next Friday at 4:00 PM', isDark),
              ] else ...[
                _buildSuggestionChip('Call Mom', isDark),
                _buildSuggestionChip('Team Standup', isDark),
                _buildSuggestionChip('Submit Project', isDark),
                _buildSuggestionChip('Buy Groceries', isDark),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Voice Instruction Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic, size: 15, color: AppColors.pulsarCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap the microphone above to speak the answer, or type below:',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Custom Answer Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.ambiguousField == 'time'
                        ? 'e.g. 9:00 PM, tomorrow morning...'
                        : 'Type your clarification...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.nebulaViolet,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: _submit,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.nebulaViolet,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  onPressed: () => _submit(_controller.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label, bool isDark) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      backgroundColor: isDark
          ? AppColors.nebulaViolet.withValues(alpha: 0.15)
          : AppColors.nebulaViolet.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.nebulaViolet.withValues(alpha: 0.35)),
      labelStyle: const TextStyle(color: AppColors.nebulaViolet),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () => widget.onSubmitClarification(label),
    );
  }
}
