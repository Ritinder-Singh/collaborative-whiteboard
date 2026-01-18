import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// User model for authentication
class User {
  final String id;
  final String? email;
  final String displayName;
  final String? avatarUrl;
  final bool isAnonymous;

  User({
    required this.id,
    this.email,
    required this.displayName,
    this.avatarUrl,
    required this.isAnonymous,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String?,
        displayName: json['display_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        isAnonymous: json['is_anonymous'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'is_anonymous': isAnonymous,
      };
}

/// Authentication service for user management
class AuthService {
  final String baseUrl;
  String? _accessToken;
  User? _currentUser;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  AuthService({required this.baseUrl});

  String? get accessToken => _accessToken;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;

  /// Initialize the service by loading stored credentials
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _currentUser = User.fromJson(jsonDecode(userJson));
    }

    // Verify token is still valid
    if (_accessToken != null) {
      try {
        await getMe();
      } catch (e) {
        await logout();
      }
    }
  }

  /// Save credentials to local storage
  Future<void> _saveCredentials(String token, User user) async {
    _accessToken = token;
    _currentUser = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// Clear credentials from local storage
  Future<void> _clearCredentials() async {
    _accessToken = null;
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Get authorization headers
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// Register a new user with email and password
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw AuthException(error['detail'] ?? 'Registration failed');
    }

    final data = jsonDecode(response.body);
    final token = data['access_token'] as String;
    final user = User.fromJson(data['user']);

    await _saveCredentials(token, user);
    return user;
  }

  /// Login with email and password
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw AuthException(error['detail'] ?? 'Login failed');
    }

    final data = jsonDecode(response.body);
    final token = data['access_token'] as String;
    final user = User.fromJson(data['user']);

    await _saveCredentials(token, user);
    return user;
  }

  /// Join anonymously with just a display name
  Future<User> anonymousJoin({required String displayName}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/anonymous'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'display_name': displayName,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw AuthException(error['detail'] ?? 'Anonymous join failed');
    }

    final data = jsonDecode(response.body);
    final token = data['access_token'] as String;
    final user = User.fromJson(data['user']);

    await _saveCredentials(token, user);
    return user;
  }

  /// Convert anonymous user to registered user
  Future<User> convertToRegistered({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_accessToken == null) {
      throw AuthException('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/convert'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw AuthException(error['detail'] ?? 'Conversion failed');
    }

    final data = jsonDecode(response.body);
    final token = data['access_token'] as String;
    final user = User.fromJson(data['user']);

    await _saveCredentials(token, user);
    return user;
  }

  /// Get current user profile
  Future<User> getMe() async {
    if (_accessToken == null) {
      throw AuthException('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw AuthException('Failed to get user profile');
    }

    final user = User.fromJson(jsonDecode(response.body));
    _currentUser = user;
    return user;
  }

  /// Update current user profile
  Future<User> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    if (_accessToken == null) {
      throw AuthException('Not authenticated');
    }

    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    final response = await http.patch(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw AuthException(error['detail'] ?? 'Update failed');
    }

    final user = User.fromJson(jsonDecode(response.body));
    await _saveCredentials(_accessToken!, user);
    return user;
  }

  /// Logout
  Future<void> logout() async {
    await _clearCredentials();
  }
}

/// Authentication exception
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
