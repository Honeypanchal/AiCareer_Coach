import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../data/chat_message.model.dart';
import 'chat_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Send message and scroll to bottom ────────────────────────────────────────
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || !ref.read(chatProvider).canSend) return;

    ref.read(chatProvider.notifier).sendMessage(text);
    _controller.clear();

    // Scroll to bottom after the new message renders
    Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Clear chat confirmation dialog ──────────────────────────────────────────
  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'This will delete your entire chat history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final cleared = await ref.read(chatProvider.notifier).clearChat();
              if (!cleared && mounted) {
                showErrorSnackBar(
                  this.context,
                  'Could not clear chat. Please try again.',
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = ref.watch(chatProvider);

    // Put text from another screen into the input so the user can edit it.
    ref.listen(chatDraftProvider, (previous, next) {
      if (next == null) return;
      _controller.text = next;
      ref.read(chatDraftProvider.notifier).state = null;
    });

    // Auto-scroll whenever a new message arrives
    ref.listen(chatProvider, (previous, next) {
      if (previous != null && next.messages.length > previous.messages.length) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppGradients.hero,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Career Coach',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
                Text(
                  chatState.isLoading ? 'Typing...' : 'Always here to help',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            onPressed: chatState.isLoading ? null : _showClearDialog,
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages list ────────────────────────────────────────────────
          Expanded(
            child: chatState.isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    // +1 for the typing indicator when loading
                    itemCount:
                        chatState.messages.length +
                        (chatState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show typing indicator as the last item
                      if (index == chatState.messages.length) {
                        return const _TypingIndicator();
                      }

                      final msg = chatState.messages[index];
                      return _ChatBubble(message: msg, isDark: isDark);
                    },
                  ),
          ),

          // ── Input bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF2A2A40)
                      : const Color(0xFFEEEEF9),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Ask anything...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkCard
                            : AppColors.lightBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: chatState.isLoading ? null : _sendMessage,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: chatState.isLoading
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Bubble ────────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _ChatBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: message.isError
                    ? AppColors.error.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.isError
                    ? Icons.error_outline_rounded
                    : Icons.psychology_rounded,
                color: message.isError ? AppColors.error : AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser ? AppGradients.primary : null,
                    color: isUser
                        ? null
                        : message.isError
                        ? AppColors.error.withValues(alpha: 0.08)
                        : (isDark
                              ? AppColors.darkCard
                              : AppColors.lightSurface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: message.isError
                                ? AppColors.error.withValues(alpha: 0.3)
                                : (isDark
                                      ? const Color(0xFF2A2A40)
                                      : const Color(0xFFEEEEF9)),
                            width: 0.5,
                          ),
                  ),
                  // ── Markdown rendering for AI messages ─────────────────────
                  // User messages are plain text; AI messages support
                  // **bold**, bullet lists, `code`, etc.
                  child: isUser
                      ? Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        )
                      : MarkdownBody(
                          data: message.text,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: message.isError
                                  ? AppColors.error
                                  : (isDark
                                        ? AppColors.textWhite
                                        : AppColors.textDark),
                            ),
                            strong: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            code: TextStyle(
                              backgroundColor: isDark
                                  ? const Color(0xFF0F0F14)
                                  : const Color(0xFFF4F4FB),
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F0F14)
                                  : const Color(0xFFF4F4FB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            listBullet: TextStyle(
                              color: isDark
                                  ? AppColors.textWhite
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.formattedTime,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                    // Retry button on error messages
                    if (message.isError) ...[
                      const SizedBox(width: 8),
                      Consumer(
                        builder: (context, ref, _) => GestureDetector(
                          onTap: () => ref
                              .read(chatProvider.notifier)
                              .retryLastMessage(),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─── Typing Indicator ──────────────────────────────────────────────────────────
// Shows three animated bouncing dots while waiting for AI response.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2A2A40)
                    : const Color(0xFFEEEEF9),
                width: 0.5,
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // Each dot animates with a slight delay (i * 0.2)
                    final delay = i * 0.2;
                    final value = ((_controller.value - delay) % 1.0).clamp(
                      0.0,
                      1.0,
                    );
                    final scale = value < 0.5
                        ? 1.0 + (value * 2 * 0.4)
                        : 1.4 - ((value - 0.5) * 2 * 0.4);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
