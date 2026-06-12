import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/auth_provider.dart';
import '../utils/file_storage.dart';

class SocialService {
  final Ref _ref;
  static const String _cacheFileName = 'public_predictions_cache.json';
  final FileStorage _storage = FileStorage();

  SocialService(this._ref);

  // Write to local cache
  Future<void> _writeToCache(List<Map<String, dynamic>> posts) async {
    try {
      await _storage.writeCache(_cacheFileName, json.encode(posts));
    } catch (e) {
      debugPrint('Error saving social feed cache: $e');
    }
  }

  // Read from local cache
  Future<List<Map<String, dynamic>>> _readFromCache() async {
    try {
      final content = await _storage.readCache(_cacheFileName);
      if (content != null) {
        final list = json.decode(content) as List;
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (e) {
      debugPrint('Error reading social feed cache: $e');
    }
    // Return empty list initially or some nice default community posts
    return _getDefaultFeedPosts();
  }

  // Get feed posts (tries Supabase, falls back to local cache)
  Future<List<Map<String, dynamic>>> getPosts() async {
    try {
      final supabase = _ref.read(supabaseServiceProvider);
      final response = await supabase.client
          .from('public_predictions')
          .select()
          .order('created_at', ascending: false);
      
      final postsList = List<Map<String, dynamic>>.from(response);
      await _writeToCache(postsList);
      return postsList;
    } catch (e) {
      debugPrint('Supabase public_predictions table not found or query failed ($e). Falling back to local cache.');
      return await _readFromCache();
    }
  }

  // Create new public prediction post
  Future<void> createPost({
    required String userId,
    required String gsId,
    required String fullName,
    required String text,
    required String homeTeam,
    required String awayTeam,
    required int homeScore,
    required int awayScore,
  }) async {
    final newPost = {
      'id': const Uuid().v4(),
      'user_id': userId,
      'gs_id': gsId,
      'full_name': fullName,
      'prediction_text': text,
      'home_team': homeTeam,
      'away_team': awayTeam,
      'home_score_pred': homeScore,
      'away_score_pred': awayScore,
      'likes_count': 0,
      'liked_by_users': <String>[],
      'comments': <Map<String, dynamic>>[],
      'shares_count': 0,
      'created_at': DateTime.now().toIso8601String(),
      'is_featured': false,
    };

    try {
      final supabase = _ref.read(supabaseServiceProvider);
      await supabase.client.from('public_predictions').insert(newPost);
      debugPrint('Post saved in Supabase public_predictions.');
    } catch (e) {
      debugPrint('Failed to save post in Supabase ($e). Saving locally on device.');
      final localPosts = await _readFromCache();
      localPosts.insert(0, newPost);
      await _writeToCache(localPosts);
    }
  }

  // Toggle Like on a post
  Future<void> toggleLike(String postId, String userId) async {
    try {
      final supabase = _ref.read(supabaseServiceProvider);
      final postResponse = await supabase.client
          .from('public_predictions')
          .select('liked_by_users, likes_count')
          .eq('id', postId)
          .single();

      final likedBy = List<String>.from(postResponse['liked_by_users'] ?? []);
      int likesCount = postResponse['likes_count'] ?? 0;

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        likesCount = (likesCount - 1).clamp(0, 999999);
      } else {
        likedBy.add(userId);
        likesCount++;
      }

      await supabase.client.from('public_predictions').update({
        'liked_by_users': likedBy,
        'likes_count': likesCount,
      }).eq('id', postId);
    } catch (e) {
      debugPrint('Like sync failed ($e). Toggling locally.');
      final localPosts = await _readFromCache();
      final postIndex = localPosts.indexWhere((p) => p['id'] == postId);
      if (postIndex != -1) {
        final post = localPosts[postIndex];
        final likedBy = List<String>.from(post['liked_by_users'] ?? []);
        int likesCount = post['likes_count'] ?? 0;

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          likesCount = (likesCount - 1).clamp(0, 999999);
        } else {
          likedBy.add(userId);
          likesCount++;
        }

        localPosts[postIndex] = {
          ...post,
          'liked_by_users': likedBy,
          'likes_count': likesCount,
        };
        await _writeToCache(localPosts);
      }
    }
  }

