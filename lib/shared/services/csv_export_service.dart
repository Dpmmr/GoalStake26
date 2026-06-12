import 'package:csv/csv.dart';
import '../services/supabase_service.dart';
import '../utils/file_storage.dart';

class CsvExportService {
  final SupabaseService _supabase = SupabaseService();

  Future<void> exportBetsCsv() async {
    final bets = await _supabase.client
        .from('bets')
        .select('*, users(full_name, phone, gs_id)')
        .order('created_at', ascending: false);

    final rows = <List<dynamic>>[
      ['Bet ID', 'User', 'Phone', 'GS ID', 'Match', 'Team', 'Amount', 'Odds', 'Payout', 'Status', 'Date'],
    ];

    for (final bet in bets) {
      rows.add([
        bet['id']?.toString().substring(0, 8) ?? '',
        bet['users']?['full_name'] ?? '',
        bet['users']?['phone'] ?? '',
        bet['users']?['gs_id'] ?? '',
        bet['match_title'] ?? '',
        bet['team_picked'] ?? '',
        bet['amount'] ?? 0,
        bet['odds'] ?? 2.0,
        bet['potential_payout'] ?? 0,
        bet['status'] ?? '',
        bet['created_at'] ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    await _shareCsv(csv, 'goalstake_bets');
  }

  Future<void> exportUsersCsv() async {
    final users = await _supabase.client
        .from('users')
        .select()
        .order('created_at', ascending: false);

    final rows = <List<dynamic>>[
      ['User ID', 'Name', 'Phone', 'GS ID', 'Total Bets', 'Wins', 'Losses', 'Total Staked', 'Total Won', 'Joined'],
    ];

    for (final user in users) {
      rows.add([
        user['id']?.toString().substring(0, 8) ?? '',
        user['full_name'] ?? '',
        user['phone'] ?? '',
        user['gs_id'] ?? '',
        user['total_bets'] ?? 0,
        user['wins'] ?? 0,
        user['losses'] ?? 0,
        user['total_staked'] ?? 0,
        user['total_won'] ?? 0,
        user['created_at'] ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    await _shareCsv(csv, 'goalstake_users');
  }

  Future<void> exportLastDanceCsv() async {
    final bets = await _supabase.client
        .from('last_dance_bets')
        .select('*, users(full_name, phone, gs_id)')
        .order('created_at', ascending: false);

    final rows = <List<dynamic>>[
      ['Bet ID', 'User', 'Phone', 'GS ID', 'Country', 'Amount', 'Status', 'Won', 'Date'],
    ];

    for (final bet in bets) {
      rows.add([
        bet['id']?.toString().substring(0, 8) ?? '',
        bet['users']?['full_name'] ?? '',
        bet['users']?['phone'] ?? '',
        bet['users']?['gs_id'] ?? '',
        bet['country'] ?? '',
        bet['amount'] ?? 0,
        bet['status'] ?? '',
        bet['won'] ?? false,
        bet['created_at'] ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    await _shareCsv(csv, 'goalstake_last_dance');
  }

  Future<void> _shareCsv(String csv, String fileName) async {
    await FileStorage().saveAndShareCsv(csv, fileName);
  }
}
