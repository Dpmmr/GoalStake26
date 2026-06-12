import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match.dart';
import 'thesportsdb_service.dart';
import '../providers/auth_provider.dart';
import '../utils/file_storage.dart';

class MatchSyncService {
  final Ref _ref;
  static const String _cacheFileName = 'matches_cache.json';
  final FileStorage _storage = FileStorage();

  MatchSyncService(this._ref);

  // Caching matches locally
  Future<void> _writeToCache(List<AppMatch> matches) async {
    try {
      final jsonList = matches.map((m) => m.toJson()).toList();
      await _storage.writeCache(_cacheFileName, json.encode(jsonList));
      debugPrint('Successfully cached ${matches.length} matches locally.');
    } catch (e) {
      debugPrint('Failed to write matches to local cache: $e');
    }
  }

  // Reading matches from local cache
  Future<List<AppMatch>> _readFromCache() async {
    try {
      final content = await _storage.readCache(_cacheFileName);
      if (content != null) {
        final jsonList = json.decode(content) as List;
        final cachedMatches = jsonList.map((m) => AppMatch.fromJson(m)).toList();
        debugPrint('Loaded ${cachedMatches.length} matches from local cache.');
        return cachedMatches;
      }
    } catch (e) {
      debugPrint('Failed to read matches from local cache: $e');
    }
    return [];
  }

  // Sync matches: API -> Supabase -> Cache
  Future<List<AppMatch>> syncMatches() async {
    try {
      final supabase = _ref.read(supabaseServiceProvider);

      // 1. Try to sync from TheSportsDB to Supabase
      final fixturesData = await TheSportsDBService.getWorldCupFixtures();
      if (fixturesData != null) {
        final parsedFixtures = TheSportsDBService.parseFixtures(fixturesData);

        for (final fixture in parsedFixtures) {
          try {
            await supabase.client.from('matches').upsert({
              'thesportsdb_event_id': fixture['id'],
              'home_team': fixture['homeTeam'],
              'away_team': fixture['awayTeam'],
              'home_team_badge': fixture['homeBadge'],
              'away_team_badge': fixture['awayBadge'],
              'home_score': fixture['homeScore'],
              'away_score': fixture['awayScore'],
              'status': _mapSportsDbStatus(fixture['status'] ?? 'upcoming'),
              'venue': fixture['venue'],
              'city': fixture['city'] ?? fixture['country'] ?? 'TBD',
              'match_date': DateTime.parse(fixture['date'] ?? DateTime.now().toIso8601String()).toIso8601String(),
              'match_time_ist': TheSportsDBService.convertUtcToIst(fixture['time'] ?? '12:00:00'),
              'round': fixture['round']?.toString() ?? 'Group Stage',
            }, onConflict: 'thesportsdb_event_id');
          } catch (upsertError) {
            debugPrint('Error upserting match ${fixture['id']}: $upsertError');
          }
        }
      }

      // 2. Fetch all matches from Supabase
      final fetchedMatches = await supabase.getMatches();
      if (fetchedMatches.isNotEmpty) {
        // Cache them locally
        await _writeToCache(fetchedMatches);
        return fetchedMatches;
      }
    } catch (e) {
      debugPrint('Network/Supabase sync error: $e');
    }

    // 3. If API/Supabase failed, fallback to local file cache
    final cachedMatches = await _readFromCache();
    if (cachedMatches.isNotEmpty) {
      return cachedMatches;
    }

    // 4. Failsafe fallback: Load default pre-populated World Cup 2026 matches
    final defaultMatches = _getDefaultWorldCupMatches();
    await _writeToCache(defaultMatches);
    
    // Seed them to Supabase in the background if possible
    _seedDefaultMatchesToSupabaseInBackground(defaultMatches);

    return defaultMatches;
  }

  void _seedDefaultMatchesToSupabaseInBackground(List<AppMatch> defaultMatches) async {
    try {
      final supabase = _ref.read(supabaseServiceProvider);
      for (final match in defaultMatches) {
        await supabase.client.from('matches').upsert(match.toJson(), onConflict: 'thesportsdb_event_id');
      }
      debugPrint('Seeded default matches to Supabase in background.');
    } catch (e) {
      debugPrint('Failed background seed to Supabase: $e');
    }
  }

