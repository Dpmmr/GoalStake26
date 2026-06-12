import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../shared/services/supabase_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late SupabaseService _supabase;
  List<Map<String, dynamic>> _allBettors = [];
  List<Map<String, dynamic>> _sortedBettors = [];
  bool _isLoading = true;
  int _activeSortIndex = 0; // 0: Accuracy, 1: Streak (Wins), 2: Engagement (Bets)

  @override
  void initState() {
    super.initState();
    _supabase = SupabaseService();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.client
          .from('users')
          .select('id, gs_id, full_name, total_bets, total_staked, total_earned, wins, losses')
          .limit(50);

      setState(() {
        _allBettors = List<Map<String, dynamic>>.from(response);
        _applySorting();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySorting() {
    final listCopy = List<Map<String, dynamic>>.from(_allBettors);

    if (_activeSortIndex == 0) {
      // Sort by Accuracy (Win Rate)
      listCopy.sort((a, b) {
        final aBets = a['total_bets'] ?? 0;
        final bBets = b['total_bets'] ?? 0;
        final aWins = a['wins'] ?? 0;
        final bWins = b['wins'] ?? 0;
        final aRate = aBets > 0 ? (aWins / aBets) : 0.0;
        final bRate = bBets > 0 ? (bWins / bBets) : 0.0;
        return bRate.compareTo(aRate);
      });
    } else if (_activeSortIndex == 1) {
      // Sort by Streak / Wins
      listCopy.sort((a, b) {
        final aWins = a['wins'] ?? 0;
        final bWins = b['wins'] ?? 0;
        return bWins.compareTo(aWins);
      });
    } else {
      // Sort by Engagement (Total Bets)
      listCopy.sort((a, b) {
        final aBets = a['total_bets'] ?? 0;
        final bBets = b['total_bets'] ?? 0;
        return bBets.compareTo(aBets);
      });
    }

    setState(() {
      _sortedBettors = listCopy.take(15).toList();
    });
  }

  int _getDaysRemainingInMonth() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return lastDay.difference(now).inDays;
  }

  String _getCurrentSeasonName() {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year} Season';
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = _getDaysRemainingInMonth();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'LEADERBOARDS',
          style: GoogleFonts.oswald(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            onPressed: _loadLeaderboard,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Season Information header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getCurrentSeasonName().toUpperCase(),
                              style: GoogleFonts.oswald(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Leaderboard resets monthly. Ranks lock in $daysLeft days.',
                              style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),

                // Custom sorting tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildSortTab(0, 'Accuracy'),
                      const SizedBox(width: 8),
                      _buildSortTab(1, 'Streak (Wins)'),
                      const SizedBox(width: 8),
                      _buildSortTab(2, 'Engagement'),
                    ],
                  ),
                ),

                // Podium Display for Top 3
                if (_sortedBettors.length >= 3)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.15),
                          AppColors.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPodiumItem('2nd', _sortedBettors[1], const Color(0xFFC0C0C0)),
                        _buildPodiumItem('1st', _sortedBettors[0], AppColors.secondary, isFirst: true),
                        _buildPodiumItem('3rd', _sortedBettors[2], const Color(0xFFCD7F32)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).scaleY(begin: 0.9, end: 1),

                // Rest of the List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _sortedBettors.length,
                    itemBuilder: (context, index) {
                      final bettor = _sortedBettors[index];
                      final rank = index + 1;
                      final rankColor = rank == 1
                          ? AppColors.secondary
                          : rank == 2
                              ? const Color(0xFFC0C0C0)
                              : rank == 3
                                  ? const Color(0xFFCD7F32)
                                  : AppColors.textMuted;
                      final gsId = bettor['gs_id'] ?? 'GS-000000';
                      final totalBets = bettor['total_bets'] ?? 0;
                      final wins = bettor['wins'] ?? 0;
                      final losses = bettor['losses'] ?? 0;
                      final totalStaked = bettor['total_staked'] ?? 0.0;
                      final winRate = totalBets > 0 ? ((wins / totalBets) * 100).toInt() : 0;

                      // Display values depending on the active sort
                      String valueText = '';
                      if (_activeSortIndex == 0) {
                        valueText = '$winRate% Win Rate';
                      } else if (_activeSortIndex == 1) {
                        valueText = '$wins Streak Wins';
                      } else {
                        valueText = '$totalBets Predictions';
                      }

                      // Dynamic movement indicators (just mock indicator showing up/down movement)
                      final bool isMovingUp = (index % 3 == 0);
                      final bool isMovingDown = (index % 5 == 0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: rankColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '$rank',
                                  style: GoogleFonts.oswald(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: rankColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        gsId,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isMovingUp)
                                        const Icon(Icons.arrow_drop_up_rounded, color: AppColors.success, size: 18)
                                      else if (isMovingDown)
                                        const Icon(Icons.arrow_drop_down_rounded, color: AppColors.error, size: 18)
                                      else
                                        const Icon(Icons.remove_rounded, color: AppColors.textMuted, size: 14),
                                    ],
                                  ),
                                  Text(
                                    '$wins W · $losses L · $totalBets total',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  valueText,
                                  style: GoogleFonts.oswald(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                Text(
                                  '₹${totalStaked.toInt()} Vol',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(
                            delay: Duration(milliseconds: 30 * index),
                            duration: 300.ms,
                          );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSortTab(int index, String label) {
    final isSelected = _activeSortIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeSortIndex = index;
            _applySorting();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumItem(String place, Map<String, dynamic> bettor, Color color, {bool isFirst = false}) {
    final gsId = bettor['gs_id'] ?? 'GS-000';
    final totalBets = bettor['total_bets'] ?? 0;
    final wins = bettor['wins'] ?? 0;
    final totalStaked = bettor['total_staked'] ?? 0.0;
    final winRate = totalBets > 0 ? ((wins / totalBets) * 100).toInt() : 0;

    String statText = '';
    if (_activeSortIndex == 0) {
      statText = '$winRate% WR';
    } else if (_activeSortIndex == 1) {
      statText = '$wins Wins';
    } else {
      statText = '$totalBets Preds';
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isFirst ? 56 : 48,
          height: isFirst ? 56 : 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isFirst ? 2.5 : 2),
            boxShadow: isFirst
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              place,
              style: GoogleFonts.oswald(
                fontSize: isFirst ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          gsId,
          style: GoogleFonts.poppins(
            fontSize: isFirst ? 13 : 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          statText,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '₹${totalStaked.toInt()}',
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0);
  }
}
