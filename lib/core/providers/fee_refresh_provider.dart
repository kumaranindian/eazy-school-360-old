import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to signal when fee data needs to be refreshed across screens
final feeRefreshProvider = StateProvider<int>((ref) {
  return DateTime.now().millisecondsSinceEpoch;
});

/// Function to trigger a refresh of fee data
void triggerFeeRefresh(WidgetRef ref) {
  final newTimestamp = DateTime.now().millisecondsSinceEpoch;
  print('[FeeRefreshProvider] Triggering refresh with timestamp: $newTimestamp');
  ref.read(feeRefreshProvider.notifier).state = newTimestamp;
}
