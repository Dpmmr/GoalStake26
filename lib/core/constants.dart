class AppConstants {
  AppConstants._();

  static const String appName = 'GOALSTAKE 26';
  static const String appTagline = 'Predict. Stake. Win.';
  static const String fifaWorldCup = 'FIFA World Cup 2026';

  static const double minBet = 100;
  static const double maxBet = 700;
  static const double lastDanceMinBet = 300;
  static const double lastDanceMaxBet = 1000;
  static const int lastDanceMaxParticipants = 20;

  static const double defaultCommissionRate = 5.0;
  static const double defaultOdds = 2.00;

  static const int totalMatches = 104;
  static const String tournamentSeason = '2026';
  static const int thesportsdbLeagueId = 4429;

  static const String adminPassword = '923300';
  static const int adminTapCount = 5;

  static const String supabaseUrl = 'https://xprrksnzajajthxqcxlf.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwcnJrc256YWphanRoeHFjeGxmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyMzU1NzUsImV4cCI6MjA5NjgxMTU3NX0.EYoghbroU_QUp4WB4zxjST-FATMKptKy-X60s-8a1PE';

  static const String adminWhatsApp = '918787665349';
  static const String userWhatsApp = '918787665349';
  static const String upiId = 'goalstake26@upi';

  static const String nvidiaApiKey = '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';
  static const String nemotronModel = 'nvidia/nemotron-3-ultra';

  static const Duration syncIntervalLive = Duration(seconds: 30);
  static const Duration syncIntervalIdle = Duration(minutes: 15);

  static const List<String> groups = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'
  ];

  static const List<String> knockoutRounds = [
    'Round of 32',
    'Round of 16',
    'Quarter-finals',
    'Semi-finals',
    'Third-place Match',
    'Final',
  ];
}
