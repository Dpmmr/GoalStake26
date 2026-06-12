class Bet {
  final String id;
  final String userId;
  final String matchId;
  final String bettorId;
  final String fullName;
  final String phone;
  final String matchTitle;
  final String teamPicked;
  final double amount;
  final double odds;
  final double potentialPayout;
  final String status;
  final String? notes;
  final String? paymentScreenshotUrl;
  final DateTime createdAt;
  final DateTime? adminApprovedAt;
  final DateTime? settledAt;

  Bet({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.bettorId,
    required this.fullName,
    required this.phone,
    required this.matchTitle,
    required this.teamPicked,
    required this.amount,
    this.odds = 2.0,
    required this.potentialPayout,
    this.status = 'pending',
    this.notes,
    this.paymentScreenshotUrl,
    required this.createdAt,
    this.adminApprovedAt,
    this.settledAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isWon => status == 'won';
  bool get isLost => status == 'lost';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Approval';
      case 'approved':
        return 'Active';
      case 'rejected':
        return 'Rejected';
      case 'won':
        return 'Won';
      case 'lost':
        return 'Lost';
      default:
        return status.toUpperCase();
    }
  }

  factory Bet.fromJson(Map<String, dynamic> json) {
    return Bet(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      matchId: json['match_id'] ?? '',
      bettorId: json['bettor_id'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      matchTitle: json['match_title'] ?? '',
      teamPicked: json['team_picked'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      odds: (json['odds'] ?? 2.0).toDouble(),
      potentialPayout: (json['potential_payout'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      paymentScreenshotUrl: json['payment_screenshot_url'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      adminApprovedAt: json['admin_approved_at'] != null
          ? DateTime.parse(json['admin_approved_at'])
          : null,
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'match_id': matchId,
      'bettor_id': bettorId,
      'full_name': fullName,
      'phone': phone,
      'match_title': matchTitle,
      'team_picked': teamPicked,
      'amount': amount,
      'odds': odds,
      'potential_payout': potentialPayout,
      'status': status,
      'notes': notes,
      'payment_screenshot_url': paymentScreenshotUrl,
      'created_at': createdAt.toIso8601String(),
      'admin_approved_at': adminApprovedAt?.toIso8601String(),
      'settled_at': settledAt?.toIso8601String(),
    };
  }
}
