import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/match.dart';
import '../services/match_sync_service.dart';

final matchesProvider = FutureProvider<List<AppMatch>>((ref) async {
  final syncService = ref.watch(matchSyncServiceProvider);
  return syncService.syncMatches();
});

final upcomingMatchesProvider = FutureProvider<List<AppMatch>>((ref) async {
  final matches = await ref.watch(matchesProvider.future);
  return matches.where((m) => m.isUpcoming).toList();
});

final liveMatchesProvider = FutureProvider<List<AppMatch>>((ref) async {
  final matches = await ref.watch(matchesProvider.future);
  return matches.where((m) => m.isLive).toList();
});

final matchesByGroupProvider = FutureProvider.family<List<AppMatch>, String>((ref, group) async {
  final matches = await ref.watch(matchesProvider.future);
  return matches.where((m) => m.groupName == group).toList();
});

final matchesByRoundProvider = FutureProvider.family<List<AppMatch>, String>((ref, round) async {
  final matches = await ref.watch(matchesProvider.future);
  return matches.where((m) => m.round == round).toList();
});
