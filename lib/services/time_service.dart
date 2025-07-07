import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/server_time_provider.dart';

Future<void> syncServerTime(ProviderContainer container) async {
  try {
    final docRef = FirebaseFirestore.instance.collection('tempTimestamps').doc();
    await docRef.set({'timestamp': FieldValue.serverTimestamp()});

    final doc = await docRef.get();
    final serverTime = (doc.data()!['timestamp'] as Timestamp).toDate();
    final localTime = DateTime.now();

    final offset = serverTime.difference(localTime);
    container.read(serverTimeOffsetProvider.notifier).state = offset;

    await docRef.delete();
  } catch (e) {
    print('Error syncing server time: $e');
    container.read(serverTimeOffsetProvider.notifier).state = Duration.zero;
  }
}

Future<void> syncServerTimeWithRef(WidgetRef ref) async {
  final container = ProviderScope.containerOf(ref.context);
  await syncServerTime(container);
}

DateTime getServerTime(WidgetRef ref) {
  final offset = ref.read(serverTimeOffsetProvider);
  return DateTime.now().add(offset);
}
