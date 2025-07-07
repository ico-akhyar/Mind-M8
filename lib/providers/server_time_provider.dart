import 'package:flutter_riverpod/flutter_riverpod.dart';

final serverTimeOffsetProvider = StateProvider<Duration>((ref) => Duration.zero);