import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/thesportsdb_service.dart';
import '../../core/constants.dart';

class NemotronService {
  static const String _baseUrl = 'https://integrate.api.nvidia.com/v1';
  static const String _apiKey = AppConstants.nvidiaApiKey;

  static Future<String> chat(String userMessage) async {
    try {
      final sportsContext = await _getSportsContext();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': AppConstants.nemotronModel,
          'messages': [
            {
              'role': 'system',
              'content': '''You are GoalStake AI, an expert FIFA World Cup 2026 analyst and betting advisor. 
You provide insights on matches, teams, players, and betting strategies.
You have access to live match data from TheSportsDB.
Always be helpful, analytical, and responsible. Remind users to bet responsibly.
Current tournament: FIFA World Cup 2026 USA/Canada/Mexico.
Betting rules: Min ₹100, Max ₹700, Default odds 2.0x, 5% commission.

Live Sports Data:
$sportsContext'''
            },
            {
              'role': 'user',
              'content': userMessage,
            }
          ],
          'temperature': 0.7,
          'top_p': 0.9,
          'max_tokens': 1024,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return 'Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Error connecting to AI: $e';
    }
  }

  static Stream<String> chatStream(String userMessage) async* {
    try {
      final sportsContext = await _getSportsContext();
      
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/chat/completions'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });
      request.body = json.encode({
        'model': AppConstants.nemotronModel,
        'messages': [
          {
            'role': 'system',
            'content': '''You are GoalStake AI, an expert FIFA World Cup 2026 analyst and betting advisor.
You provide insights on matches, teams, players, and betting strategies.
You have access to live match data from TheSportsDB.
Always be helpful, analytical, and responsible.

Live Sports Data:
$sportsContext'''
          },
          {
            'role': 'user',
            'content': userMessage,
          }
        ],
        'temperature': 0.7,
        'top_p': 0.9,
        'max_tokens': 1024,
        'stream': true,
      });

      final streamedResponse = await http.Client().send(request);
      
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            try {
              final data = json.decode(line.substring(6));
              final content = data['choices'][0]['delta']['content'];
              if (content != null) {
                yield content;
              }
            } catch (e) {
              // Skip malformed chunks
            }
          }
        }
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }

  static Future<String> _getSportsContext() async {
    try {
      final fixtures = await TheSportsDBService.getWorldCupFixtures();
      if (fixtures == null) return 'No live data available';
      
      final parsed = TheSportsDBService.parseFixtures(fixtures);
      final liveMatches = parsed.where((m) => 
        m['status'] == '1H' || m['status'] == '2H' || 
        m['status'] == 'HT' || m['status'] == 'FT'
      ).toList();
      
      final upcoming = parsed.where((m) => 
        m['status'] == 'NS' || m['status'] == 'upcoming'
      ).take(5).toList();

      final buffer = StringBuffer();
      
      if (liveMatches.isNotEmpty) {
        buffer.writeln('LIVE MATCHES:');
        for (final m in liveMatches) {
          buffer.writeln('${m['homeTeam']} ${m['homeScore'] ?? 0} - ${m['awayScore'] ?? 0} ${m['awayTeam']} (${m['status']})');
        }
      }
      
      if (upcoming.isNotEmpty) {
        buffer.writeln('\nUPCOMING MATCHES:');
        for (final m in upcoming) {
          buffer.writeln('${m['homeTeam']} vs ${m['awayTeam']} - ${m['date']} ${m['time']}');
        }
      }

      return buffer.toString();
    } catch (e) {
      return 'Error fetching sports data: $e';
    }
  }

  static Future<String> getMatchPrediction(String homeTeam, String awayTeam) async {
    return await chat('Predict the outcome of $homeTeam vs $awayTeam in FIFA World Cup 2026. Give score prediction, key players to watch, and betting recommendation. Consider current form and head-to-head records.');
  }

  static Future<String> getTeamAnalysis(String teamName) async {
    return await chat('Analyze $teamName\'s FIFA World Cup 2026 campaign. Include squad strength, form, key players, strengths, weaknesses, and tournament prospects.');
  }

  static Future<String> getBettingAdvice(String matchInfo) async {
    return await chat('Provide betting advice for: $matchInfo. Consider odds, form, head-to-head, and value bets. Remember: Min ₹100, Max ₹700, odds 2.0x. Bet responsibly.');
  }
}
