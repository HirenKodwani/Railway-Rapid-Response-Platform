import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to manage the selected index of the bottom navigation bar.
/// This allows any screen in the app to programmatically switch tabs.
final shellNavigationProvider = StateProvider<int>((ref) => 0);
