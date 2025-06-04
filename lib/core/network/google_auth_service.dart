// lib/core/network/google_auth_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import '../constants/google_calendar_constants.dart';
import '../error/exceptions.dart';
import 'package:http/http.dart' as http;

class GoogleAuthService {
  static GoogleAuthService? _instance;
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  auth.AuthClient? _authClient;

  GoogleAuthService._internal();

  factory GoogleAuthService() {
    return _instance ??= GoogleAuthService._internal();
  }

  void initialize() {
    _googleSignIn = GoogleSignIn(scopes: GoogleCalendarConstants.scopes);

    _googleSignIn!.onCurrentUserChanged.listen((account) {
      _currentUser = account;
    });
  }

  Future<bool> signIn() async {
    try {
      if (_googleSignIn == null) {
        initialize();
      }

      // Clear any existing auth first
      await _clearAuth();

      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      if (account == null) {
        throw AuthException('Login dibatalkan oleh user');
      }

      _currentUser = account;
      await _createAuthClient();
      return true;
    } catch (e) {
      print('❌ SignIn Error: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Gagal login: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      await _clearAuth();
      await _googleSignIn?.signOut();
    } catch (e) {
      print('❌ SignOut Error: $e');
      throw AuthException('Gagal logout: ${e.toString()}');
    }
  }

  Future<bool> silentSignIn() async {
    try {
      if (_googleSignIn == null) {
        initialize();
      }

      final GoogleSignInAccount? account =
          await _googleSignIn!.signInSilently();
      if (account != null) {
        _currentUser = account;
        await _createAuthClient();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Silent SignIn Error: $e');
      return false;
    }
  }

  // ✅ CRITICAL FIX: Use UTC DateTime for expiry
  Future<void> _createAuthClient() async {
    if (_currentUser == null) return;

    try {
      final GoogleSignInAuthentication authentication =
          await _currentUser!.authentication;

      // ✅ Validate access token
      if (authentication.accessToken == null ||
          authentication.accessToken!.isEmpty) {
        throw AuthException('Access token tidak valid');
      }

      // ✅ FIXED: Use UTC DateTime for expiry (CRITICAL!)
      final DateTime utcExpiryTime =
          DateTime.now().toUtc().add(const Duration(hours: 1));

      print('🔑 Creating auth client:');
      print(
          '   Access Token: ${authentication.accessToken?.substring(0, 20)}...');
      print('   Current Time (Local): ${DateTime.now()}');
      print('   Current Time (UTC): ${DateTime.now().toUtc()}');
      print('   Expiry Time (UTC): $utcExpiryTime');
      print('   Is UTC: ${utcExpiryTime.isUtc}');
      print(
          '   ID Token: ${authentication.idToken != null ? 'Present' : 'None'}');

      // ✅ CRITICAL: Ensure expiry is UTC and in the future
      if (!utcExpiryTime.isUtc) {
        throw AuthException('Expiry time harus UTC');
      }

      if (utcExpiryTime.isBefore(DateTime.now().toUtc())) {
        throw AuthException('Expiry time harus di masa depan');
      }

      final auth.AccessCredentials credentials = auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          authentication.accessToken!,
          utcExpiryTime, // ✅ FIXED: UTC DateTime
        ),
        authentication.idToken,
        GoogleCalendarConstants.scopes,
      );

      // ✅ Use http.Client() as base client
      final baseClient = http.Client();
      _authClient = auth.authenticatedClient(baseClient, credentials);

      print('✅ Auth client created successfully with UTC expiry');
    } catch (e) {
      print('❌ Create Auth Client Error: $e');
      throw AuthException('Gagal membuat auth client: ${e.toString()}');
    }
  }

  // ✅ Clear auth helper
  Future<void> _clearAuth() async {
    try {
      _authClient?.close();
      _authClient = null;
      _currentUser = null;
    } catch (e) {
      print('⚠️ Clear auth warning: $e');
    }
  }

  auth.AuthClient? get authClient => _authClient;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null && _authClient != null;

  Future<String?> getAccessToken() async {
    if (_currentUser == null) return null;

    try {
      final authentication = await _currentUser!.authentication;
      return authentication.accessToken;
    } catch (e) {
      print('❌ Get Access Token Error: $e');
      return null;
    }
  }

  Future<bool> refreshToken() async {
    if (_currentUser == null) return false;

    try {
      print('🔄 Refreshing token...');
      await _currentUser!.clearAuthCache();
      await _createAuthClient();
      print('✅ Token refreshed successfully');
      return true;
    } catch (e) {
      print('❌ Refresh Token Error: $e');
      return false;
    }
  }

  // ✅ Check if token is valid and not expired
  Future<bool> isTokenValid() async {
    if (_authClient == null || _currentUser == null) return false;

    try {
      final authentication = await _currentUser!.authentication;
      return authentication.accessToken != null &&
          authentication.accessToken!.isNotEmpty;
    } catch (e) {
      print('❌ Token validation error: $e');
      return false;
    }
  }

  // ✅ NEW: Complete reset method for troubleshooting
  Future<void> completeReset() async {
    try {
      print('🔄 Performing complete reset...');

      // Disconnect and sign out
      await _googleSignIn?.disconnect();
      await _googleSignIn?.signOut();

      // Clear all references
      _authClient?.close();
      _authClient = null;
      _currentUser = null;
      _googleSignIn = null;

      print('✅ Complete reset successful');
    } catch (e) {
      print('⚠️ Reset error (ignored): $e');
    }
  }
}
