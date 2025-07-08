import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/journal_provider.dart';
import 'package:clipboard/clipboard.dart';
import '../providers/auth_provider.dart';
import '../providers/roast_provider.dart';

class MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isPremium;
  final bool isStreaming;
  final bool isRoastMode;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isPremium,
    this.isStreaming = false,
    this.isRoastMode = false,
  });

  void _showMessageOptions(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final user = ref.read(authProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDarkMode
              ? Colors.grey[900]
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Message Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Divider(height: 0, color: Colors.grey[600]),
              _buildOptionButton(
                context,
                icon: Icons.content_copy,
                label: 'Copy Text',
                onTap: () {
                  FlutterClipboard.copy(message.content).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  });
                },
              ),
              _buildOptionButton(
                context,
                icon: Icons.delete,
                label: 'Delete Message',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, ref, user.uid);
                },
              ),
              Divider(height: 0, color: Colors.grey[600]),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        bool isDestructive = false,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive
                    ? Colors.red
                    : isDarkMode
                    ? Colors.white
                    : Colors.black,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: isDestructive
                      ? Colors.red
                      : isDarkMode
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String userId) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            'Delete Message',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this message?',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  if (isRoastMode) {
                    // Delete from roast messages
                    await ref.read(roastProvider.notifier).deleteMessage(message.id!, userId);
                  } else {
                    // Delete from normal chat messages
                    await ref.read(chatProvider.notifier).deleteMessage(message.id!, userId);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Message deleted'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Skip messages that are about daily limits
    if (message.content.contains('Daily message limit reached')) {
      return const SizedBox.shrink();
    }

    final isUser = message.role == MessageRole.user;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Get bubble colors
    Color bubbleColor;
    Color textColor;

    if (isRoastMode) {
      // 🔥 Roast Mode
      if (isUser) {
        bubbleColor = isDarkMode
            ? const Color(0xFFFB845D).withOpacity(0.9) // Spicy orange for user
            : const Color(0xFFFFAB91); // Softer orange in light
        textColor = isDarkMode ? Colors.black : const Color(0xFF1A0000); // readable
      } else {
        bubbleColor = isDarkMode
            ? const Color(0xFFD84315) // Roast AI reply dark
            : const Color(0xFFFF5722); // Roast AI reply light
        textColor = Colors.white;
      }
    } else {
      // Regular mode colors
      if (isUser) {
        bubbleColor = theme.colorScheme.primary.withOpacity(0.1);
        textColor = theme.colorScheme.onSurface;
      } else {
        bubbleColor = isDarkMode
            ? const Color(0xFF5D4BBD)  // Darker purple for dark mode
            : const Color(0xFF9688FF); // Original purple for light mode
        textColor = isDarkMode ? Colors.white : Colors.black;
      }
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context, ref),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: isUser
                        ? const Radius.circular(12)
                        : const Radius.circular(0),
                    bottomRight: isUser
                        ? const Radius.circular(0)
                        : const Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isStreaming && !isUser)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: textColor,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}