import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match.dart';
import '../models/bet.dart';

class SettlementService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> settleMatchBets(String matchId) async {
    final matchResponse = await _client
        .from('matches')
        .select()
        .eq('id', matchId)
        .single();

    final match = AppMatch.fromJson(matchResponse);

    if (match.homeScore == null || match.awayScore == null) return;

    final betsResponse = await _client
        .from('bets')
        .select()
        .eq('match_id', matchId)
        .eq('status', 'active');

    final bets = (betsResponse as List).map((b) => Bet.fromJson(b)).toList();

    final String? winner = _determineWinner(match);

    for (final bet in bets) {
      final bool isWinningBet = _isBetWinner(bet, winner);
      final String newStatus = isWinningBet ? 'won' : 'lost';
      final double payout = isWinningBet ? bet.potentialPayout : 0;

      await _client.from('bets').update({
        'status': newStatus,
        'settled_at': DateTime.now().toIso8601String(),
      }).eq('id', bet.id);

      if (isWinningBet) {
        await _client.rpc('increment_user_stats', params: {
          'p_user_id': bet.userId,
          'p_amount_won': payout,
          'p_is_win': true,
        });
      } else {
        await _client.rpc('increment_user_stats', params: {
          'p_user_id': bet.userId,
          'p_amount_won': 0,
          'p_is_win': false,
        });
      }
    }

    await _client.from('matches').update({
      'is_settled': true,
    }).eq('id', matchId);

    await _updatePlatformStats(bets, winner != null);
  }

  String? _determineWinner(AppMatch match) {
    if (match.homeScore == null || match.awayScore == null) return null;

    if (match.homeScore! > match.awayScore!) {
      return match.homeTeam;
    } else if (match.awayScore! > match.homeScore!) {
      return match.awayTeam;
    } else {
      return 'Draw';
    }
  }

  bool _isBetWinner(Bet bet, String? winner) {
    if (winner == null) return false;

    if (winner == 'Draw') {
      return bet.teamPicked.toLowerCase() == 'draw';
    }

    return bet.teamPicked == winner;
  }

  Future<void> _updatePlatformStats(List<Bet> bets, bool hasWinner) async {
    final totalStaked = bets.fold<double>(0, (sum, b) => sum + b.amount);
    final totalWon = bets
        .where((b) => b.status == 'won')
        .fold<double>(0, (sum, b) => sum + b.potentialPayout);

    await _client.rpc('update_platform_stat', params: {
      'p_key': 'total_amount_staked',
      'p_value': totalStaked,
    });

    if (hasWinner) {
      await _client.rpc('update_platform_stat', params: {
        'p_key': 'total_amount_won',
        'p_value': totalWon,
      });
    }
  }

  Future<void> settleAllFinishedMatches() async {
    final response = await _client
        .from('matches')
        .select()
        .eq('status', 'finished')
        .eq('is_settled', false);

    final matches = (response as List).map((m) => AppMatch.fromJson(m)).toList();

    for (final match in matches) {
      await settleMatchBets(match.id);
    }
  }

  Future<void> settleUserBet(String betId, String status) async {
    final betResponse = await _client
        .from('bets')
        .select()
        .eq('id', betId)
        .single();

    final bet = Bet.fromJson(betResponse);

    await _client.from('bets').update({
      'status': status,
      'settled_at': DateTime.now().toIso8601String(),
    }).eq('id', betId);

    if (status == 'won') {
      await _client.rpc('increment_user_stats', params: {
        'p_user_id': bet.userId,
        'p_amount_won': bet.potentialPayout,
        'p_is_win': true,
      });
    } else {
      await _client.rpc('increment_user_stats', params: {
        'p_user_id': bet.userId,
        'p_amount_won': 0,
        'p_is_win': false,
      });
    }
  }
}
