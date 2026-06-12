import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/models/match.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/whatsapp_service.dart';
import '../../shared/utils/file_storage.dart';

class PlaceBetScreen extends ConsumerStatefulWidget {
  final AppMatch match;

  const PlaceBetScreen({super.key, required this.match});

  @override
  ConsumerState<PlaceBetScreen> createState() => _PlaceBetScreenState();
}

class _PlaceBetScreenState extends ConsumerState<PlaceBetScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedTeam;
  bool _isSubmitting = false;
  bool _initializedUser = false;
  late TabController _tabController;
  PlatformFile? _screenshotFile;
  bool _acknowledgedPolicies = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCachedUserInfo();
  }

  void _loadCachedUserInfo() async {
    try {
      final phone = await FileStorage().readCache('user_phone');
      final name = await FileStorage().readCache('user_name');
      if (mounted) {
        if (phone != null && phone.isNotEmpty) {
          _phoneController.text = phone;
        }
        if (name != null && name.isNotEmpty) {
          _nameController.text = name;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  double get _stakeAmount => double.tryParse(_amountController.text) ?? 0;
  double get _winningShare => _stakeAmount;
  double get _platformCommission => _winningShare * 0.10;
  double get _potentialPayout => _winningShare - _platformCommission;

  void _submitBet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a team', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_screenshotFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload a payment screenshot', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!_acknowledgedPolicies) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please acknowledge the No Refund Policy', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = ref.read(supabaseServiceProvider);

      // 1. Upload screenshot
      final screenshotUrl = await supabase.uploadScreenshot(
        _screenshotFile!.name,
        _screenshotFile!.bytes ?? Uint8List(0),
      );

      // 2. Lookup or create user
      final phone = _phoneController.text.trim();
      final fullName = _nameController.text.trim();
      
      var dbUser = await supabase.getUserByPhone(phone);
      if (dbUser == null) {
        final gsId = 'GS${phone.substring(phone.length - (phone.length >= 6 ? 6 : phone.length))}';
        dbUser = await supabase.createUser(
          phone: phone,
          fullName: fullName,
          gsId: gsId,
        );
      }

      // Cache phone and name for next time
      await FileStorage().writeCache('user_phone', phone);
      await FileStorage().writeCache('user_name', fullName);

      // 3. Create bet
      final bet = await supabase.createBet(
        userId: dbUser.id,
        matchId: widget.match.id,
        teamPicked: _selectedTeam!,
        amount: _stakeAmount,
        odds: AppConstants.defaultOdds,
        potentialPayout: _potentialPayout,
        paymentScreenshotUrl: screenshotUrl,
        matchTitle: '${widget.match.homeTeam} vs ${widget.match.awayTeam}',
      );

      final message = _buildWhatsAppMessage(_stakeAmount, bet.id);
      
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showConfirmation(message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save prediction: ${e.toString()}', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _buildWhatsAppMessage(double amount, String betId) {
    final match = widget.match;
    final date = '${match.matchDate.day}/${match.matchDate.month}/${match.matchDate.year}';
    
    return '''🟢 *NEW PREDICTION REQUEST*
━━━━━━━━━━━━━━━

👤 *Name:* ${_nameController.text}
📱 *Phone:* ${_phoneController.text}

⚽ *Match:* ${match.homeTeam} vs ${match.awayTeam}
📅 *Date:* $date • ${match.matchTimeIst}
🏟️ *Venue:* ${match.venue ?? 'TBD'}

🎯 *Your Pick:* $_selectedTeam
💰 *Amount:* ₹${amount.toInt()}
📈 *Odds:* ${AppConstants.defaultOdds}x

📊 *Payout Calculation:*
- Stake Pool: ₹${(amount * 2).toInt()}
- Winning Share: ₹${amount.toInt()}
- Platform Commission (10%): ₹${_platformCommission.toInt()}
- Net Payout: ₹${_potentialPayout.toInt()}

━━━━━━━━━━━━━━━
_Payment screenshot sent separately._
🆔 *Bet ID:* $betId

✅ Approve or ❌ Reject?''';
  }

  void _showConfirmation(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Confirm Prediction',
              style: GoogleFonts.oswald(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Name', _nameController.text),
                  _buildSummaryRow('Phone', _phoneController.text),
                  const Divider(color: AppColors.border),
                  _buildSummaryRow('Match', '${widget.match.homeTeam} vs ${widget.match.awayTeam}'),
                  _buildSummaryRow('Pick', _selectedTeam!),
                  _buildSummaryRow('Amount', '₹${_amountController.text}'),
                  const Divider(color: AppColors.border),
                  _buildSummaryRow('Platform Fee (10%)', '-₹${_platformCommission.toInt()}', color: AppColors.error),
                  _buildSummaryRow('Potential Payout', '₹${_potentialPayout.toInt()}', color: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _launchWhatsApp(message);
                },
                icon: const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  'Confirm & Share on WhatsApp',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your prediction is registered! Send screenshot on WhatsApp to activate.',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _launchWhatsApp(String message) async {
    try {
      await WhatsAppService.sendBetConfirmation(
        fullName: _nameController.text,
        matchTitle: '${widget.match.homeTeam} vs ${widget.match.awayTeam}',
        teamPicked: _selectedTeam!,
        amount: _stakeAmount,
        potentialPayout: _potentialPayout,
        betId: 'STANDARD',
      );
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'MATCH DETAILS',
          style: GoogleFonts.oswald(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: AppColors.background,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Predict'),
            Tab(text: 'Statistics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPredictionForm(),
          _buildMatchStatistics(),
        ],
      ),
    );
  }

  Widget _buildPredictionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            if (widget.match.homeTeamBadge != null)
                              Image.network(
                                widget.match.homeTeamBadge!,
                                width: 48,
                                height: 48,
                                errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 48),
                              )
                            else
                              const Icon(Icons.shield, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              widget.match.homeTeam,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'VS',
                        style: GoogleFonts.oswald(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            if (widget.match.awayTeamBadge != null)
                              Image.network(
                                widget.match.awayTeamBadge!,
                                width: 48,
                                height: 48,
                                errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 48),
                              )
                            else
                              const Icon(Icons.shield, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              widget.match.awayTeam,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.match.matchDate.day}/${widget.match.matchDate.month}/${widget.match.matchDate.year} • ${widget.match.matchTimeIst}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'YOUR DETAILS',
              style: GoogleFonts.oswald(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Name is required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Phone is required';
                if (value.length < 10) return 'Enter valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              'SELECT TEAM',
              style: GoogleFonts.oswald(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTeamButton(widget.match.homeTeam),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTeamButton(widget.match.awayTeam),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'STAKE AMOUNT',
              style: GoogleFonts.oswald(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [100, 200, 300, 500, 700].map((amount) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        _amountController.text = amount.toString();
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _amountController.text == amount.toString()
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _amountController.text == amount.toString()
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '₹$amount',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _amountController.text == amount.toString()
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Custom Amount',
                prefixIcon: const Icon(Icons.currency_rupee_rounded),
                hintText: '${AppConstants.minBet.toInt()} - ${AppConstants.maxBet.toInt()}',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Amount is required';
                final amount = double.tryParse(value);
                if (amount == null) return 'Enter valid amount';
                if (amount < AppConstants.minBet) return 'Minimum stake is ₹${AppConstants.minBet.toInt()}';
                if (amount > AppConstants.maxBet) return 'Maximum stake is ₹${AppConstants.maxBet.toInt()}';
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (_amountController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    _buildBreakdownRow('Stake Pool', '₹${(_stakeAmount * 2).toInt()}'),
                    _buildBreakdownRow('Winning Share', '₹${_winningShare.toInt()}'),
                    _buildBreakdownRow('Platform Commission (10%)', '-₹${_platformCommission.toInt()}', isNegative: true),
                    const Divider(color: AppColors.border),
                    _buildBreakdownRow('User Payout (Receives)', '₹${_potentialPayout.toInt()}', isHighlighted: true),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'PAYMENT VERIFICATION',
              style: GoogleFonts.oswald(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pay to Admin UPI: paygoalstake@upi\nSend screenshot below to approve prediction.',
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFiles(type: FileType.image);
                  if (result != null && result.files.isNotEmpty) {
                    setState(() {
                      _screenshotFile = result.files.first;
                    });
                  }
                },
                icon: Icon(
                  _screenshotFile == null ? Icons.upload_file_rounded : Icons.check_circle_outline_rounded,
                  color: _screenshotFile == null ? AppColors.primary : AppColors.success,
                ),
                label: Text(
                  _screenshotFile == null ? 'UPLOAD PAYMENT SCREENSHOT' : 'UPLOADED: ${_screenshotFile!.name}',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _screenshotFile == null ? AppColors.border : AppColors.success),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _acknowledgedPolicies,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _acknowledgedPolicies = val ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'I acknowledge and agree to the No Refund Policy. I understand that approved predictions cannot be modified and admin decisions are final.',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitBet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : Text(
                        'SUBMIT PREDICTION',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isNegative = false, bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isHighlighted ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isHighlighted ? 15 : 12,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              color: isNegative
                  ? AppColors.error
                  : isHighlighted
                      ? AppColors.primary
                      : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamButton(String teamName) {
    final isSelected = _selectedTeam == teamName;
    return GestureDetector(
      onTap: () => setState(() => _selectedTeam = teamName),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            teamName,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // --- STATISTICS TAB ---
  Widget _buildMatchStatistics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Community Pick percentages
          _buildCardHeader('Community Consensus Picks'),
          _buildStatsCard([
            _buildPercentagePickRow(),
          ]),
          const SizedBox(height: 20),

          // 2. Team Form (Last 5 matches)
          _buildCardHeader('Team Form (Last 5 Games)'),
          _buildStatsCard([
            _buildFormRow(widget.match.homeTeam, ['W', 'W', 'D', 'W', 'L']),
            const Divider(color: AppColors.border, height: 20),
            _buildFormRow(widget.match.awayTeam, ['W', 'D', 'W', 'W', 'W']),
          ]),
          const SizedBox(height: 20),

          // 3. Head to Head History
          _buildCardHeader('Head-to-Head (Last 3 Meetings)'),
          _buildStatsCard([
            _buildH2hRow('FIFA World Cup 2022', widget.match.homeTeam, '2 - 1', widget.match.awayTeam),
            const Divider(color: AppColors.border, height: 16),
            _buildH2hRow('International Friendly 2024', widget.match.homeTeam, '1 - 1', widget.match.awayTeam),
            const Divider(color: AppColors.border, height: 16),
            _buildH2hRow('Copa America 2025', widget.match.homeTeam, '0 - 2', widget.match.awayTeam),
          ]),
          const SizedBox(height: 20),

          // 4. Core Match Stats
          _buildCardHeader('Historical Averages'),
          _buildStatsCard([
            _buildStatProgressBar('Average Possession', 55, 45),
            const SizedBox(height: 16),
            _buildStatProgressBar('Goals Scored per match', 70, 30, leftValue: '2.4', rightValue: '1.2'),
            const SizedBox(height: 16),
            _buildStatProgressBar('Clean Sheets (last 10)', 60, 40, leftValue: '6', rightValue: '4'),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCardHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.oswald(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStatsCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPercentagePickRow() {
    final homePct = widget.match.homePercentage.toInt();
    final awayPct = widget.match.awayPercentage.toInt();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$homePct% predict ${widget.match.homeTeam}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
            Text('$awayPct% predict ${widget.match.awayTeam}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: homePct,
              child: Container(height: 8, decoration: const BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.horizontal(left: Radius.circular(4)))),
            ),
            Expanded(
              flex: awayPct,
              child: Container(height: 8, decoration: const BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.horizontal(right: Radius.circular(4)))),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildFormRow(String team, List<String> form) {
    return Row(
      children: [
        Expanded(
          child: Text(
            team,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Row(
          children: form.map((res) {
            Color color;
            if (res == 'W') {
              color = AppColors.success;
            } else if (res == 'D') {
              color = AppColors.warning;
            } else {
              color = AppColors.error;
            }
            return Container(
              margin: const EdgeInsets.only(left: 4),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  res,
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildH2hRow(String tournament, String home, String score, String away) {
    return Column(
      children: [
        Text(
          tournament,
          style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text(home, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(6)),
              child: Text(score, style: GoogleFonts.oswald(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(away, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500))),
          ],
        )
      ],
    );
  }

  Widget _buildStatProgressBar(String label, int leftPercent, int rightPercent, {String? leftValue, String? rightValue}) {
    final lVal = leftValue ?? '$leftPercent%';
    final rVal = rightValue ?? '$rightPercent%';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lVal, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
            Text(rVal, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: leftPercent,
              child: Container(height: 4, decoration: const BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.horizontal(left: Radius.circular(2)))),
            ),
            Expanded(
              flex: rightPercent,
              child: Container(height: 4, decoration: const BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.horizontal(right: Radius.circular(2)))),
            ),
          ],
        ),
      ],
    );
  }
}
