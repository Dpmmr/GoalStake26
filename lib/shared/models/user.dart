class AppUser {
  final String id;
  final String bettorId;
  final String fullName;
  final String phone;
  final String? email;
  final bool isAdmin;
  final bool isActive;
  final int totalBets;
  final double totalStaked;
  final double totalWon;
  final int wins;
  final int losses;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.bettorId,
    required this.fullName,
    required this.phone,
    this.email,
    this.isAdmin = false,
    this.isActive = true,
    this.totalBets = 0,
    this.totalStaked = 0,
    this.totalWon = 0,
    this.wins = 0,
    this.losses = 0,
    required this.createdAt,
  });

  double get winRate => totalBets > 0 ? (wins / totalBets) * 100 : 0;
  int get netProfit => totalWon.toInt() - totalStaked.toInt();

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      bettorId: json['bettor_id'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      isAdmin: json['is_admin'] ?? false,
      isActive: json['is_active'] ?? true,
      totalBets: json['total_bets'] ?? 0,
      totalStaked: (json['total_staked'] ?? 0).toDouble(),
      totalWon: (json['total_won'] ?? 0).toDouble(),
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bettor_id': bettorId,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'is_admin': isAdmin,
      'is_active': isActive,
      'total_bets': totalBets,
      'total_staked': totalStaked,
      'total_won': totalWon,
      'wins': wins,
      'losses': losses,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
