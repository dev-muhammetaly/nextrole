import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:job_portal/core/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supaBaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supaBaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authState = ref.watch(authStateStreamProvider).value;
  final session = authState?.session;

  if (session == null) {
    return null;
  }

  final supabase = ref.watch(supaBaseClientProvider);

  try {
    final response = await supabase
        .from('profiles')
        .select()
        .eq('id', session.user.id)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromJson(response);
  } catch (e) {
    return null;
  }
});

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Sign In with Email & Password
  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final supabase = ref.read(supaBaseClientProvider);
      await supabase.auth.signInWithPassword(email: email, password: password);
    });
  }

  /// Sign Up with Email, Password & Selected Role
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? companyName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final supabase = ref.read(supaBaseClientProvider);
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role.toDbString(),
          if (companyName != null && companyName.isNotEmpty)
            'company_name': companyName,
        },
      );
    });
  }

  /// Sign Out
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final supabase = ref.read(supaBaseClientProvider);
      await supabase.auth.signOut();
    });
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
