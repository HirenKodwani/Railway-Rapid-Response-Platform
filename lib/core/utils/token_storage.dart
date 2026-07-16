import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'dart:async';

/// Secure token and user data storage using flutter_secure_storage.
/// Also mirrors data to SharedPreferences so the background isolate
/// can read credentials without needing the Android Keystore.
class TokenStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Secure Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // SharedPreferences keys (for background isolate access)
  static const String _bgTokenKey = 'bg_auth_token';
  static const String _bgUserKey = 'bg_user_data';

  /// Save JWT token securely + mirror to SharedPreferences for background service
  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token).timeout(const Duration(seconds: 3));
    } catch (e) {
      // Ignore
    }
    // Always save to SharedPreferences — background isolates can't access Keystore
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bgTokenKey, token);
    } catch (e) {
      // Ignore
    }
  }

  /// Get stored JWT token (foreground only)
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey).timeout(const Duration(seconds: 3));
    } catch (e) {
      return null;
    }
  }

  /// Delete stored JWT token
  static Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey).timeout(const Duration(seconds: 3));
    } catch (e) {
      // Ignore
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bgTokenKey);
    } catch (e) {
      // Ignore
    }
  }

  /// Save user data as JSON string + mirror to SharedPreferences
  static Future<void> saveUser(UserModel user) async {
    final userJson = jsonEncode(user.toJson()..['id'] = user.id);
    try {
      await _storage.write(key: _userKey, value: userJson).timeout(const Duration(seconds: 3));
    } catch (e) {
      // Ignore
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bgUserKey, userJson);
    } catch (e) {
      // Ignore
    }
  }

  /// Get stored user data (foreground only)
  static Future<UserModel?> getUser() async {
    try {
      final userJson = await _storage.read(key: _userKey).timeout(const Duration(seconds: 3));
      if (userJson == null) return null;

      final Map<String, dynamic> json = jsonDecode(userJson);
      if (json.containsKey('id') && !json.containsKey('_id')) {
        json['_id'] = json['id'];
      }
      return UserModel.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Get token from SharedPreferences — WORKS in background isolates
  static Future<String?> getTokenForBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_bgTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Get user from SharedPreferences — WORKS in background isolates
  static Future<UserModel?> getUserForBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_bgUserKey);
      if (userJson == null) return null;

      final Map<String, dynamic> json = jsonDecode(userJson);
      if (json.containsKey('id') && !json.containsKey('_id')) {
        json['_id'] = json['id'];
      }
      return UserModel.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Clear all stored data (token + user) — used on logout
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll().timeout(const Duration(seconds: 3));
    } catch (e) {
      // Ignore
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bgTokenKey);
      await prefs.remove(_bgUserKey);
    } catch (e) {
      // Ignore
    }
  }

  /// Check if a token exists
  static Future<bool> hasToken() async {
    try {
      final token = await _storage.read(key: _tokenKey).timeout(const Duration(seconds: 3));
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
