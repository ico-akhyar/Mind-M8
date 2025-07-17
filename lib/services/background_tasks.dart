import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import '../providers/proactive_provider.dart';
import '../services/gpt_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Firebase
      await Firebase.initializeApp();

      // Load environment variables
      await dotenv.load(fileName: '.env');

      // Initialize GPTService with retry logic
      bool gptInitialized = false;
      int attempts = 0;

      while (!gptInitialized && attempts < 3) {
        try {
          await GPTService().preInitialize();
          gptInitialized = true;
        } catch (e) {
          debugPrint('GPTService initialization attempt ${attempts + 1} failed: $e');
          await Future.delayed(Duration(seconds: 2));
          attempts++;
        }
      }

      if (!gptInitialized) {
        throw Exception('Failed to initialize GPTService after 3 attempts');
      }

      await proactiveNotificationCallback();
      return Future.value(true);
    } catch (e, stack) {
      debugPrint('WorkManager isolate error: $e\n$stack');
      return Future.value(false);
    }
  });
}