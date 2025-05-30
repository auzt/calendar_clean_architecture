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

      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      if (account == null) {
        throw AuthException('Login dibatalkan oleh user');
      }

      _currentUser = account;
      await _createAuthClient();
      return true;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Gagal login: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      _currentUser = null;
      _authClient = null;
    } catch (e) {
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
      return false;
    }
  }

  // Ganti method _createAuthClient():
  Future<void> _createAuthClient() async {
    if (_currentUser == null) return;

    try {
      final GoogleSignInAuthentication authentication =
          await _currentUser!.authentication;

      final auth.AccessCredentials credentials = auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          authentication.accessToken!,
          DateTime.now().add(const Duration(hours: 1)),
        ),
        authentication.idToken,
        GoogleCalendarConstants.scopes,
      );

      // Gunakan http.Client() sebagai base client
      final baseClient = http.Client();
      _authClient = auth.authenticatedClient(baseClient, credentials);
    } catch (e) {
      throw AuthException('Gagal membuat auth client: ${e.toString()}');
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
      return null;
    }
  }

  Future<bool> refreshToken() async {
    if (_currentUser == null) return false;

    try {
      await _currentUser!.clearAuthCache();
      await _createAuthClient();
      return true;
    } catch (e) {
      return false;
    }
  }
}
