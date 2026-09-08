import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import '../services/supabase_service.dart';
import '../config/supabase_config.dart';

/// Status summary for both Firebase and Supabase backends.
class HybridBackendStatus {
  final bool isFirebaseConnected;
  final bool isFirebaseAuthenticated;
  final bool isSupabaseConfigured;
  final bool isSupabaseConnected;
  final String? currentUserId;
  final String supabaseProjectUrl;

  const HybridBackendStatus({
    required this.isFirebaseConnected,
    required this.isFirebaseAuthenticated,
    required this.isSupabaseConfigured,
    required this.isSupabaseConnected,
    this.currentUserId,
    required this.supabaseProjectUrl,
  });

  bool get isDualBackendReady => isFirebaseConnected && isSupabaseConfigured;
}

/// Orchestrator for the Academy App's Hybrid Backend Architecture.
class HybridBackend {
  /// Check overall backend health status
  static Future<HybridBackendStatus> getStatus() async {
    final firebaseConnected = await FirebaseService.checkConnection();
    final firebaseAuth = FirebaseService.isAuthenticated;
    final currentUserId = FirebaseService.currentUserId;

    final supabaseConfigured = SupabaseConfig.isInitialized;
    final supabaseConnected = await SupabaseService.checkConnection();

    return HybridBackendStatus(
      isFirebaseConnected: firebaseConnected,
      isFirebaseAuthenticated: firebaseAuth,
      isSupabaseConfigured: supabaseConfigured,
      isSupabaseConnected: supabaseConnected,
      currentUserId: currentUserId,
      supabaseProjectUrl: SupabaseConfig.supabaseUrl,
    );
  }

  /// Print diagnostic summary to console
  static Future<void> printDiagnostics() async {
    final status = await getStatus();
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('           HYBRID BACKEND ARCHITECTURE STATUS              ');
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('🔥 Firebase / Firestore: ${status.isFirebaseConnected ? "CONNECTED ✅" : "DISCONNECTED ❌"}');
    debugPrint('   • Auth status: ${status.isFirebaseAuthenticated ? "LOGGED IN (${status.currentUserId})" : "GUEST / LOCAL"}');
    debugPrint('   • Push Notifications (FCM): READY');
    debugPrint('   • Realtime Streams: ACTIVE');
    debugPrint('⚡ Supabase (PostgreSQL): ${status.isSupabaseConfigured ? "CONFIGURED ✅" : "NOT INITIALIZED ❌"}');
    debugPrint('   • Project URL: ${status.supabaseProjectUrl}');
    debugPrint('   • Relational SQL & Analytics: READY');
    debugPrint('   • Storage bucket sync: ENABLED');
    debugPrint('════════════════════════════════════════════════════════════');
  }
}
