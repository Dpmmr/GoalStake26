import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bet.dart';
import '../models/match.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final realtimeBetsProvider = StreamProvider<List<Bet>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<List<Bet>>();

  final channel = supabase
      .channel('live-bets-feed')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bets',
        callback: (payload) async {
          final response = await supabase
              .from('bets')
              .select()
              .order('created_at', ascending: false)
              .limit(20);
          final bets = (response as List).map((b) => Bet.fromJson(b)).toList();
          controller.add(bets);
        },
      )
      .subscribe();

  controller.onCancel = () {
    supabase.removeChannel(channel);
  };

  return controller.stream;
});

final realtimeMatchProvider = StreamProvider.family<AppMatch?, String>((ref, matchId) {
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<AppMatch?>();

  final channel = supabase
      .channel('match-$matchId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'matches',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: matchId,
        ),
        callback: (payload) {
          final match = AppMatch.fromJson(payload.newRecord);
          controller.add(match);
        },
      )
      .subscribe();

  controller.onCancel = () {
    supabase.removeChannel(channel);
  };

  return controller.stream;
});

final liveBetsFeedProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<List<Map<String, dynamic>>>();

  Future<void> fetchFeed() async {
    final response = await supabase
        .from('bets')
        .select('id, team_picked, amount, created_at, user_id')
        .order('created_at', ascending: false)
        .limit(10);
    controller.add(List<Map<String, dynamic>>.from(response));
  }

  fetchFeed();

  final channel = supabase
      .channel('live-feed')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'bets',
        callback: (payload) {
          fetchFeed();
        },
      )
      .subscribe();

  controller.onCancel = () {
    supabase.removeChannel(channel);
  };

  return controller.stream;
});
