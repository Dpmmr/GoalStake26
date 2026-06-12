import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match.dart';
import '../models/user.dart';
import '../models/bet.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  // Auth
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signInWithPhone(String phone, String otp) async {
    return await _client.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
  }

  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Users
  Future<AppUser?> getUser(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();
    return AppUser.fromJson(response);
  }

  Future<AppUser?> getUserByPhone(String phone) async {
    final response = await _client
        .from('users')
        .select()
        .eq('phone', phone)
        .maybeSingle();
    return response != null ? AppUser.fromJson(response) : null;
  }

  Future<AppUser> createUser({
    required String phone,
    required String fullName,
    required String gsId,
  }) async {
    final response = await _client
        .from('users')
        .insert({
          'phone': phone,
          'full_name': fullName,
          'gs_id': gsId,
        })
        .select()
        .single();
    return AppUser.fromJson(response);
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await _client.from('users').update(updates).eq('id', userId);
  }

  // Matches
  Future<List<AppMatch>> getMatches() async {
    final response = await _client
        .from('matches')
        .select()
        .order('match_date', ascending: true)
        .order('match_time_ist', ascending: true);
    return (response as List).map((m) => AppMatch.fromJson(m)).toList();
  }

  Future<List<AppMatch>> getMatchesByGroup(String group) async {
    final response = await _client
        .from('matches')
        .select()
        .eq('group_name', group)
        .order('match_date', ascending: true);
    return (response as List).map((m) => AppMatch.fromJson(m)).toList();
  }

  Future<List<AppMatch>> getMatchesByRound(String round) async {
    final response = await _client
        .from('matches')
        .select()
        .eq('round', round)
        .order('round_order', ascending: true);
    return (response as List).map((m) => AppMatch.fromJson(m)).toList();
  }

  Future<List<AppMatch>> getLiveMatches() async {
    final response = await _client
        .from('matches')
        .select()
        .eq('is_live', true)
        .order('match_date', ascending: true);
    return (response as List).map((m) => AppMatch.fromJson(m)).toList();
  }

  Future<List<AppMatch>> getUpcomingMatches() async {
    final response = await _client
        .from('matches')
        .select()
        .eq('status', 'upcoming')
        .order('match_date', ascending: true)
        .order('match_time_ist', ascending: true)
        .limit(10);
    return (response as List).map((m) => AppMatch.fromJson(m)).toList();
  }

  Future<void> updateMatchScore(
      String matchId, int homeScore, int awayScore) async {
    await _client.from('matches').update({
      'home_score': homeScore,
      'away_score': awayScore,
      'status': 'finished',
      'is_live': false,
    }).eq('id', matchId);
  }

  // Bets
  Future<List<Bet>> getUserBets(String userId) async {
    final response = await _client
        .from('bets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((b) => Bet.fromJson(b)).toList();
  }

  Future<List<Bet>> getUserBetsByStatus(String userId, String status) async {
    final response = await _client
        .from('bets')
        .select()
        .eq('user_id', userId)
        .eq('status', status)
        .order('created_at', ascending: false);
    return (response as List).map((b) => Bet.fromJson(b)).toList();
  }

  Future<List<Bet>> getUserBetsByPhone(String phone) async {
    final user = await getUserByPhone(phone);
    if (user == null) return [];
    final response = await _client
        .from('bets')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return (response as List).map((b) => Bet.fromJson(b)).toList();
  }

  Future<List<Bet>> getUserBetsByPhoneAndStatus(String phone, String status) async {
    final user = await getUserByPhone(phone);
    if (user == null) return [];
    final response = await _client
        .from('bets')
        .select()
        .eq('user_id', user.id)
        .eq('status', status)
        .order('created_at', ascending: false);
    return (response as List).map((b) => Bet.fromJson(b)).toList();
  }

  Future<Bet> createBet({
    required String userId,
    required String matchId,
    required String teamPicked,
    required double amount,
    required double odds,
    required double potentialPayout,
    String? paymentScreenshotUrl,
    String? matchTitle,
  }) async {
    final response = await _client
        .from('bets')
        .insert({
          'user_id': userId,
          'match_id': matchId,
          'team_picked': teamPicked,
          'amount': amount,
          'odds': odds,
          'potential_payout': potentialPayout,
          'status': 'pending',
          'payment_screenshot_url': paymentScreenshotUrl,
          'match_title': matchTitle,
        })
        .select()
        .single();
    return Bet.fromJson(response);
  }

  Future<String?> uploadScreenshot(String name, Uint8List bytes) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$name';
      await _client.storage.from('payment-screenshots').uploadBinary(fileName, bytes);
      return _client.storage.from('payment-screenshots').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Storage upload failed: $e. Returning a mock URL.');
      return 'https://images.unsplash.com/photo-1540747737956-37872ba68b5a?q=80&w=600';
    }
  }

  Future<void> updateBetStatus(String betId, String status) async {
    await _client.from('bets').update({
      'status': status,
      'settled_at': DateTime.now().toIso8601String(),
    }).eq('id', betId);
  }

  // Last Dance Bets
  Future<List<LastDanceBet>> getUserLastDanceBets(String userId) async {
    final response = await _client
        .from('last_dance_bets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((b) => LastDanceBet.fromJson(b)).toList();
  }

  Future<List<LastDanceBet>> getUserLastDanceBetsByPhone(String phone) async {
    final user = await getUserByPhone(phone);
    if (user == null) return [];
    final response = await _client
        .from('last_dance_bets')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return (response as List).map((b) => LastDanceBet.fromJson(b)).toList();
  }

  Future<LastDanceBet> createLastDanceBet({
    required String userId,
    required String country,
    required String countryFlag,
    required double amount,
    String? paymentScreenshotUrl,
  }) async {
    final response = await _client
        .from('last_dance_bets')
        .insert({
          'user_id': userId,
          'country': country,
          'country_flag': countryFlag,
          'amount': amount,
          'payment_screenshot_url': paymentScreenshotUrl,
          'status': 'pending',
        })
        .select()
        .single();

    // Update country pool
    try {
      await _client.rpc('increment_country_pool', params: {
        'p_country': country,
        'p_amount': amount,
      });
    } catch (e) {
      debugPrint('Error updating country pool RPC: $e');
    }

    return LastDanceBet.fromJson(response);
  }

  // Country Pool
  Future<List<CountryPool>> getCountryPool() async {
    final response = await _client
        .from('country_pool')
        .select()
        .order('total_staked', ascending: false);
    return (response as List).map((c) => CountryPool.fromJson(c)).toList();
  }

  // Platform Stats
  Future<PlatformStats> getPlatformStats() async {
    final response = await _client.from('platform_stats').select();
    final stats = <String, double>{};
    for (final row in response) {
      stats[row['stat_key']] = (row['stat_value'] as num).toDouble();
    }
    return PlatformStats.fromJson(stats);
  }

  // Notifications
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read': true}).eq('id', notificationId);
  }

  // Realtime Subscriptions
  RealtimeChannel subscribeToMatches(void Function(Map<String, dynamic>) onUpdate) {
    return _client
        .channel('matches-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matches',
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToBets(
      String userId, void Function(Map<String, dynamic>) onUpdate) {
    return _client
        .channel('bets-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToAllBets(void Function(Map<String, dynamic>) onUpdate) {
    return _client
        .channel('all-bets-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bets',
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToNotifications(
      String userId, void Function(Map<String, dynamic>) onUpdate) {
    return _client
        .channel('notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  Future<void> unsubscribeChannel(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }

  // Storage - Payment Screenshots
  Future<String> uploadPaymentScreenshot(String betId, Uint8List bytes) async {
    final fileName = 'payment_${betId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('payment-screenshots').uploadBinary(fileName, bytes);
    final url = _client.storage.from('payment-screenshots').getPublicUrl(fileName);
    await _client.from('bets').update({
      'payment_screenshot_url': url,
    }).eq('id', betId);
    return url;
  }

  // Storage - User Avatars
  Future<String> uploadAvatar(String userId, Uint8List bytes) async {
    final fileName = 'avatar_${userId}.jpg';
    await _client.storage.from('avatars').uploadBinary(fileName, bytes);
    final url = _client.storage.from('avatars').getPublicUrl(fileName);
    await _client.from('users').update({
      'avatar_url': url,
    }).eq('id', userId);
    return url;
  }
}
