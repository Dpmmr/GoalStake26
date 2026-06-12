class LastDanceBet {
  final String id;
  final String userId;
  final String country;
  final String? countryFlag;
  final double amount;
  final String status;
  final bool won;
  final String? paymentScreenshotUrl;
  final DateTime createdAt;

  LastDanceBet({
    required this.id,
    required this.userId,
    required this.country,
    this.countryFlag,
    required this.amount,
    this.status = 'pending',
    this.won = false,
    this.paymentScreenshotUrl,
    required this.createdAt,
  });

  factory LastDanceBet.fromJson(Map<String, dynamic> json) {
    return LastDanceBet(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      country: json['country'] ?? '',
      countryFlag: json['country_flag'],
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      won: json['won'] ?? false,
      paymentScreenshotUrl: json['payment_screenshot_url'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'country': country,
      'country_flag': countryFlag,
      'amount': amount,
      'status': status,
      'won': won,
      'payment_screenshot_url': paymentScreenshotUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class CountryPool {
  final String id;
  final String country;
  final String? countryFlag;
  final int participants;
  final double totalStaked;
  final bool isWinner;

  CountryPool({
    required this.id,
    required this.country,
    this.countryFlag,
    this.participants = 0,
    this.totalStaked = 0,
    this.isWinner = false,
  });

  factory CountryPool.fromJson(Map<String, dynamic> json) {
    return CountryPool(
      id: json['id'] ?? '',
      country: json['country'] ?? '',
      countryFlag: json['country_flag'],
      participants: json['participants'] ?? 0,
      totalStaked: (json['total_staked'] ?? 0).toDouble(),
      isWinner: json['is_winner'] ?? false,
    );
  }

  bool get isFull => participants >= 20;
  int get remainingSlots => 20 - participants;
  double get fillPercentage => (participants / 20) * 100;
}

class PlatformStats {
  final double totalUsers;
  final double totalBets;
  final double totalMatches;
  final double totalAmountStaked;
  final double totalAmountWon;

  PlatformStats({
    this.totalUsers = 0,
    this.totalBets = 0,
    this.totalMatches = 104,
    this.totalAmountStaked = 0,
    this.totalAmountWon = 0,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> json) {
    return PlatformStats(
      totalUsers: (json['total_users'] ?? 0).toDouble(),
      totalBets: (json['total_bets'] ?? 0).toDouble(),
      totalMatches: (json['total_matches'] ?? 104).toDouble(),
      totalAmountStaked: (json['total_amount_staked'] ?? 0).toDouble(),
      totalAmountWon: (json['total_amount_won'] ?? 0).toDouble(),
    );
  }
}
