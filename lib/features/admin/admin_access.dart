import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/csv_export_service.dart';
import '../../shared/services/settlement_service.dart';
import '../../shared/services/live_score_poller.dart';
import '../../shared/models/bet.dart';
import '../../shared/models/match.dart';
import '../../shared/models/user.dart';
import '../home/home_screen.dart'; // for flag helper

class AdminAccess extends StatefulWidget {
  const AdminAccess({super.key});

  @override
  State<AdminAccess> createState() => _AdminAccessState();
}

class _AdminAccessState extends State<AdminAccess> with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  bool _isAuthenticated = false;
  late SupabaseService _supabase;
  late SettlementService _settlement;
  late LiveScorePoller _poller;
  
  late TabController _tabController;

  // State lists
  List<Bet> _pendingBets = [];
  List<AppMatch> _allMatches = [];
  List<AppUser> _allUsers = [];
  List<AppUser> _searchResults = [];
  List<Map<String, dynamic>> _socialPosts = [];
  
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isSyncing = false;
  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _supabase = SupabaseService();
    _settlement = SettlementService();
    _poller = LiveScorePoller();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _login() {
    if (_passwordController.text == AppConstants.adminPassword) {
      setState(() => _isAuthenticated = true);
      _loadAllAdminData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid password', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadAllAdminData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Bets
      final pendingBets = await _getUserBetsByStatus('pending');
      final allBetsResponse = await _supabase.client.from('bets').select();
      final allBets = (allBetsResponse as List).map((b) => Bet.fromJson(b)).toList();
      
      final totalBetsCount = allBets.length;
      final pendingCount = pendingBets.length;
      final totalVolume = allBets.fold<double>(0, (sum, b) => sum + b.amount);
      
      // Calculate revenue (10% of settled payouts + volume estimates)
      final settledBets = allBets.where((b) => b.status == 'won' || b.status == 'lost').toList();
      final double commissionEarned = settledBets.fold<double>(0, (sum, b) {
        // Standard standard prediction fee (10% of potential winnings)
        return sum + (b.potentialPayout * 0.10);
      });
      final double totalRevenue = commissionEarned + (totalVolume * 0.05); // volume fee

      // 2. Fetch Matches
      final matchesList = await _supabase.getMatches();

      // 3. Fetch Users
      final usersResponse = await _supabase.client.from('users').select();
      final usersList = (usersResponse as List).map((u) => AppUser.fromJson(u)).toList();

      // 4. Fetch Social Posts
      // Avoid crash if table public_predictions is missing on server
      List<Map<String, dynamic>> postsList = [];
      try {
        final socialResponse = await _supabase.client.from('public_predictions').select().order('created_at', ascending: false);
        postsList = List<Map<String, dynamic>>.from(socialResponse);
      } catch (e) {
        debugPrint('Social Table missing. Displaying mocked posts in admin.');
        // Fallback to empty list or basic mockup
      }

      setState(() {
        _pendingBets = pendingBets;
        _allMatches = matchesList;
        _allUsers = usersList;
        _searchResults = usersList;
        _socialPosts = postsList;
        _stats = {
          'total_bets': totalBetsCount,
          'pending': pendingCount,
          'volume': totalVolume,
          'active_users': usersList.where((u) => u.isActive).length,
          'suspended_users': usersList.where((u) => !u.isActive).length,
          'live_matches': matchesList.where((m) => m.isLive).length,
          'revenue': totalRevenue,
          'commission': commissionEarned,
          'flagged_activities': allBets.where((b) => b.amount > 600).length, // stake volume flag
        };
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Bet>> _getUserBetsByStatus(String status) async {
    try {
      final response = await _supabase.client
          .from('bets')
          .select()
          .eq('status', status)
          .order('created_at', ascending: false);
      return (response as List).map((b) => Bet.fromJson(b)).toList();
    } catch (e) {
      return [];
    }
  }

  // Bet actions
  Future<void> _approveBet(String betId) async {
    try {
      await _supabase.updateBetStatus(betId, 'active');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bet approved successfully!', style: GoogleFonts.poppins()), backgroundColor: AppColors.primary),
      );
      _loadAllAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving: $e', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _rejectBet(String betId) async {
    try {
      await _supabase.updateBetStatus(betId, 'lost');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bet rejected and closed.', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
      );
      _loadAllAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting: $e', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
      );
    }
  }

  // Match management
  Future<void> _syncMatchesManually() async {
    setState(() => _isSyncing = true);
    try {
      await _poller.syncAllFixtures();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Manual SportsLiveDB sync completed!', style: GoogleFonts.poppins()), backgroundColor: AppColors.primary),
      );
      _loadAllAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync error: $e', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _lockPredictions(String matchId, bool lock) async {
    try {
      final newStatus = lock ? 'live' : 'upcoming'; // live status locks predictions
      await _supabase.client.from('matches').update({'status': newStatus}).eq('id', matchId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lock ? 'Predictions locked!' : 'Predictions opened!', style: GoogleFonts.poppins()), backgroundColor: AppColors.primary),
      );
      _loadAllAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _settleMatch(String matchId, int homeScore, int awayScore) async {
    try {
      // 1. Update match scores and mark finished
      await _supabase.client.from('matches').update({
        'home_score': homeScore,
        'away_score': awayScore,
        'status': 'finished',
      }).eq('id', matchId);
      
      // 2. Settle the bets on that match
      await _settlement.settleMatchBets(matchId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Match settled & payouts processed!', style: GoogleFonts.poppins()), backgroundColor: AppColors.primary),
      );
      _loadAllAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settlement error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _voidMatch(String matchId) async {
    try {
      // Mark all active bets as settled with original stake refunded (status: lost or custom void)
      await _supabase.client.from('bets').update({'status': 'void', 'potential_payout': 0}).eq('match_id', matchId);
      await _supabase.client.from('matches').update({'status': 'void', 'is_settled': true}).eq('id', matchId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Match voided & stakes refunded.', style: GoogleFonts.poppins()), backgroundColor: AppColors.warning),
      );
      _loadAllAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Void error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // User management
  void _searchUsers(String query) {
    setState(() {
      _userSearchQuery = query;
      if (query.isEmpty) {
        _searchResults = _allUsers;
      } else {
        _searchResults = _allUsers.where((u) {
          final fullName = u.fullName.toLowerCase();
          final phone = u.phone.toLowerCase();
          final bettorId = u.bettorId.toLowerCase();
          final cleanQuery = query.toLowerCase();
          return fullName.contains(cleanQuery) || phone.contains(cleanQuery) || bettorId.contains(cleanQuery);
        }).toList();
      }
    });
  }

  Future<void> _toggleUserActive(String userId, bool active) async {
    try {
      await _supabase.client.from('users').update({'is_active': active}).eq('id', userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(active ? 'User account activated!' : 'User account suspended!', style: GoogleFonts.poppins()),
          backgroundColor: active ? AppColors.primary : AppColors.error,
        ),
      );
      _loadAllAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle active: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // Social Moderation
  Future<void> _deletePost(String postId) async {
    try {
      await _supabase.client.from('public_predictions').delete().eq('id', postId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Community post deleted.', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
      );
      _loadAllAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _toggleFeaturePost(String postId, bool feature) async {
    try {
      await _supabase.client.from('public_predictions').update({'is_featured': feature}).eq('id', postId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feature ? 'Post featured!' : 'Post unfeatured.', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.primary,
        ),
      );
      _loadAllAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Feature error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // Leaderboard Management
  Future<void> _resetLeaderboardSeason() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Leaderboard Season?', style: GoogleFonts.oswald()),
        content: Text('This will reset wins, losses, total bets, and staked volume for ALL users to start a fresh monthly season. This cannot be undone!', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('RESET ALL STATS'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      // Update all users statistics to zero
      await _supabase.client.from('users').update({
        'wins': 0,
        'losses': 0,
        'total_bets': 0,
        'total_staked': 0.0,
        'total_won': 0.0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Season stats reset successfully!', style: GoogleFonts.poppins()), backgroundColor: AppColors.primary),
      );
      _loadAllAdminData();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // Exports
  Future<void> _exportBets() async => CsvExportService().exportBetsCsv();
  Future<void> _exportUsers() async => CsvExportService().exportUsersCsv();
  Future<void> _exportLastDance() async => CsvExportService().exportLastDanceCsv();

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildLoginScreen();
    }
    return _buildAdminDashboard();
  }

  Widget _buildLoginScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'ADMIN ACCESS',
          style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
        backgroundColor: AppColors.background,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.shield_rounded, color: AppColors.secondary, size: 40),
              ),
              const SizedBox(height: 24),
              Text('Admin Login', style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Enter admin password to continue', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text('LOGIN', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminDashboard() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'ADMIN PANEL',
          style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
        backgroundColor: AppColors.background,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Analytics'),
            Tab(text: 'Approvals'),
            Tab(text: 'Matches'),
            Tab(text: 'Users'),
            Tab(text: 'Social'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAllAdminData,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
          IconButton(
            onPressed: () => setState(() => _isAuthenticated = false),
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAnalyticsTab(),
                _buildApprovalsTab(),
                _buildMatchesTab(),
                _buildUsersTab(),
                _buildSocialTab(),
              ],
            ),
    );
  }

  // --- TAB 1: ANALYTICS ---
  Widget _buildAnalyticsTab() {
    final revenue = _stats['revenue'] ?? 0.0;
    final commission = _stats['commission'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Active Users', '${_stats['active_users'] ?? 0}', AppColors.primary),
              _buildStatCard('Volume Pool', '₹${((_stats['volume'] ?? 0) / 1000).toStringAsFixed(1)}K', AppColors.secondary),
              _buildStatCard('Revenue Generated', '₹${revenue.toInt()}', AppColors.accent),
              _buildStatCard('Commission Earned', '₹${commission.toInt()}', AppColors.success),
            ],
          ),
          const SizedBox(height: 24),

          // Platform metrics
          _buildAdminSectionTitle('Flagged & Risk Activities'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Flagged predictions (> ₹600)', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    Text('${_stats['flagged_activities'] ?? 0} suspicious flags found', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
                Icon(Icons.warning_amber_rounded, color: (_stats['flagged_activities'] ?? 0) > 0 ? AppColors.warning : AppColors.success, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons & Season control
          _buildAdminSectionTitle('Admin Maintenance'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resetLeaderboardSeason,
                  icon: const Icon(Icons.restart_alt_rounded, color: AppColors.background),
                  label: const Text('RESET SEASON'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.background),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildExportButton(Icons.download, 'Bets CSV', _exportBets, AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _buildExportButton(Icons.people, 'Users CSV', _exportUsers, AppColors.accent)),
              const SizedBox(width: 8),
              Expanded(child: _buildExportButton(Icons.emoji_events, 'LD CSV', _exportLastDance, AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildExportButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminSectionTitle(String title) {
    return Text(title.toUpperCase(), style: GoogleFonts.oswald(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.2));
  }

  // --- TAB 2: APPROVALS ---
  Widget _buildApprovalsTab() {
    if (_pendingBets.isEmpty) {
      return Center(child: Text('No pending bets waiting for payment approval.', style: GoogleFonts.poppins(color: AppColors.textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingBets.length,
      itemBuilder: (context, index) {
        final bet = _pendingBets[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prediction #${bet.id.substring(0, 8)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('₹${bet.amount.toInt()}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Pick: ${bet.teamPicked} · Odds: ${bet.odds}x · Payout: ₹${bet.potentialPayout.toInt()}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approveBet(bet.id),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 8)),
                      child: Text('Approve', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectBet(bet.id),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(vertical: 8)),
                      child: Text('Reject', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3: MATCHES ---
  Widget _buildMatchesTab() {
    return Column(
      children: [
        // Sync control header
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncMatchesManually,
              icon: _isSyncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2))
                  : const Icon(Icons.sync_rounded, color: AppColors.background),
              label: const Text('SYNC SPORTSLIVEDB FIXTURES'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _allMatches.length,
            itemBuilder: (context, index) {
              final match = _allMatches[index];
              return _buildAdminMatchTile(match);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdminMatchTile(AppMatch match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: match.isLive ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${match.round} · ${match.statusDisplay}', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              Text(
                '₹${match.totalStaked.toInt()} Pool',
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(getCountryFlagEmoji(match.homeTeam), style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(child: Text(match.homeTeam, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(6)),
                child: Text(match.scoreDisplay, style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(match.awayTeam, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold))),
              const SizedBox(width: 6),
              Text(getCountryFlagEmoji(match.awayTeam), style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),

          // Actions Row
          Row(
            children: [
              // 1. Lock/Unlock predictions
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _lockPredictions(match.id, !match.isLive),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: match.isLive ? AppColors.warning : AppColors.primary,
                    side: BorderSide(color: match.isLive ? AppColors.warning : AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  child: Text(match.isLive ? 'Unlock' : 'Lock', style: const TextStyle(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 6),

              // 2. Score overrides / Settle
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _openScoreOverrideDialog(match),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  child: const Text('Override', style: TextStyle(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 6),

              // 3. Void match
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _voidMatch(match.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  child: const Text('Void', style: TextStyle(fontSize: 10)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _openScoreOverrideDialog(AppMatch match) {
    final homeController = TextEditingController(text: '${match.homeScore ?? 0}');
    final awayController = TextEditingController(text: '${match.awayScore ?? 0}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Override Score & Settle', style: GoogleFonts.oswald()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: TextFormField(controller: homeController, decoration: InputDecoration(labelText: '${match.homeTeam} Score'))),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: awayController, decoration: InputDecoration(labelText: '${match.awayTeam} Score'))),
              ],
            ),
            const SizedBox(height: 12),
            Text('Settling this will distribute the pool, deduct a 10% commission, and credit user accounts.', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final h = int.tryParse(homeController.text) ?? 0;
              final a = int.tryParse(awayController.text) ?? 0;
              _settleMatch(match.id, h, a);
            },
            child: const Text('SETTLE RESULT'),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: USERS ---
  Widget _buildUsersTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Search Users (Phone / GS-ID / Name)',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _searchUsers,
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: user.isActive ? AppColors.primary.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.person, color: user.isActive ? AppColors.primary : AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('${user.bettorId} · ${user.phone}', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted)),
                          Text('${user.wins} Wins · ${user.losses} Losses · Volume: ₹${user.totalStaked.toInt()}', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Switch(
                      value: user.isActive,
                      activeColor: AppColors.primary,
                      inactiveTrackColor: AppColors.error.withValues(alpha: 0.3),
                      inactiveThumbColor: AppColors.error,
                      onChanged: (val) => _toggleUserActive(user.id, val),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 5: SOCIAL MODERATION ---
  Widget _buildSocialTab() {
    if (_socialPosts.isEmpty) {
      return Center(child: Text('No community feed posts available.', style: GoogleFonts.poppins(color: AppColors.textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _socialPosts.length,
      itemBuilder: (context, index) {
        final post = _socialPosts[index];
        final isFeatured = post['is_featured'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${post['full_name']} (${post['gs_id']})', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => _deletePost(post['id']),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  )
                ],
              ),
              const SizedBox(height: 4),
              Text(post['prediction_text'] ?? '', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _toggleFeaturePost(post['id'], !isFeatured),
                    icon: Icon(isFeatured ? Icons.star_rounded : Icons.star_border_rounded, size: 16),
                    label: Text(isFeatured ? 'Featured' : 'Feature', style: const TextStyle(fontSize: 10)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      foregroundColor: AppColors.secondary,
                      side: BorderSide(color: AppColors.secondary),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
