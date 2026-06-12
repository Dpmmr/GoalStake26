import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../shared/models/match.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/matches_provider.dart';
import '../../shared/services/social_service.dart';
import 'home_screen.dart'; // for flag helper

class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  final _postController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final feed = await ref.read(socialServiceProvider).getPosts();
      if (mounted) {
        setState(() {
          _posts = feed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCreatePostDialog() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to write a prediction post', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CreatePostWidget(
        onPostCreated: () {
          _loadFeed();
        },
      ),
    );
  }

  void _likePost(String postId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await ref.read(socialServiceProvider).toggleLike(postId, user.id);
    _refreshPostLocally(postId, (post) {
      final likedBy = List<String>.from(post['liked_by_users'] ?? []);
      int likes = post['likes_count'] ?? 0;
      if (likedBy.contains(user.id)) {
        likedBy.remove(user.id);
        likes = (likes - 1).clamp(0, 999999);
      } else {
        likedBy.add(user.id);
        likes++;
      }
      return {
        ...post,
        'liked_by_users': likedBy,
        'likes_count': likes,
      };
    });
  }

  void _refreshPostLocally(String postId, Map<String, dynamic> Function(Map<String, dynamic>) updater) {
    if (!mounted) return;
    setState(() {
      final idx = _posts.indexWhere((p) => p['id'] == postId);
      if (idx != -1) {
        _posts[idx] = updater(_posts[idx]);
      }
    });
  }

  void _openCommentsDialog(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CommentsSheetWidget(
        post: post,
        onCommentAdded: (updatedComments) {
          _refreshPostLocally(post['id'], (p) => {...p, 'comments': updatedComments});
        },
      ),
    );
  }

  void _sharePost(Map<String, dynamic> post) {
    final cleanHome = post['home_team'] ?? '';
    final cleanAway = post['away_team'] ?? '';
    final homeScore = post['home_score_pred'] ?? 0;
    final awayScore = post['away_score_pred'] ?? 0;
    final textContent = post['prediction_text'] ?? '';

    final shareText = "I predicted $cleanHome $homeScore–$awayScore $cleanAway on GOALSTAKE 26.\n"
        "\"$textContent\"\n"
        "Think I'm right? Join the action!";

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SHARE PREDICTION', style: GoogleFonts.oswald(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareOption(
                  Icons.chat_bubble_rounded,
                  'WhatsApp',
                  const Color(0xFF25D366),
                  () async {
                    Navigator.pop(context);
                    final url = 'https://wa.me/?text=${Uri.encodeComponent(shareText)}';
                    try {
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    } catch (e) {
                      debugPrint('Error launching WhatsApp: $e');
                    }
                    await ref.read(socialServiceProvider).incrementShare(post['id']);
                    _refreshPostLocally(post['id'], (p) => {...p, 'shares_count': (p['shares_count'] ?? 0) + 1});
                  },
                ),
                _buildShareOption(
                  Icons.send_rounded,
                  'Telegram',
                  const Color(0xFF0088cc),
                  () async {
                    Navigator.pop(context);
                    final url = 'https://t.me/share/url?url=${Uri.encodeComponent(shareText)}';
                    try {
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    } catch (e) {
                      debugPrint('Error launching Telegram: $e');
                    }
                    await ref.read(socialServiceProvider).incrementShare(post['id']);
                    _refreshPostLocally(post['id'], (p) => {...p, 'shares_count': (p['shares_count'] ?? 0) + 1});
                  },
                ),
                _buildShareOption(
                  Icons.close_rounded,
                  'X / Twitter',
                  const Color(0xFF1DA1F2),
                  () async {
                    Navigator.pop(context);
                    final url = 'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(shareText)}';
                    try {
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    } catch (e) {
                      debugPrint('Error launching X: $e');
                    }
                    await ref.read(socialServiceProvider).incrementShare(post['id']);
                    _refreshPostLocally(post['id'], (p) => {...p, 'shares_count': (p['shares_count'] ?? 0) + 1});
                  },
                ),
                _buildShareOption(
                  Icons.share_rounded,
                  'System',
                  AppColors.primary,
                  () async {
                    Navigator.pop(context);
                    try {
                      await Share.share(shareText);
                    } catch (e) {
                      debugPrint('Error using Native Share: $e');
                    }
                    await ref.read(socialServiceProvider).incrementShare(post['id']);
                    _refreshPostLocally(post['id'], (p) => {...p, 'shares_count': (p['shares_count'] ?? 0) + 1});
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'COMMUNITY FEED',
          style: GoogleFonts.oswald(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: AppColors.background,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadFeed,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final isLiked = user != null && List<String>.from(post['liked_by_users'] ?? []).contains(user.id);
                  return _buildFeedItem(post, isLiked);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreatePostDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        child: const Icon(Icons.add_comment_rounded, size: 24),
      ),
    );
  }

  Widget _buildFeedItem(Map<String, dynamic> post, bool isLiked) {
    final commentsList = List<dynamic>.from(post['comments'] ?? []);
    final timeAgo = _getTimeAgo(DateTime.parse(post['created_at']));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post['full_name'] ?? 'Bettor',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        if (post['is_featured'] == true) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text('FEATURED', style: GoogleFonts.poppins(fontSize: 8, color: AppColors.secondary, fontWeight: FontWeight.bold)),
                          ),
                        ]
                      ],
                    ),
                    Text(
                      '${post['gs_id']} · $timeAgo',
                      style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Attached Prediction Display
          if (post['home_team'] != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(getCountryFlagEmoji(post['home_team']), style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(post['home_team'], style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      'Predicted: ${post['home_score_pred']} – ${post['away_score_pred']}',
                      style: GoogleFonts.oswald(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  Row(
                    children: [
                      Text(post['away_team'], style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text(getCountryFlagEmoji(post['away_team']), style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),

          Text(
            post['prediction_text'] ?? '',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),

          // Like, Comment, Share Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => _likePost(post['id']),
                icon: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? AppColors.error : AppColors.textMuted,
                      size: 20,
                    ).animate(target: isLiked ? 1.0 : 0.0).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 200.ms),
                    const SizedBox(width: 6),
                    Text(
                      '${post['likes_count']}',
                      style: GoogleFonts.poppins(fontSize: 12, color: isLiked ? AppColors.error : AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openCommentsDialog(post),
                icon: Row(
                  children: [
                    const Icon(Icons.mode_comment_outlined, color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '${commentsList.length}',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _sharePost(post),
                icon: Row(
                  children: [
                    const Icon(Icons.share_outlined, color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '${post['shares_count'] ?? 0}',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

// --- SHEET FOR CREATING POST ---
class _CreatePostWidget extends ConsumerStatefulWidget {
  final VoidCallback onPostCreated;

  const _CreatePostWidget({required this.onPostCreated});

  @override
  ConsumerState<_CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends ConsumerState<_CreatePostWidget> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _homeScoreController = TextEditingController(text: '0');
  final _awayScoreController = TextEditingController(text: '0');
  AppMatch? _selectedMatch;
  bool _isPosting = false;

  @override
  void dispose() {
    _textController.dispose();
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  void _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please attach a match to your prediction', style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    final appUser = ref.read(appUserProvider).value;
    if (user == null || appUser == null) return;

    setState(() => _isPosting = true);

    try {
      await ref.read(socialServiceProvider).createPost(
            userId: user.id,
            gsId: appUser.bettorId,
            fullName: appUser.fullName,
            text: _textController.text,
            homeTeam: _selectedMatch!.homeTeam,
            awayTeam: _selectedMatch!.awayTeam,
            homeScore: int.parse(_homeScoreController.text),
            awayScore: int.parse(_awayScoreController.text),
          );

      if (mounted) {
        setState(() => _isPosting = false);
        Navigator.pop(context);
        widget.onPostCreated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(upcomingMatchesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('POST PUBLIC PREDICTION', style: GoogleFonts.oswald(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Match Selector
              matchesAsync.when(
                data: (matches) {
                  return DropdownButtonFormField<AppMatch>(
                    decoration: const InputDecoration(labelText: 'Attach Upcoming Match'),
                    items: matches.map((m) {
                      return DropdownMenuItem<AppMatch>(
                        value: m,
                        child: Text('${m.homeTeam} vs ${m.awayTeam} (${m.matchTimeIst})', style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedMatch = val);
                    },
                    validator: (val) => val == null ? 'Attach a match' : null,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading matches'),
              ),
              const SizedBox(height: 16),

              if (_selectedMatch != null) ...[
                // Predicted Score Inputs
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _homeScoreController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: '${_selectedMatch!.homeTeam} Score'),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text('—', style: GoogleFonts.oswald(fontSize: 20, color: AppColors.textMuted)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: TextFormField(
                        controller: _awayScoreController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: '${_selectedMatch!.awayTeam} Score'),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Prediction text
              TextFormField(
                controller: _textController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Analysis / Thoughts',
                  hintText: "Example: Brazil's midfield is stronger. Brazil 2-1 Spain.",
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Thoughts required' : null,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _submitPost,
                  child: _isPosting
                      ? const CircularProgressIndicator()
                      : Text('POST PREDICTION', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --- SHEET FOR COMMENTS ---
class _CommentsSheetWidget extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;
  final Function(List<Map<String, dynamic>>) onCommentAdded;

  const _CommentsSheetWidget({required this.post, required this.onCommentAdded});

  @override
  ConsumerState<_CommentsSheetWidget> createState() => _CommentsSheetWidgetState();
}

class _CommentsSheetWidgetState extends ConsumerState<_CommentsSheetWidget> {
  final _commentController = TextEditingController();
  late List<Map<String, dynamic>> _comments;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _comments = List<Map<String, dynamic>>.from(widget.post['comments'] ?? []);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final appUser = ref.read(appUserProvider).value;
    if (user == null || appUser == null) return;

    setState(() => _isSending = true);

    try {
      await ref.read(socialServiceProvider).addComment(
            postId: widget.post['id'],
            userId: user.id,
            gsId: appUser.bettorId,
            fullName: appUser.fullName,
            commentText: text,
          );

      if (mounted) {
        final newComment = {
          'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
          'user_id': user.id,
          'gs_id': appUser.bettorId,
          'full_name': appUser.fullName,
          'comment_text': text,
          'created_at': DateTime.now().toIso8601String(),
        };
        setState(() {
          _comments.add(newComment);
          _commentController.clear();
          _isSending = false;
        });
        widget.onCommentAdded(_comments);
      }
    } catch (e) {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('COMMENTS (${_comments.length})', style: GoogleFonts.oswald(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Expanded(
              child: _comments.isEmpty
                  ? Center(child: Text('No comments yet.', style: GoogleFonts.poppins(color: AppColors.textMuted)))
                  : ListView.builder(
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(comment['full_name'] ?? 'User', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text(comment['gs_id'] ?? '', style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textMuted)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(comment['comment_text'] ?? '', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),

            // Comment Input
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _commentController,
                    decoration: const InputDecoration(hintText: 'Add a comment...', contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSending ? null : _postComment,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: _isSending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: AppColors.background, size: 20),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
