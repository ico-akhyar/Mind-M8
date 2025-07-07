import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'providers/proactive_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/time_service.dart';
import 'services/gpt_service.dart';

/// ✅ Auth Provider (Reactive)
final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: '.env');

    // Initialize Firebase
    await Firebase.initializeApp();

    // Set up FCM token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
      }
    });

    // Init ProviderScope early
    final container = ProviderContainer();
    await syncServerTime(container);
    await GPTService().preInitialize();
    await GPTService().warmUpConnection();
    await NotificationService.init();
    await NotificationService.setupInteractedMessage();

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('Main initialization error: $e\n$stack');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Initialization failed'),
                Text(e.toString()),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (state == AppLifecycleState.paused) {
      ref.read(proactiveProvider.notifier).scheduleProactiveCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);

    return authAsync.when(
      loading: () => MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Auth Error: $e')),
        ),
      ),
      data: (user) {
        final isVerified = user?.emailVerified ?? false;

        return MaterialApp(
          title: 'MindM8',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          builder: (context, child) {
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child,
            );
          },
          home: user != null && isVerified
              ? const HomeScreen()
              : const LoginScreen(),
        );
      },
    );
  }
}