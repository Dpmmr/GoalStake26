import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match.dart';
import '../services/thesportsdb_service.dart';
import '../services/settlement_service.dart';
import '../../core/constants.dart';

class LiveScorePoller {
  final SupabaseClient _client = Supabase.instance.client;
  final SettlementService _settlementService = SettlementService();
  Timer? _pollTimer;
  bool _isPolling = false;

  void startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    _pollTimer = Timer.periodic(AppConstants.syncIntervalLive, (_) => _pollLiveMatches());
    _pollLiveMatches();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
  }

  Future<void> _pollLiveMatches() async {
    try {
      final response = await _client
          .from('matches')
          .select()
          .inFilter('status', ['live', '1H', '2H', 'HT', 'ET', 'Pens'])
          .eq('is_settled', false);

      final liveMatches = (response as List).map((m) => AppMatch.fromJson(m)).toList();

      for (final match in liveMatches) {
        if (match.thesportsdbEventId != null) {
          await _updateMatchScore(match);
        }
      }

      await _settlementService.settleAllFinishedMatches();
    } catch (e) {
      // Error polling live matches
    }
  }

  Future<void> _updateMatchScore(AppMatch match) async {
    try {
      final eventData = await TheSportsDBService.getEventById(match.thesportsdbEventId!);
      if (eventData == null) return;

      final events = eventData['events'];
      if (events == null || events.isEmpty) return;

      final event = events[0];
      final homeScore = int.tryParse(event['intHomeScore']?.toString() ?? '');
      final awayScore = int.tryParse(event['intAwayScore']?.toString() ?? '');
      final status = event['strStatus'] ?? '';

      if (homeScore != null && awayScore != null) {
        final newStatus = _mapSportsDbStatus(status);

        await _client.from('matches').update({
          'home_score': homeScore,
          'away_score': awayScore,
          'status': newStatus,
          'is_live': _isLiveStatus(newStatus),
        }).eq('id', match.id);

        if (newStatus == 'finished' || newStatus == 'FT') {
          await _settlementService.settleMatchBets(match.id);
          await _createNotification(
            matchId: match.id,
            title: 'Match Finished',
            message: '${match.homeTeam} $homeScore - $awayScore ${match.awayTeam}',
            type: 'match_finished',
          );
        }
      }
    } catch (e) {
      // Error updating match score
    }
  }

  String _mapSportsDbStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ft':
      case 'finished':
        return 'finished';
      case '1h':
      case '1st half':
        return '1H';
      case 'ht':
      case 'half time':
        return 'HT';
      case '2h':
      case '2nd half':
        return '2H';
      case 'et':
      case 'extra time':
        return 'ET';
      case 'pens':
      case 'penalties':
        return 'Pens';
      case 'ns':
      case 'not started':
        return 'upcoming';
      case 'pst':
      case 'postponed':
        return 'postponed';
      default:
        return status;
    }
  }

  bool _isLiveStatus(String status) {
    return ['1H', 'HT', '2H', 'ET', 'Pens'].contains(status);
  }

  Future<void> syncAllFixtures() async {
    try {
      final fixturesData = await TheSportsDBService.getWorldCupFixtures();
      if (fixturesData == null) return;

      final fixtures = TheSportsDBService.parseFixtures(fixturesData);

      for (final fixture in fixtures) {
        await _client.from('matches').upsert({
          'thesportsdb_event_id': fixture['id'],
          'home_team': fixture['homeTeam'],
          'away_team': fixture['awayTeam'],
          'home_team_badge': fixture['homeBadge'],
          'away_team_badge': fixture['awayBadge'],
          'home_score': fixture['homeScore'],
          'away_score': fixture['awayScore'],
          'status': _mapSportsDbStatus(fixture['status'] ?? ''),
          'venue': fixture['venue'],
        }, onConflict: 'thesportsdb_event_id');
      }
    } catch (e) {
      // Error syncing fixtures
    }
  }

  Future<void> _createNotification({
    required String matchId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final betsResponse = await _client
          .from('bets')
          .select('user_id')
          .eq('match_id', matchId)
          .eq('status', 'active');

      final userIds = (betsResponse as List).map((b) => b['user_id'] as String).toSet();

      for (final userId in userIds) {
        await _client.from('notifications').insert({
          'user_id': userId,
          'title': title,
          'message': message,
          'type': type,
          'data': {'match_id': matchId},
        });
      }
    } catch (e) {
      // Error creating notifications
    }
  }
}

final liveScorePollerProvider = Provider<LiveScorePoller>((ref) {
  return LiveScorePoller();
});
