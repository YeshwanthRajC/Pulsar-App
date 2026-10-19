import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../core/constants/app_colors.dart';
import 'widgets/voice_pulse_button.dart';
import 'widgets/staged_task_review_dialog.dart';
import 'widgets/clarification_dialog.dart';

class VoiceInputTab extends StatefulWidget {
  final VoidCallback? onSwitchToManual;

  const VoiceInputTab({
    super.key,
    this.onSwitchToManual,
  });

  @override
  State<VoiceInputTab> createState() => _VoiceInputTabState();
}

class _VoiceInputTabState extends State<VoiceInputTab> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        const SizedBox(height: 6),

        // 1. Live Engine Status Badge
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: provider.isNeedleRunning
                  ? AppColors.pulsarCyan.withValues(alpha: 0.12)
                  : AppColors.moonlightGrey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: provider.isNeedleRunning
                    ? AppColors.pulsarCyan.withValues(alpha: 0.35)
                    : AppColors.moonlightGrey.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  provider.isNeedleRunning ? Icons.offline_bolt : Icons.tune,
                  size: 13,
                  color: provider.isNeedleRunning
                      ? AppColors.pulsarCyan
                      : (isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    provider.modelStatusMessage,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: provider.isNeedleRunning
                          ? (isDark ? AppColors.pulsarCyan : AppColors.lightCyan)
                          : (isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 2. Glowing Pulsar Microphone
        VoicePulseButton(
          isListening: provider.isListening,
          isProcessing: provider.isProcessingAI || provider.isTranscribing,
          onTap: () {
            if (provider.isProcessingAI || provider.isTranscribing) return;
            provider.toggleVoiceCapture();
          },
        ),

        const SizedBox(height: 12),

        // 3. Subtitle Status Indicator
        Center(
          child: Text(
            provider.isListening
                ? 'Listening... tap again when done speaking'
                : (provider.isTranscribing
                    ? 'Transcribing speech with Whistle...'
                    : (provider.isProcessingAI
                        ? 'Extracting task draft with Needle...'
                        : 'Tap the microphone to tell your task')),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.starlightWhite : AppColors.lightTextPrimary,
            ),
          ),
        ),

        // 4. Helpful Tip
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'The model might make mistakes, feel free to edit your tasks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.moonlightGrey : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. Live Audio Transcript Card
        if (provider.liveTranscript.isNotEmpty && !provider.isListening) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 18,
                    color: AppColors.pulsarCyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.liveTranscript,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // 5. Error Feedback (if any)
        if (provider.voiceError != null) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 15, color: AppColors.errorRed),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      provider.voiceError!,
                      style: const TextStyle(fontSize: 12, color: AppColors.errorRed),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // 6. Interactive Task Draft Confirmation Card (User can update details: time 7pm -> 9pm, date, title, reminder)
        if (provider.stagedTasks.isNotEmpty) ...[
          StagedTaskReviewDialog(
            tasks: provider.stagedTasks,
            onTaskUpdated: (index, updatedTask) {
              provider.updateStagedTask(index, updatedTask);
            },
            onTaskRemoved: (index) {
              provider.removeStagedTask(index);
            },
            onConfirm: () async {
              final messenger = ScaffoldMessenger.of(context);
              await provider.confirmStagedTasks();
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.pulsarCyan, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Task confirmed and scheduled!',
                          style: TextStyle(
                            color: AppColors.starlightWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.nebulaNavy,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.nebulaNavyBorder, width: 1),
                    ),
                  ),
                );
              }
            },
            onCancel: () => provider.cancelStagedTasks(),
          ),
          const SizedBox(height: 12),
        ],

        // 7. Clarification Dialog (Prompted when information is insufficient or missing)
        if (provider.clarificationPrompt != null) ...[
          ClarificationDialog(
            question: provider.clarificationPrompt!['question'] as String? ??
                'Could you clarify the details for this task?',
            ambiguousField: provider.clarificationPrompt!['field'] ??
                provider.clarificationPrompt!['ambiguousField'] as String? ??
                'field',
            pendingTitle: provider.clarificationPrompt!['title'] ??
                provider.clarificationPrompt!['pendingTitle'] as String?,
            onSaveWithoutReminder: provider.clarificationPrompt!['title'] != null ||
                    provider.clarificationPrompt!['pendingTitle'] != null
                ? () {
                    final title = (provider.clarificationPrompt!['title'] ??
                        provider.clarificationPrompt!['pendingTitle']) as String;
                    provider.saveClarificationTaskWithoutReminder(title);
                  }
                : null,
            onSubmitClarification: (answer) {
              final pendingTitle = provider.clarificationPrompt!['pendingTitle'] ??
                  provider.clarificationPrompt!['title'];
              if (pendingTitle != null) {
                provider.submitVoiceCommand('$pendingTitle $answer');
              } else {
                provider.submitVoiceCommand(answer);
              }
            },
            onDismiss: () => provider.cancelStagedTasks(),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}
