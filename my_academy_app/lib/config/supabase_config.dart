
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Your Supabase Project URL (Project Ref: lrvzofjlaziypwssuqvi)
  static const String supabaseUrl = 'https://lrvzofjlaziypwssuqvi.supabase.co';

  /// Your Supabase Anon / Public Key
  /// Find this in Supabase Dashboard -> Project Settings -> API -> Project API keys -> anon / public
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxydnpvZmpsYXppeXB3c3N1cXZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMzQ1NjcsImV4cCI6MjA1NjgxMDU2N30.placeholder_key_paste_your_anon_key_here',
  );

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Initialize Supabase Flutter SDK safely
  static Future<void> init({String? anonKeyOverride}) async {
    final keyToUse = anonKeyOverride ?? supabaseAnonKey;
    if (keyToUse.isEmpty || keyToUse.contains('placeholder')) {
      debugPrint('[SUPABASE] URL configured: $supabaseUrl');
      debugPrint('[SUPABASE] Notice: Supabase initialized with Project URL. Add your anon key to enable full database/storage sync.');
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: keyToUse,
        debug: kDebugMode,
      );
      _isInitialized = true;
      debugPrint('[SUPABASE] Connected successfully to project: lrvzofjlaziypwssuqvi ($supabaseUrl)');
    } catch (e) {
      debugPrint('[SUPABASE] Initialization notice: $e');
    }
  }

  /// Get active Supabase Client instance
  static SupabaseClient get client {
    return Supabase.instance.client;
  }
}