  String _mapSportsDbStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ft':
      case 'finished':
      case 'completed':
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
        return 'upcoming';
    }
  }

  List<AppMatch> _getDefaultWorldCupMatches() {
    final baseDate = DateTime(2026, 6, 11);
    
    final matchesData = [
      {
        'id': 'def-match-1',
        'match_number': 1,
        'thesportsdb_event_id': '2391728',
        'home_team': 'Mexico',
        'away_team': 'South Africa',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/3rmosi1748525208.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/xjz9j91553368824.png',
        'group_name': 'A',
        'round': 'Group Stage',
        'venue': 'Estadio Azteca',
        'city': 'Mexico City',
        'match_date': baseDate.toIso8601String(),
        'match_time_ist': '00:30 IST',
        'status': 'finished',
        'home_score': 2,
        'away_score': 0,
      },
      {
        'id': 'def-match-2',
        'match_number': 2,
        'thesportsdb_event_id': '2461103',
        'home_team': 'South Korea',
        'away_team': 'Czech Republic',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/a8nqfs1589564916.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/1o0cx31654205806.png',
        'group_name': 'A',
        'round': 'Group Stage',
        'venue': 'Estadio Akron',
        'city': 'Guadalajara',
        'match_date': baseDate.add(const Duration(days: 1)).toIso8601String(),
        'match_time_ist': '07:30 IST',
        'status': 'finished',
        'home_score': 2,
        'away_score': 1,
      },
      {
        'id': 'def-match-3',
        'match_number': 3,
        'thesportsdb_event_id': '2461104',
        'home_team': 'Canada',
        'away_team': 'Bosnia-Herzegovina',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/2t631f1595154867.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/wtqqst1455463120.png',
        'group_name': 'B',
        'round': 'Group Stage',
        'venue': 'BMO Field',
        'city': 'Toronto',
        'match_date': baseDate.add(const Duration(days: 1)).toIso8601String(),
        'match_time_ist': '19:00 IST',
        'status': 'live',
        'home_score': 1,
        'away_score': 1,
      },
      {
        'id': 'def-match-4',
        'match_number': 4,
        'thesportsdb_event_id': '2391729',
        'home_team': 'USA',
        'away_team': 'Paraguay',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/21f0oi1597948195.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/khgav41553419195.png',
        'group_name': 'C',
        'round': 'Group Stage',
        'venue': 'SoFi Stadium',
        'city': 'Los Angeles',
        'match_date': baseDate.add(const Duration(days: 2)).toIso8601String(),
        'match_time_ist': '01:00 IST',
        'status': 'upcoming',
      },
      {
        'id': 'def-match-5',
        'match_number': 5,
        'thesportsdb_event_id': '2391730',
        'home_team': 'Brazil',
        'away_team': 'Morocco',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/jl6dip1726167280.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/hbmwkj1731791275.png',
        'group_name': 'D',
        'round': 'Group Stage',
        'venue': 'MetLife Stadium',
        'city': 'New York',
        'match_date': baseDate.add(const Duration(days: 2)).toIso8601String(),
        'match_time_ist': '22:00 IST',
        'status': 'upcoming',
      },
      {
        'id': 'def-match-6',
        'match_number': 6,
        'thesportsdb_event_id': '2391732',
        'home_team': 'Qatar',
        'away_team': 'Switzerland',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/rs3ir31642708685.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/mb7yqe1717365808.png',
        'group_name': 'E',
        'round': 'Group Stage',
        'venue': 'Levi\'s Stadium',
        'city': 'Santa Clara',
        'match_date': baseDate.add(const Duration(days: 2)).toIso8601String(),
        'match_time_ist': '19:00 IST',
        'status': 'upcoming',
      },
      {
        'id': 'def-match-7',
        'match_number': 7,
        'thesportsdb_event_id': '2391731',
        'home_team': 'Haiti',
        'away_team': 'Scotland',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/gml8wx1598135302.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/3691i11552945146.png',
        'group_name': 'F',
        'round': 'Group Stage',
        'venue': 'Gillette Stadium',
        'city': 'Boston',
        'match_date': baseDate.add(const Duration(days: 3)).toIso8601String(),
        'match_time_ist': '01:00 IST',
        'status': 'upcoming',
      },
      {
        'id': 'def-match-8',
        'match_number': 8,
        'thesportsdb_event_id': '2391733',
        'home_team': 'Germany',
        'away_team': 'Curaçao',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/1xysi51726167152.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/itygvb1600955363.png',
        'group_name': 'G',
        'round': 'Group Stage',
        'venue': 'Reliant Stadium',
        'city': 'Houston',
        'match_date': baseDate.add(const Duration(days: 3)).toIso8601String(),
        'match_time_ist': '17:00 IST',
        'status': 'upcoming',
      },
      {
        'id': 'def-match-9',
        'match_number': 9,
        'thesportsdb_event_id': '2391734',
        'home_team': 'Ivory Coast',
        'away_team': 'Ecuador',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/rwxuuu1455465643.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/47wv2y1591989301.png',
        'group_name': 'H',
        'round': 'Group Stage',
        'venue': 'Lincoln Financial Field',
        'city': 'Philadelphia',
        'match_date': baseDate.add(const Duration(days: 3)).toIso8601String(),
        'match_time_ist': '23:00 IST',
        'status': 'upcoming',
      },
      {
        'id': 'def-match-10',
        'match_number': 10,
        'thesportsdb_event_id': '2391735',
        'home_team': 'Netherlands',
        'away_team': 'Japan',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/1p0hr41593787110.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/ffsyxz1591989843.png',
        'group_name': 'I',
        'round': 'Group Stage',
        'venue': 'AT&T Stadium',
        'city': 'Dallas',
        'match_date': baseDate.add(const Duration(days: 3)).toIso8601String(),
        'match_time_ist': '20:00 IST',
        'status': 'upcoming',
      },
      {
        'id': 'def-match-11',
        'match_number': 80,
        'thesportsdb_event_id': '2391760',
        'home_team': 'Argentina',
        'away_team': 'France',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/vpxxru1455467005.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/wuxuyt1455468504.png',
        'round': 'Quarter-finals',
        'venue': 'Gillette Stadium',
        'city': 'Boston',
        'match_date': baseDate.add(const Duration(days: 15)).toIso8601String(),
        'match_time_ist': '22:00 IST',
        'status': 'upcoming',
      },
      {
        'id': 'def-match-12',
        'match_number': 104,
        'thesportsdb_event_id': '2391790',
        'home_team': 'Brazil',
        'away_team': 'Spain',
        'home_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/jl6dip1726167280.png',
        'away_team_badge': 'https://r2.thesportsdb.com/images/media/team/badge/ncgqyr1726166942.png',
        'round': 'Final',
        'venue': 'MetLife Stadium',
        'city': 'New York',
        'match_date': baseDate.add(const Duration(days: 28)).toIso8601String(),
        'match_time_ist': '00:30 IST',
        'status': 'upcoming',
      }
    ];

    return matchesData.map((data) => AppMatch.fromJson(data)).toList();
  }
}

final matchSyncServiceProvider = Provider<MatchSyncService>((ref) {
  return MatchSyncService(ref);
});
