import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gpt_service.dart';

final gptServiceProvider = Provider<GPTService>((ref) {
  return GPTService();
});