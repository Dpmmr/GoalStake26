import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/bet.dart';
import '../../shared/models/user.dart';
import '../../shared/utils/file_storage.dart';

class MyBetsScreen extends ConsumerStatefulWidget {
  const MyBetsScreen({super.key});

  @override
  ConsumerState<MyBetsScreen> createState() => _MyBetsScreenState();
}

class _MyBetsScreenState extends ConsumerState<MyBetsScreen> {
  late SupabaseService _supabase;
  String? _cachedPhone;
  bool _isLoadingPhone = true;
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _supabase = ref.read(supabaseServiceProvider);
    _loadCachedPhone();
  }

  void _loadCachedPhone() async {
    try {
      final phone = await FileStorage().readCache('user_phone');
      if (mounted) {
        setState(() {
          _cachedPhone = (phone == null || phone.trim().isEmpty) ? null : phone.trim();
          _isLoadingPhone = false;
          if (_cachedPhone != null) {
            _phoneController.text = _cachedPhone!;
          } else {
            _phoneController.clear();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPhone = false);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'MY BETS',
            style: GoogleFonts.oswald(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          backgroundColor: AppColors.background,
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Won'),
              Tab(text: 'Lost'),
              Tab(text: 'Pending'),
            ],
          ),
        ),
        body: _isLoadingPhone
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _cachedPhone == null
                ? _buildPhoneInputScreen()
                : Column(
                    children: [
                      _buildWalletHeader(_cachedPhone!),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildBetsList(_cachedPhone!, 'active'),
                            _buildBetsList(_cachedPhone!, 'won'),
                            _buildBetsList(_cachedPhone!, 'lost'),
                            _buildBetsList(_cachedPhone!, 'pending'),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPhoneInputScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'View Prediction History',
                style: GoogleFonts.oswald(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your phone number to view all your predictions, active balances, and winning history.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Phone number is required';
                  if (value.length < 10) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final phone = _phoneController.text.trim();
                    await FileStorage().writeCache('user_phone', phone);
                    setState(() {
                      _cachedPhone = phone;
                    });
                  },
                  child: Text('VIEW PREDICTIONS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletHeader(String phone) {
    return FutureBuilder<AppUser?>(
      future: _supabase.getUserByPhone(phone),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final appUser = userSnapshot.data;
        if (appUser == null) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'No predictions registered under $phone yet.',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted),
                  onPressed: () async {
                    await FileStorage().writeCache('user_phone', '');
                    setState(() {
                      _cachedPhone = null;
                      _phoneController.clear();
                    });
                  },
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<Bet>>(
          future: _supabase.getUserBetsByPhone(phone),
          builder: (context, snapshot) {
            double pendingWinnings = 0;
            if (snapshot.hasData) {
              final activeAndPending = snapshot.data!.where((b) => b.status == 'active' || b.status == 'pending');
              pendingWinnings = activeAndPending.fold<double>(0, (sum, b) => sum + b.potentialPayout);
            }

            final currentBalance = 5000.0 + appUser.totalWon - appUser.totalStaked;

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appUser.fullName.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'ID: ${appUser.bettorId} · ${appUser.phone}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                        tooltip: 'Change Phone Number',
                        onPressed: () async {
                          await FileStorage().writeCache('user_phone', '');
                          setState(() {
                            _cachedPhone = null;
                            _phoneController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildWalletStat('Balance', '₹${currentBalance.toInt()}', Colors.white),
                      _buildWalletStat('Pending Win', '₹${pendingWinnings.toInt()}', Colors.white),
                      _buildWalletStat('Won Share', '₹${appUser.totalWon.toInt()}', Colors.white),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWalletStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBetsList(String phone, String status) {
    return FutureBuilder<List<Bet>>(
      future: _supabase.getUserBetsByPhoneAndStatus(phone, status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading bets',
              style: GoogleFonts.poppins(color: AppColors.error),
            ),
          );
        }

        final bets = snapshot.data ?? [];

        if (bets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'active'
                      ? Icons.sports_soccer_rounded
                      : status == 'won'
                          ? Icons.emoji_events_rounded
                          : status == 'lost'
                              ? Icons.sentiment_dissatisfied_rounded
                              : Icons.hourglass_empty_rounded,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'No $status bets yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bets.length,
          itemBuilder: (context, index) {
            final bet = bets[index];
            return _buildBetCard(bet, index);
          },
        );
      },
    );
  }

  Widget _buildBetCard(Bet bet, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(bet.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bet.status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(bet.status),
                  ),
                ),
              ),
              Text(
                _formatDate(bet.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Bet on ${bet.teamPicked}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBetDetail('Pick', bet.teamPicked),
              _buildBetDetail('Staked', '₹${bet.amount.toInt()}'),
              _buildBetDetail('Potential', '₹${bet.potentialPayout.toInt()}'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
        );
  }

  Widget _buildBetDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.primary;
      case 'won':
        return AppColors.secondary;
      case 'lost':
        return AppColors.error;
      case 'pending':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }
}
