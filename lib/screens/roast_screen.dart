import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/roast_provider.dart';
import '../widgets/message_bubble.dart';
import '../theme/app_theme.dart';

class RoastScreen extends ConsumerStatefulWidget {
  const RoastScreen({super.key});

  @override
  ConsumerState<RoastScreen> createState() => _RoastScreenState();
}

class _RoastScreenState extends ConsumerState<RoastScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isInitializing = true;
  bool _isSending = false;
  bool _warningShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWarningDialog();
    });
  }

  Future<void> _showWarningDialog() async {
    if (_warningShown) return;

    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            title: const Text('User Warning'),
            content: const Text(
                '⚠️ Warning: Roast Mode is brutally honest and purely for fun.\n\n'
                    'If you struggle with low self-confidence or feel sensitive about your looks or personality, we recommend avoiding Roast Mode. Some jokes might hit hard – especially if they touch on appearance. 😬\n\n'
                    'But remember: no roast is serious. It’s all just playful banter – everyone is unique and has their own vibe ✨ Nobody’s perfect, and that’s what makes you real.\n\n'
                    '📖 “Indeed, We have created humans in the best of forms.”\n— (Quran 95:4)\n\n'
                    'Do you still wanna continue? 😈'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                    'Go Back', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
    ) ?? false;

    if (!shouldContinue && mounted) {
      Navigator.of(context).pop();
      return;
    }

    _warningShown = true;
    _initializeRoastMode();
  }

  Future<void> _initializeRoastMode() async {
    try {
      await ref.read(roastProvider.notifier).initializeRoast();
      if (mounted) {
        setState(() => _isInitializing = false);
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize roast mode')),
        );
        setState(() => _isInitializing = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendRoastBack() async {
    if (_messageController.text.isEmpty || _isSending) return;
    if (!ref
        .read(roastProvider.notifier)
        .canRoastMore) return;

    setState(() => _isSending = true);
    try {
      await ref.read(roastProvider.notifier).sendRoastBack(
          _messageController.text);
      _messageController.clear();
      _scrollToBottom();

      await ref.read(roastProvider.notifier).sendAiRoast();
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _startRoast() async {
    setState(() => _isSending = true);
    try {
      await ref.read(roastProvider.notifier).sendAiRoast();
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(roastProvider);
    final canRoastMore = ref.watch(roastProvider.notifier).canRoastMore;
    final remaining = ref.watch(roastProvider.notifier).remainingRoastsToday;
    final hasEnoughData = ref.watch(roastProvider.notifier).hasEnoughData;
    final isTyping = ref.watch(roastProvider.notifier).isTyping;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final roastTheme = isDarkMode ? AppTheme.roastDarkTheme : AppTheme.roastLightTheme;

    return Theme(
      data: roastTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Roast Mode'),
          actions: [
            if (isTyping)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Text(
                    'Typing...',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.warning_amber),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Roast Mode 🔥'),
                      content: const Text(
                        'Roast Mode is all about fun — brutal honesty, Gen Z slang, and savage comebacks 😈\n\n'
                            'Don\'t take it to heart — it\'s never personal. Just laugh it off and enjoy the chaos 😂🔥\n\n'
                      'Never think about the jokes made on your appearance.\n'
                        '📖 "Indeed, We have created humans in the best of forms."\n— (Quran 95:4)\n\n'
                        'Warning: Feelings might get toasted 😈',
                      ),
                      actions: [
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isInitializing
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: messages.length + (isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (isTyping && index == messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Mind M8 is typing...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    );
                  }
                  final message = messages[index];
                  return MessageBubble(
                    message: message,
                    isPremium: true,
                    isRoastMode: true,
                  );
                },
              ),
            ),
            if (messages.isEmpty && !_isInitializing)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _startRoast,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: roastTheme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Get Roasted 🔥',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            if (messages.isNotEmpty && canRoastMore)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Roast back...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? const Color(0xFF2E0000)
                              : Colors.white,
                        ),
                        onSubmitted: hasEnoughData
                            ? (_) => _sendRoastBack()
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isSending
                          ? const CircularProgressIndicator()
                          : Icon(Icons.send,
                          color: hasEnoughData
                              ? roastTheme.colorScheme.primary
                              : Colors.grey),
                      onPressed: hasEnoughData ? _sendRoastBack : null,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    'Roasts left today: $remaining/5',
                    style: TextStyle(
                      color: remaining > 0
                          ? roastTheme.colorScheme.primary
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!hasEnoughData && messages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Not enough data to roast back',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}