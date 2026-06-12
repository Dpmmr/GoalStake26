import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/models.dart';
import '../../shared/utils/file_storage.dart';
import '../../shared/services/whatsapp_service.dart';

class LastDanceScreen extends ConsumerStatefulWidget {
  const LastDanceScreen({super.key});

  @override
  ConsumerState<LastDanceScreen> createState() => _LastDanceScreenState();
}

class _LastDanceScreenState extends ConsumerState<LastDanceScreen> {
  String? _selectedCountry;
  double? _selectedAmount;
  bool _isSubmitting = false;
  late SupabaseService _supabase;
  List<CountryPool> _countryPool = [];
  bool _isLoadingPool = true;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  PlatformFile? _screenshotFile;
  bool _acknowledgedPolicies = false;

  @override
  void initState() {
    super.initState();
    _supabase = ref.read(supabaseServiceProvider);
    _loadCountryPool();
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
    super.dispose();
  }

  Future<void> _loadCountryPool() async {
    try {
      final pool = await _supabase.getCountryPool();
      setState(() {
        _countryPool = pool;
        _isLoadingPool = false;
      });
    } catch (e) {
      setState(() => _isLoadingPool = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'LAST DANCE BET',
          style: GoogleFonts.oswald(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 48,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FIFA 2026',
                    style: GoogleFonts.oswald(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Who will lift the trophy?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your nation, place your prediction,\nand compete with other football fans.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),
            Text(
              'SELECT YOUR CHAMPION',
              style: GoogleFonts.oswald(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            _isLoadingPool
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _countryPool.length,
                    itemBuilder: (context, index) {
                      final country = _countryPool[index];
                      final isSelected = _selectedCountry == country.country;
                      final isFull = country.participants >= AppConstants.lastDanceMaxParticipants;

                      return GestureDetector(
                        onTap: isFull
                            ? null
                            : () {
                                setState(() => _selectedCountry = country.country);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : isFull
                                      ? AppColors.error.withValues(alpha: 0.3)
                                      : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                country.countryFlag ?? '',
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                country.country,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFull
                                    ? 'FULL'
                                    : '${AppConstants.lastDanceMaxParticipants - country.participants}/${AppConstants.lastDanceMaxParticipants}',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: isFull ? AppColors.error : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),
            if (_selectedCountry != null) ...[
              Text(
                'SELECT AMOUNT',
                style: GoogleFonts.oswald(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [300, 500, 700, 1000].map((amount) {
                  final isSelected = _selectedAmount == amount.toDouble();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedAmount = amount.toDouble()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '₹$amount',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (_selectedAmount != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _showPredictionConfirmation(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : Text(
                            'PLACE PREDICTION',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.background,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only ${AppConstants.lastDanceMaxParticipants} slots available per country. Minimum ₹${AppConstants.lastDanceMinBet.toInt()}, Maximum ₹${AppConstants.lastDanceMaxBet.toInt()}. 15% Platform Fee applies.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPredictionConfirmation(BuildContext context) {
    if (_selectedCountry == null || _selectedAmount == null) return;
    
    final country = _countryPool.firstWhere((c) => c.country == _selectedCountry);
    
    double totalPool = _countryPool.fold<double>(0, (sum, c) => sum + c.totalStaked);
    double countryStaked = country.totalStaked;
    
    double simTotalPool = totalPool + _selectedAmount!;
    double simCountryStaked = countryStaked + _selectedAmount!;
    
    double grossWinningAmount = (_selectedAmount! / simCountryStaked) * simTotalPool;
    if (grossWinningAmount.isNaN || grossWinningAmount.isInfinite) {
      grossWinningAmount = _selectedAmount! * 5.0; 
    }
    double platformCommission = grossWinningAmount * 0.15;
    double userReceives = grossWinningAmount - platformCommission;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.secondary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TOURNAMENT PREDICTION',
                    style: GoogleFonts.oswald(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                      letterSpacing: 1.5,
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
                        _buildSummaryRow('Champion Pick', '${country.countryFlag ?? ""} ${country.country}'),
                        _buildSummaryRow('Your Stake', '₹${_selectedAmount!.toInt()}'),
                        _buildSummaryRow('Estimated Total Pool', '₹${simTotalPool.toInt()}'),
                        _buildSummaryRow('Estimated Pool Share', '${((_selectedAmount! / simCountryStaked) * 100).toStringAsFixed(1)}%'),
                        const Divider(color: AppColors.border),
                        _buildSummaryRow('Estimated Winning Share', '₹${grossWinningAmount.toInt()}'),
                        _buildSummaryRow('Platform Commission (15%)', '-₹${platformCommission.toInt()}', color: AppColors.error),
                        _buildSummaryRow('Potential Net Payout', '₹${userReceives.toInt()}', color: AppColors.primary),
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
                          setStateSheet(() {});
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
                          setStateSheet(() {});
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
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        if (_screenshotFile == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Upload payment screenshot first', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        if (!_acknowledgedPolicies) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Acknowledge No Refund Policy', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        _placePrediction();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'CONFIRM & SUBMIT',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.background,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A platform commission fee of 15% is deducted from all tournament winnings.',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
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

  Future<void> _placePrediction() async {
    if (_selectedCountry == null || _selectedAmount == null) return;
    if (_screenshotFile == null) return;

    setState(() => _isSubmitting = true);

    try {
      final country = _countryPool.firstWhere((c) => c.country == _selectedCountry);

      // 1. Upload screenshot
      final screenshotUrl = await _supabase.uploadScreenshot(
        _screenshotFile!.name,
        _screenshotFile!.bytes ?? Uint8List(0),
      );

      // 2. Lookup or create user
      final phone = _phoneController.text.trim();
      final fullName = _nameController.text.trim();
      
      var dbUser = await _supabase.getUserByPhone(phone);
      if (dbUser == null) {
        final gsId = 'GS${phone.substring(phone.length - (phone.length >= 6 ? 6 : phone.length))}';
        dbUser = await _supabase.createUser(
          phone: phone,
          fullName: fullName,
          gsId: gsId,
        );
      }

      // Cache phone and name for next time
      await FileStorage().writeCache('user_phone', phone);
      await FileStorage().writeCache('user_name', fullName);

      // 3. Create Last Dance Bet
      final bet = await _supabase.createLastDanceBet(
        userId: dbUser.id,
        country: country.country,
        countryFlag: country.countryFlag ?? '',
        amount: _selectedAmount!,
        paymentScreenshotUrl: screenshotUrl,
      );

      // 4. Launch WhatsApp confirmation
      final message = '''🟢 *NEW TOURNAMENT PREDICTION*
━━━━━━━━━━━━━━━

👤 *Name:* $fullName
📱 *Phone:* $phone

🏆 *Tournament pick:* ${country.countryFlag ?? ""} ${country.country}
💰 *Amount staked:* ₹${_selectedAmount!.toInt()}
📅 *Timestamp:* ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}

_Payment screenshot sent separately._
🆔 *Bet ID:* ${bet.id}

✅ Approve or ❌ Reject?''';

      final encodedMessage = Uri.encodeComponent(message);
      final url = 'https://wa.me/${AppConstants.adminWhatsApp}?text=$encodedMessage';
      
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Prediction placed for $_selectedCountry! Status: Pending Verification.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        _loadCountryPool();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
