import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

class TheSportsDBService {
  static const String _baseUrl = 'https://www.thesportsdb.com/api/v1/json/123';

  static Future<Map<String, dynamic>?> _getWithRetry(String url, {int retries = 3}) async {
    int attempt = 0;
    while (attempt < retries) {
      attempt++;
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          return json.decode(response.body);
        }
        debugPrint('API request failed with status code ${response.statusCode}: $url');
      } catch (e) {
        debugPrint('API request attempt $attempt failed for $url: $e');
        if (attempt >= retries) {
          return null;
        }
        await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getWorldCupFixtures() async {
    try {
      return await _getWithRetry(
        '$_baseUrl/eventsseason.php?id=${AppConstants.thesportsdbLeagueId}&s=${AppConstants.tournamentSeason}',
      );
    } catch (e) {
      debugPrint('Error fetching fixtures: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getEventById(String eventId) async {
    try {
      return await _getWithRetry('$_baseUrl/lookupevent.php?id=$eventId');
    } catch (e) {
      debugPrint('Error fetching event: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getTeamById(String teamId) async {
    try {
      return await _getWithRetry('$_baseUrl/lookupteam.php?id=$teamId');
    } catch (e) {
      debugPrint('Error fetching team: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> searchTeam(String teamName) async {
    try {
      return await _getWithRetry('$_baseUrl/searchteams.php?t=$teamName');
    } catch (e) {
      debugPrint('Error searching team: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getEventLineup(String eventId) async {
    try {
      return await _getWithRetry('$_baseUrl/lookuplineup.php?id=$eventId');
    } catch (e) {
      debugPrint('Error fetching lineup: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getEventTimeline(String eventId) async {
    try {
      return await _getWithRetry('$_baseUrl/lookuptimeline.php?id=$eventId');
    } catch (e) {
      debugPrint('Error fetching timeline: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getEventsByDate(String date) async {
    try {
      return await _getWithRetry('$_baseUrl/eventsday.php?d=$date&s=Soccer');
    } catch (e) {
      debugPrint('Error fetching events by date: $e');
      return null;
    }
  }

  static List<Map<String, dynamic>> parseFixtures(Map<String, dynamic> data) {
    final events = data['events'];
    if (events == null) return [];

    return List<Map<String, dynamic>>.from(events).map((event) {
      return {
        'id': event['idEvent'],
        'homeTeam': event['strHomeTeam'],
        'awayTeam': event['strAwayTeam'],
        'homeScore': event['intHomeScore'],
        'awayScore': event['intAwayScore'],
        'status': event['strStatus'],
        'date': event['dateEvent'],
        'time': event['strTime'],
        'venue': event['strVenue'],
        'country': event['strCountry'],
        'round': event['intRound'],
        'homeBadge': event['strHomeTeamBadge'],
        'awayBadge': event['strAwayTeamBadge'],
        'thumb': event['strThumb'],
        'poster': event['strPoster'],
        'homeTeamId': event['idHomeTeam'],
        'awayTeamId': event['idAwayTeam'],
      };
    }).toList();
  }

  static String convertUtcToIst(String utcTime) {
    try {
      final parts = utcTime.split(':');
      if (parts.length < 2) return utcTime;

      int hours = int.parse(parts[0]);
      int minutes = int.parse(parts[1]);

      hours += 5;
      minutes += 30;

      if (minutes >= 60) {
        hours += 1;
        minutes -= 60;
      }

      if (hours >= 24) {
        hours -= 24;
      }

      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} IST';
    } catch (e) {
      return utcTime;
    }
  }

  static String formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return dateStr;

      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = int.parse(parts[2]);
      final month = months[int.parse(parts[1])];

      return '$day $month ${parts[0]}';
    } catch (e) {
      return dateStr;
    }
  }
}
