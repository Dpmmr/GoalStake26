import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/user.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return supabase.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session?.user,
    loading: () => null,
    error: (_, __) => null,
  );
});

final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  
  final supabase = ref.watch(supabaseServiceProvider);
  return supabase.getUser(user.id);
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseService _supabase;
  
  AuthNotifier(this._supabase) : super(const AsyncValue.data(null));
  
  Future<void> sendOtp(String phone) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.sendOtp(phone);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> verifyOtp(String phone, String otp) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase.signInWithPhone(phone, otp);
      if (response.user != null) {
        // Check if user exists in our users table
        final existingUser = await _supabase.getUserByPhone(phone);
        if (existingUser == null) {
          // Create new user
          final gsId = 'GS${phone.substring(phone.length - 6)}';
          await _supabase.createUser(
            phone: phone,
            fullName: 'User ${phone.substring(phone.length - 4)}',
            gsId: gsId,
          );
        }
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _supabase.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return AuthNotifier(supabase);
});
