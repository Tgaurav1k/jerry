import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bridges Firebase phone OTP verification with Supabase session creation.
class PhoneAuthService {
  static FirebaseAuth get _firebase => FirebaseAuth.instance;
  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Step 1 — Send SMS OTP via Firebase.
  static Future<void> sendOtp({
    required String phone,                   // e.g. "+919876543210"
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    await _firebase.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (_) {},         // auto-verify on some Android devices
      verificationFailed: (e) => onError(e.message ?? 'Verification failed'),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Step 2 — Verify OTP with Firebase, then create/restore Supabase session.
  /// [fullName] and [role] are only required for new (signup) users.
  static Future<AuthResponse> verifyOtpAndGetSupabaseSession({
    required String verificationId,
    required String smsCode,
    String? fullName,
    String? role,
  }) async {
    // Firebase: exchange SMS code for a credential
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final fbResult = await _firebase.signInWithCredential(credential);
    final fbUser   = fbResult.user!;
    final idToken  = await fbUser.getIdToken();

    // Supabase Edge Function: verify Firebase token → return Supabase session
    final fnResponse = await _supabase.functions.invoke(
      'firebase-phone-signin',
      body: <String, dynamic>{
        'firebaseToken': idToken,
        if (fullName != null) 'fullName': fullName,
        if (role    != null) 'role':     role,
        'phone': fbUser.phoneNumber ?? '',
      },
    );

    if (fnResponse.status != 200) {
      final msg = (fnResponse.data as Map<String, dynamic>?)?['error'] ?? 'Phone sign-in failed';
      throw Exception(msg);
    }

    // Restore the Supabase session returned by the Edge Function.
    // fnResponse.data is { user: {...}, session: {...} } — recoverSession
    // needs only the session object with access_token at root level.
    final data = fnResponse.data as Map<String, dynamic>;
    final sessionMap = data['session'] as Map<String, dynamic>;
    return await _supabase.auth.recoverSession(jsonEncode(sessionMap));
  }
}