  // Add Comment to a post
  Future<void> addComment({
    required String postId,
    required String userId,
    required String gsId,
    required String fullName,
    required String commentText,
  }) async {
    final newComment = {
      'id': const Uuid().v4(),
      'user_id': userId,
      'gs_id': gsId,
      'full_name': fullName,
      'comment_text': commentText,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final supabase = _ref.read(supabaseServiceProvider);
      final postResponse = await supabase.client
          .from('public_predictions')
          .select('comments')
          .eq('id', postId)
          .single();

      final comments = List<Map<String, dynamic>>.from(postResponse['comments'] ?? []);
      comments.add(newComment);

      await supabase.client.from('public_predictions').update({
        'comments': comments,
      }).eq('id', postId);
    } catch (e) {
      debugPrint('Comment sync failed ($e). Adding locally.');
      final localPosts = await _readFromCache();
      final postIndex = localPosts.indexWhere((p) => p['id'] == postId);
      if (postIndex != -1) {
        final post = localPosts[postIndex];
        final comments = List<Map<String, dynamic>>.from(post['comments'] ?? []);
        comments.add(newComment);

        localPosts[postIndex] = {
          ...post,
          'comments': comments,
        };
        await _writeToCache(localPosts);
      }
    }
  }

  // Increment Share Count
  Future<void> incrementShare(String postId) async {
    try {
      final supabase = _ref.read(supabaseServiceProvider);
      final postResponse = await supabase.client
          .from('public_predictions')
          .select('shares_count')
          .eq('id', postId)
          .single();

      final shares = (postResponse['shares_count'] ?? 0) + 1;

      await supabase.client.from('public_predictions').update({
        'shares_count': shares,
      }).eq('id', postId);
    } catch (e) {
      debugPrint('Share count increment failed ($e). Simulating locally.');
      final localPosts = await _readFromCache();
      final postIndex = localPosts.indexWhere((p) => p['id'] == postId);
      if (postIndex != -1) {
        final post = localPosts[postIndex];
        final shares = (post['shares_count'] ?? 0) + 1;
        localPosts[postIndex] = {
          ...post,
          'shares_count': shares,
        };
        await _writeToCache(localPosts);
      }
    }
  }

  List<Map<String, dynamic>> _getDefaultFeedPosts() {
    return [
      {
        'id': 'post-1',
        'user_id': 'default-user-1',
        'gs_id': 'GS654321',
        'full_name': 'Cristiano R.',
        'prediction_text': "Brazil's midfield is stronger. Brazil 2–1 Spain.",
        'home_team': 'Brazil',
        'away_team': 'Spain',
        'home_score_pred': 2,
        'away_score_pred': 1,
        'likes_count': 14,
        'liked_by_users': ['some-id'],
        'comments': [
          {
            'id': 'c-1',
            'user_id': 'default-user-2',
            'gs_id': 'GS123456',
            'full_name': 'Leo M.',
            'comment_text': 'I disagree, Spain\'s possession play will dominate. Spain 1-0.',
            'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          }
        ],
        'shares_count': 3,
        'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        'is_featured': true,
      },
      {
        'id': 'post-2',
        'user_id': 'default-user-3',
        'gs_id': 'GS987654',
        'full_name': 'Kylian M.',
        'prediction_text': 'Mexico has the home advantage at Azteca. Mexico 2-0 South Africa.',
        'home_team': 'Mexico',
        'away_team': 'South Africa',
        'home_score_pred': 2,
        'away_score_pred': 0,
        'likes_count': 28,
        'liked_by_users': <String>[],
        'comments': <Map<String, dynamic>>[],
        'shares_count': 7,
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'is_featured': false,
      }
    ];
  }
}

final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService(ref);
});
