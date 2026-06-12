import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/models/match.dart';
import '../../shared/providers/matches_provider.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/live_score_poller.dart';
import '../match_centre/match_centre_screen.dart';
import '../betting/place_bet_screen.dart';
import '../my_bets/my_bets_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../last_dance/last_dance_screen.dart';
import '../ai_centre/ai_centre_screen.dart';
import '../admin/admin_access.dart';

import 'social_feed_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const _DashboardContent(),
    const MatchCentreScreen(),
    const SocialFeedScreen(),
    const MyBetsScreen(),
    const LeaderboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveScorePollerProvider).startPolling();
    });
  }

  @override
  void dispose() {
    ref.read(liveScorePollerProvider).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.sports_soccer_rounded, 'Matches'),
                _buildNavItem(2, Icons.people_rounded, 'Community'),
                _buildNavItem(3, Icons.receipt_long_rounded, 'My Bets'),
                _buildNavItem(4, Icons.leaderboard_rounded, 'Ranks'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerStatefulWidget {
  const _DashboardContent();

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  int _adminTapCount = 0;
  Map<String, dynamic> _platformStats = {};
  List<Map<String, dynamic>> _topBettors = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final supabase = SupabaseService();
      
      // Load platform stats
      final statsResponse = await supabase.client.from('platform_stats').select();
      final stats = <String, dynamic>{};
      for (final row in statsResponse) {
        stats[row['stat_key']] = row['stat_value'];
      }

      // Load top bettors
      final bettorsResponse = await supabase.client
          .from('users')
          .select('id, gs_id, full_name, total_bets, total_staked, total_earned')
          .order('total_staked', ascending: false)
          .limit(3);

      if (mounted) {
        setState(() {
          _platformStats = stats;
          _topBettors = List<Map<String, dynamic>>.from(bettorsResponse);
        });
      }
    } catch (e) {
      debugPrint('Error loading platform stats: $e');
    }
  }

  void _onAdminTap() {
    _adminTapCount++;
    if (_adminTapCount >= AppConstants.adminTapCount) {
      _adminTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminAccess()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(matchesProvider);
        await _loadStats();
      },
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.surface, AppColors.background],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: _onAdminTap,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppConstants.appName,
                                    style: GoogleFonts.oswald(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppConstants.fifaWorldCup,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.secondary,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const AiCentreScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppColors.primary, AppColors.accent],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      color: AppColors.background,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LastDanceScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppColors.secondary, Color(0xFFFF8C00)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events_rounded,
                                      color: AppColors.background,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildQuickStats(),
                const SizedBox(height: 24),
                
                // 1. LIVE MATCHES SECTION
                _buildLiveMatchesSection(context),
                
                // 2. UPCOMING MATCHES SECTION
                _buildSectionHeader('Upcoming FIFA 2026 Matches', 'View All', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MatchCentreScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                _buildUpcomingSection(context),
                const SizedBox(height: 24),

                // 3. TRENDING MATCHES SECTION
                _buildSectionHeader('Trending Matches', null, null),
                const SizedBox(height: 12),
                _buildTrendingSection(context),
                const SizedBox(height: 24),

                // 4. COMMUNITY PICKS SECTION
                _buildSectionHeader('Community Consensus Picks', null, null),
                const SizedBox(height: 12),
                _buildCommunityPicksSection(context),
                const SizedBox(height: 24),

                // 5. STAY UPDATED
                _buildSectionHeader('Stay Updated', null, null),
                const SizedBox(height: 12),
                _buildStayUpdatedSection(),
                const SizedBox(height: 24),

                // 6. TOP BETTORS
                _buildSectionHeader('Top Bettors', 'Leaderboard', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                _buildTopBettors(),
                const SizedBox(height: 24),

                // 7. PLATFORM STATS
                _buildPlatformStats(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStat('104', 'Matches'),
          _buildDivider(),
          _buildQuickStat('48', 'Teams'),
          _buildDivider(),
          _buildQuickStat('12', 'Groups'),
          _buildDivider(),
          _buildQuickStat('6', 'Rounds'),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildQuickStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.oswald(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 32,
      width: 1,
      color: AppColors.border,
    );
  }

  Widget _buildSectionHeader(String title, String? action, VoidCallback? onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.oswald(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (action != null && onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Text(
              action,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  // --- NEW HOME REDESIGN SECTIONS ---

  // 1. Live Matches Section
  Widget _buildLiveMatchesSection(BuildContext context) {
    final matchesAsync = ref.watch(liveMatchesProvider);

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return const SizedBox.shrink(); // Hide live section entirely if no live matches
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Live Matches', 'View All', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MatchCentreScreen()),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              height: 205,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  return _buildLiveMatchCard(context, matches[index]);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLiveMatchCard(BuildContext context, AppMatch match) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      margin: const EdgeInsets.only(right: 14, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1035), Color(0xFF110D2C)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error,
                      ),
                    ).animate(onPlay: (c) => c.repeat()).fadeOut(duration: 600.ms),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE · ${match.statusDisplay}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Live Timer',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          getCountryFlagEmoji(match.homeTeam),
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 6),
                        _buildMiniTeamBadge(match.homeTeamBadge, match.homeTeam),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      match.homeTeam,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                match.scoreDisplay,
                style: GoogleFonts.oswald(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMiniTeamBadge(match.awayTeamBadge, match.awayTeam),
                        const SizedBox(width: 6),
                        Text(
                          getCountryFlagEmoji(match.awayTeam),
                          style: const TextStyle(fontSize: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      match.awayTeam,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlaceBetScreen(match: match)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              minimumSize: const Size(double.infinity, 36),
            ),
            child: Text(
              'QUICK PREDICT',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Upcoming Section
  Widget _buildUpcomingSection(BuildContext context) {
    final matchesAsync = ref.watch(upcomingMatchesProvider);

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return _buildEmptyState('No upcoming fixtures scheduled.');
        }

        return Column(
          children: matches.take(3).map((match) {
            return _buildUpcomingMatchCard(context, match);
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (error, _) => _buildErrorState('Failed to fetch upcoming matches. Tap to retry.', () {
        ref.invalidate(matchesProvider);
      }),
    );
  }

  Widget _buildUpcomingMatchCard(BuildContext context, AppMatch match) {
    final bool isClosed = DateTime.now().isAfter(match.matchDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ROUND · ${match.round}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              MatchCountdownTimer(
                kickoffTime: match.matchDate,
                onFinished: () {
                  setState(() {}); // Rebuild to lock prediction
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(getCountryFlagEmoji(match.homeTeam), style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        match.homeTeam,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'VS',
                style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        match.awayTeam,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(getCountryFlagEmoji(match.awayTeam), style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatMatchDate(match.matchDate)} · ${match.matchTimeIst}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
              ),
              ElevatedButton(
                onPressed: isClosed
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PlaceBetScreen(match: match)),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  minimumSize: const Size(80, 30),
                ),
                child: Text(
                  isClosed ? 'CLOSED' : 'PREDICT',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Trending Matches Section
  Widget _buildTrendingSection(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);

    return matchesAsync.when(
      data: (matches) {
        final trending = List<AppMatch>.from(matches)
          ..sort((a, b) => (b.totalStaked + b.totalBets * 100).compareTo(a.totalStaked + a.totalBets * 100));
        
        final list = trending.where((m) => !m.isCompleted).take(2).toList();
        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          children: list.map((match) {
            return _buildTrendingMatchCard(context, match);
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTrendingMatchCard(BuildContext context, AppMatch match) {
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.trending_up_rounded, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.homeTeam} vs ${match.awayTeam}',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Stake Pool: ₹${(match.totalStaked).toInt()} · ${match.totalBets} bets',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlaceBetScreen(match: match)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(60, 28),
            ),
            child: Text(
              'BET',
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.background),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Community Picks Section
  Widget _buildCommunityPicksSection(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);

    return matchesAsync.when(
      data: (matches) {
        final picks = matches.where((m) => m.homePercentage > 60 || m.awayPercentage > 60).take(2).toList();
        if (picks.isEmpty) {
          return _buildEmptyState('No community picks available right now.');
        }

        return Column(
          children: picks.map((match) {
            final favoriteTeam = match.homePercentage > match.awayPercentage ? match.homeTeam : match.awayTeam;
            final percentage = match.homePercentage > match.awayPercentage ? match.homePercentage : match.awayPercentage;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                gradient: LinearGradient(
                  colors: [AppColors.surface, AppColors.surfaceLight.withValues(alpha: 0.3)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        getCountryFlagEmoji(favoriteTeam),
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$percentage% of users predict $favoriteTeam to win.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fixture: ${match.homeTeam} vs ${match.awayTeam} · ${match.matchTimeIst}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // 5. Stay Updated Section
  Widget _buildStayUpdatedSection() {
    final updates = [
      {
        'title': 'Brazil Midfield Dynamics Shift Predictions',
        'category': 'INSIGHTS',
        'readTime': '3 min read',
        'summary': 'With Neymar and Vinicius Jr. hitting top form, Brazil\'s midfield predictions are soaring. Over 75% of users now back them to top Group D.',
        'icon': Icons.insights_rounded,
        'color': AppColors.primary,
      },
      {
        'title': 'FIFA World Cup 2026 Stadiums Ready',
        'category': 'NEWS',
        'readTime': '5 min read',
        'summary': 'Estadio Azteca in Mexico City has officially completed renovations for the opening matches. Standard stadium capacity is set to break historical records.',
        'icon': Icons.newspaper_rounded,
        'color': AppColors.accent,
      },
      {
        'title': 'Argentina vs Netherlands H2H Rivalry Details',
        'category': 'STATISTICS',
        'readTime': '4 min read',
        'summary': 'Historically, the matches between Argentina and Netherlands have been tight. The last 4 matches ended in draws or 1-goal margins.',
        'icon': Icons.query_stats_rounded,
        'color': AppColors.secondary,
      }
    ];

    return Column(
      children: updates.map((update) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
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
                      color: (update['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      update['category'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: update['color'] as Color,
                      ),
                    ),
                  ),
                  Text(
                    update['readTime'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(update['icon'] as IconData, color: update['color'] as Color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          update['title'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          update['summary'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Common Layout Widgets
  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildErrorState(String text, VoidCallback onRetry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            text,
            style: GoogleFonts.poppins(color: AppColors.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              side: const BorderSide(color: AppColors.error),
              foregroundColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTeamBadge(String? imageUrl, String teamName) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildTextBadge(teamName),
              )
            : _buildTextBadge(teamName),
      ),
    );
  }

  Widget _buildTextBadge(String teamName) {
    return Center(
      child: Text(
        teamName.substring(0, minOf(2, teamName.length)).toUpperCase(),
        style: GoogleFonts.oswald(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
      ),
    );
  }

  int minOf(int a, int b) => a < b ? a : b;

  String _formatMatchDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  Widget _buildTopBettors() {
    return Column(
      children: _topBettors.asMap().entries.map((entry) {
        final index = entry.key;
        final bettor = entry.value;
        final rank = index + 1;
        final rankColor = rank == 1
            ? AppColors.secondary
            : rank == 2
                ? const Color(0xFFC0C0C0)
                : const Color(0xFFCD7F32);
        final gsId = bettor['gs_id'] ?? 'GS-000000';
        final totalStaked = bettor['total_staked'] ?? 0;
        final totalBets = bettor['total_bets'] ?? 0;
        final totalEarned = bettor['total_earned'] ?? 0;
        final winRate = totalBets > 0 ? ((totalEarned / totalStaked) * 100).toInt() : 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: GoogleFonts.oswald(
                      fontSize: 16,
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
                    Text(
                      gsId,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$totalBets bets · $winRate% win',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹$totalStaked',
                style: GoogleFonts.oswald(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlatformStats() {
    final totalBets = _platformStats['total_bets'] ?? 0;
    final totalMatches = _platformStats['total_matches'] ?? 0;
    final totalStaked = (_platformStats['total_amount_staked'] ?? 0).toDouble();
    final totalWon = (_platformStats['total_amount_won'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surfaceLight.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform Statistics',
            style: GoogleFonts.oswald(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Bets', '$totalBets'),
              _buildStatItem('Volume', '₹${(totalStaked / 100000).toStringAsFixed(1)}L'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Matches', '$totalMatches'),
              _buildStatItem('Won', '₹${(totalWon / 100000).toStringAsFixed(1)}L'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.oswald(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// Countdown Timer Widget
class MatchCountdownTimer extends StatefulWidget {
  final DateTime kickoffTime;
  final VoidCallback? onFinished;

  const MatchCountdownTimer({super.key, required this.kickoffTime, this.onFinished});

  @override
  State<MatchCountdownTimer> createState() => _MatchCountdownTimerState();
}

class _MatchCountdownTimerState extends State<MatchCountdownTimer> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    if (now.isAfter(widget.kickoffTime)) {
      _remaining = Duration.zero;
      _timer?.cancel();
      _timer = null;
      widget.onFinished?.call();
    } else {
      _remaining = widget.kickoffTime.difference(now);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return Text(
        'Closed',
        style: GoogleFonts.poppins(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
      );
    }

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    String text = '';
    if (days > 0) text += '${days}d ';
    text += '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Text(
      text,
      style: GoogleFonts.poppins(
        color: AppColors.warning,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// Country Flag Emoji Helper
String getCountryFlagEmoji(String countryName) {
  final cleanName = countryName.toLowerCase().trim();
  switch (cleanName) {
    case 'mexico': return '🇲🇽';
    case 'south africa': return '🇿🇦';
    case 'south korea': return '🇰🇷';
    case 'czech republic': return '🇨🇿';
    case 'canada': return '🇨🇦';
    case 'bosnia-herzegovina': return '🇧🇦';
    case 'usa': return '🇺🇸';
    case 'paraguay': return '🇵🇾';
    case 'brazil': return '🇧🇷';
    case 'morocco': return '🇲🇦';
    case 'qatar': return '🇶🇦';
    case 'switzerland': return '🇨🇭';
    case 'haiti': return '🇭🇹';
    case 'scotland': return '🏴󠁧󠁢󠁳󠁣󠁴󠁿';
    case 'germany': return '🇩🇪';
    case 'curaçao': return '🇨🇼';
    case 'ivory coast': return '🇨🇮';
    case 'ecuador': return '🇪🇨';
    case 'netherlands': return '🇳🇱';
    case 'japan': return '🇯🇵';
    case 'australia': return '🇦🇺';
    case 'turkey': return '🇹🇷';
    case 'belgium': return '🇧🇪';
    case 'egypt': return '🇪🇬';
    case 'saudi arabia': return '🇸🇦';
    case 'uruguay': return '🇺🇾';
    case 'cape verde': return '🇨🇻';
    case 'sweden': return '🇸🇪';
    case 'tunisia': return '🇹🇳';
    case 'argentina': return '🇦🇷';
    case 'france': return '🇫🇷';
    case 'spain': return '🇪🇸';
    case 'portugal': return '🇵🇹';
    case 'england': return '🏴󠁧󠁢󠁥󠁮󠁧󠁿';
    case 'italy': return '🇮🇹';
    default: return '🏳️';
  }
}
