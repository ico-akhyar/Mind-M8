import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/app_drawer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/time_service.dart';
import 'dart:async';
import '../providers/proactive_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  bool _isPremium = false;
  bool _hasCheckedPremium = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSending = false;
  bool _isWaitingForResponse = false;
  Timer? _timeSyncTimer;
  bool _shouldScrollToBottom = true;
  int _dailyMessageCount = 0;
  DateTime? _lastResetDate;
  bool _isLoadingMore = false;

  // Replace the _setupRefreshListener with this in your home_screen.dart
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupNotificationInteractions();
        _scheduleTimeSync();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedPremium) {
      _initializeChat();
      _checkPremiumStatus();
      _checkProactiveNotifications();
      _loadMessageCount();
    }
  }

  Future<void> _loadMessageCount() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final serverTime = await ref.read(chatProvider.notifier).getServerTimeReference();
    final todayMidnight = DateTime(serverTime.year, serverTime.month, serverTime.day);

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    if (data == null) return;

    final Timestamp? lastResetTs = data['lastMessageCountReset'];
    final lastReset = lastResetTs?.toDate();
    final count = data['dailyMessageCount'] ?? 0;

    // Check if it's a new day and reset if needed
    if (lastReset == null || lastReset.isBefore(todayMidnight)) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'lastMessageCountReset': FieldValue.serverTimestamp(),
        'dailyMessageCount': 0,
      });

      if (mounted) {
        setState(() {
          _dailyMessageCount = 0;
          _lastResetDate = DateTime.now();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _dailyMessageCount = count;
          _lastResetDate = lastReset;
        });
      }
    }
  }

  Future<void> _checkProactiveNotifications() async {
    final wasProactiveSent = await ref.read(proactiveProvider.notifier)
        .checkForMissedProactiveNotification();
    if (wasProactiveSent && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) await _syncMessages();
    }
    _hasCheckedPremium = true;
  }

  void _scheduleTimeSync() {
    syncServerTimeWithRef(ref);
    _timeSyncTimer?.cancel();
    _timeSyncTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (mounted) syncServerTimeWithRef(ref);
    });
  }

  Future<void> _checkPremiumStatus() async {
    final userId = ref.read(authProvider)?.uid;
    if (userId == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return;

    if (data['isPremium'] == true) {
      final expiry = (data['premiumExpiry'] as Timestamp).toDate();
      if (expiry.isAfter(DateTime.now())) {
        if (mounted) setState(() => _isPremium = true);
      } else {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isPremium': false,
          'premiumPlan': '',
          'premiumSince': null,
          'premiumExpiry': null,
        });
      }
    }
  }

  Future<void> _setupNotificationInteractions() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleNotificationMessage(initialMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationMessage);
  }

  void _handleNotificationMessage(RemoteMessage message) {
    final userId = message.data['userId'];
    final currentUser = ref.read(authProvider);
    if (currentUser?.uid == userId && message.data['message'] != null) {
      ref.read(chatProvider.notifier).handleProactiveNotification(
        message.data['message']!,
        userId,
      );
      _scrollToBottom();
    }
  }

  Future<void> _initializeChat() async {
    if (ref.read(authProvider) != null) {
      await _syncMessages();
    }
  }


  Future<void> _syncMessages() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authProvider);
      if (user != null) {
        // Preserve existing messages including optimistic ones
        final currentMessages = ref.read(chatProvider);

        // Fetch updates
        await ref.read(chatProvider.notifier)
            .fetchInitialMessages(user.uid, isPremium: _isPremium);

        // Reload message count after sync
        await _loadMessageCount();

        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _timeSyncTimer?.cancel();
    super.dispose();
  }

  // Add this method to handle initial scroll
  Future<void> _handleInitialScroll() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (_scrollController.hasClients && mounted) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }


  void _scrollToBottom() {
    if (!_shouldScrollToBottom) return;

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

  void _scrollListener() {
    final isAtBottom = _scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent;

    if (isAtBottom) {
      _shouldScrollToBottom = true;
    } else {
      _shouldScrollToBottom = false;

      // Only trigger load more when near top, not immediately
      if (_scrollController.position.pixels <
          _scrollController.position.maxScrollExtent * 0.2) {
        final user = ref.read(authProvider);
        if (user != null && !_isLoadingMore) {
          setState(() => _isLoadingMore = true);
          ref.read(chatProvider.notifier)
              .loadMoreMessages(user.uid, isPremium: _isPremium)
              .whenComplete(() {
            if (mounted) {
              setState(() => _isLoadingMore = false);
            }
          });
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    if (_messageController.text.isEmpty || _isSending) return;

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() {
      _isSending = true;
      _isWaitingForResponse = true;
      _shouldScrollToBottom = true;
    });

    try {
      // Check message limits
      final max = _isPremium ? 50 : 10;
      if (_dailyMessageCount >= max) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isPremium
                    ? 'Premium daily limit reached'
                    : 'Daily limit reached - upgrade for more messages',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      final message = _messageController.text;
      _messageController.clear();

      // Add optimistic user message
      ref.read(chatProvider.notifier).addOptimisticUserMessage(message);
      _scrollToBottom();

      // Send message
      await ref.read(chatProvider.notifier).sendMessage(
        userId: user.uid,
        message: message,
        isPremium: _isPremium,
      );

      // Update local count
      if (mounted) {
        setState(() {
          _dailyMessageCount++;
        });
      }

      _scrollToBottom();
      print('Message cycle completed: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.stop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isWaitingForResponse = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final messages = ref.watch(chatProvider);

    // Add this right here:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shouldScrollToBottom && _scrollController.hasClients) {
        _handleInitialScroll();
      }
    });

    final max = _isPremium ? 50 : 10;
    final dailyCanSend = _dailyMessageCount < max;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mind M8'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncMessages,
            tooltip: 'Sync messages',
          ),
          if (_isLoading && messages.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      drawer: AppDrawer(onSettingsClosed: _syncMessages),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  SvgPicture.asset(
                    AppTheme.getLogoAsset(context),
                    width: 220,
                    height: 220,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Start Chatting',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
                      onRefresh: _syncMessages,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: messages.length + (_isWaitingForResponse ? 1 : 0) + (_isLoadingMore ? 1 : 0),
                        cacheExtent: 1000, // Add this line to cache more items off-screen
                        physics: const AlwaysScrollableScrollPhysics(), // Ensures smooth scrolling
                        itemBuilder: (context, index) {
                          // Loading more indicator at top
                          if (_isLoadingMore && index == 0) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          // Adjust index for loading more indicator
                          final adjustedIndex = _isLoadingMore ? index - 1 : index;

                          // Waiting for response indicator
                          if (_isWaitingForResponse && adjustedIndex == messages.length) {
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

                          return MessageBubble(
                            key: ValueKey(messages[adjustedIndex].id), // Add unique key
                            message: messages[adjustedIndex],
                            isPremium: _isPremium,
                          );
                        },
                      )
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isPremium
                            ? 'Premium: $_dailyMessageCount/50 today'
                            : 'Free: $_dailyMessageCount/10 today',
                        style: TextStyle(
                          fontSize: 12,
                          color: !dailyCanSend
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        '${max - _dailyMessageCount} remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: !dailyCanSend
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!dailyCanSend)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _isPremium
                          ? 'Premium daily limit reached'
                          : 'Daily limit reached - upgrade for more',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: dailyCanSend
                              ? 'Type your message...'
                              : _isPremium
                              ? 'Premium limit reached'
                              : 'Upgrade to send more',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          enabled: dailyCanSend && !_isSending,
                        ),
                        onSubmitted: dailyCanSend ? (_) => _sendMessage() : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: _isSending
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      onPressed: dailyCanSend && !_isSending ? _sendMessage : null,
                      color: dailyCanSend
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).disabledColor,
                      splashRadius: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}