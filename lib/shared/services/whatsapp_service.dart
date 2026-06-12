import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';

class WhatsAppService {
  static Future<void> sendBetRequest({
    required String fullName,
    required String phone,
    required String matchTitle,
    required String teamPicked,
    required double amount,
    required double odds,
    required double potentialPayout,
    required String betId,
    String? notes,
  }) async {
    final message = _buildAdminMessage(
      fullName: fullName,
      phone: phone,
      matchTitle: matchTitle,
      teamPicked: teamPicked,
      amount: amount,
      odds: odds,
      potentialPayout: potentialPayout,
      betId: betId,
      notes: notes,
    );

    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/${AppConstants.adminWhatsApp}?text=$encodedMessage';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> sendBetConfirmation({
    required String fullName,
    required String matchTitle,
    required String teamPicked,
    required double amount,
    required double potentialPayout,
    required String betId,
  }) async {
    final message = _buildUserConfirmationMessage(
      fullName: fullName,
      matchTitle: matchTitle,
      teamPicked: teamPicked,
      amount: amount,
      potentialPayout: potentialPayout,
      betId: betId,
    );

    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/${AppConstants.adminWhatsApp}?text=$encodedMessage';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  static String _buildAdminMessage({
    required String fullName,
    required String phone,
    required String matchTitle,
    required String teamPicked,
    required double amount,
    required double odds,
    required double potentialPayout,
    required String betId,
    String? notes,
  }) {
    return '''🟢 NEW BET REQUEST
─────────────────

👤 Name: $fullName
📱 Phone: $phone
⚽ Match: $matchTitle
📅 Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}
🏳 Team Backed: $teamPicked
💰 Amount: ₹${amount.toInt()}
📈 Odds: $odds
🎯 Potential Payout: ₹${potentialPayout.toInt()}
🆔 Bet ID: $betId

${notes != null && notes.isNotEmpty ? '📝 Notes: $notes\n' : ''}
─────────────────
Payment screenshot sent separately.

Please confirm or reject this bet.''';
  }

  static String _buildUserConfirmationMessage({
    required String fullName,
    required String matchTitle,
    required String teamPicked,
    required double amount,
    required double potentialPayout,
    required String betId,
  }) {
    return '''🟢 BET SUBMITTED — GoalStake 26
─────────────────

Your bet has been submitted for approval!

⚽ $matchTitle
🏳 Your pick: $teamPicked
💰 Staked: ₹${amount.toInt()}
🎯 Potential win: ₹${potentialPayout.toInt()}
🆔 Bet ID: $betId

─────────────────
Your bet becomes active only after admin approval.
Please send your payment screenshot to the admin.''';
  }

  static String generateBetId() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch}-${now.microsecond}';
  }
}
