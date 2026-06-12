class AppMatch {
  final String id;
  final int matchNumber;
  final String? thesportsdbEventId;
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamBadge;
  final String? awayTeamBadge;
  final String? groupName;
  final String round;
  final String? venue;
  final String? city;
  final DateTime matchDate;
  final String matchTimeIst;
  final String status;
  final int? homeScore;
  final int? awayScore;
  final double totalStaked;
  final int totalBets;
  final int homeBets;
  final int awayBets;
  final double homePercentage;
  final double awayPercentage;
  final bool isSettled;

  AppMatch({
    required this.id,
    required this.matchNumber,
    this.thesportsdbEventId,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamBadge,
    this.awayTeamBadge,
    this.groupName,
    required this.round,
    this.venue,
    this.city,
    required this.matchDate,
    required this.matchTimeIst,
    this.status = 'upcoming',
    this.homeScore,
    this.awayScore,
    this.totalStaked = 0,
    this.totalBets = 0,
    this.homeBets = 0,
    this.awayBets = 0,
    this.homePercentage = 50,
    this.awayPercentage = 50,
    this.isSettled = false,
  });

  bool get isLive => status == 'live' || status == '1H' || status == '2H' || status == 'HT';
  bool get isCompleted => status == 'completed' || status == 'FT';
  bool get isUpcoming => status == 'upcoming' || status == 'NS';

  String get statusDisplay {
    switch (status) {
      case 'FT':
        return 'Full Time';
      case '1H':
        return '1st Half';
      case 'HT':
        return 'Half Time';
      case '2H':
        return '2nd Half';
      case 'ET':
        return 'Extra Time';
      case 'Pens':
        return 'Penalties';
      case 'PST':
        return 'Postponed';
      case 'NS':
        return 'Not Started';
      default:
        return status.toUpperCase();
    }
  }

  String get scoreDisplay {
    if (homeScore == null || awayScore == null) return 'vs';
    return '$homeScore - $awayScore';
  }

  factory AppMatch.fromJson(Map<String, dynamic> json) {
    return AppMatch(
      id: json['id'] ?? '',
      matchNumber: json['match_number'] ?? 0,
      thesportsdbEventId: json['thesportsdb_event_id'],
      homeTeam: json['home_team'] ?? '',
      awayTeam: json['away_team'] ?? '',
      homeTeamBadge: json['home_team_badge'],
      awayTeamBadge: json['away_team_badge'],
      groupName: json['group_name'],
      round: json['round'] ?? 'Group Stage',
      venue: json['venue'],
      city: json['city'],
      matchDate: DateTime.parse(json['match_date'] ?? DateTime.now().toIso8601String()),
      matchTimeIst: json['match_time_ist'] ?? '',
      status: json['status'] ?? 'upcoming',
      homeScore: json['home_score'],
      awayScore: json['away_score'],
      totalStaked: (json['total_staked'] ?? 0).toDouble(),
      totalBets: json['total_bets'] ?? 0,
      homeBets: json['home_bets'] ?? 0,
      awayBets: json['away_bets'] ?? 0,
      homePercentage: (json['home_percentage'] ?? 50).toDouble(),
      awayPercentage: (json['away_percentage'] ?? 50).toDouble(),
      isSettled: json['is_settled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'match_number': matchNumber,
      'thesportsdb_event_id': thesportsdbEventId,
      'home_team': homeTeam,
      'away_team': awayTeam,
      'home_team_badge': homeTeamBadge,
      'away_team_badge': awayTeamBadge,
      'group_name': groupName,
      'round': round,
      'venue': venue,
      'city': city,
      'match_date': matchDate.toIso8601String(),
      'match_time_ist': matchTimeIst,
      'status': status,
      'home_score': homeScore,
      'away_score': awayScore,
      'total_staked': totalStaked,
      'total_bets': totalBets,
      'home_bets': homeBets,
      'away_bets': awayBets,
      'home_percentage': homePercentage,
      'away_percentage': awayPercentage,
      'is_settled': isSettled,
    };
  }
}
