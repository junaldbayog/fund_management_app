import 'package:hive/hive.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  
  factory AuthService() {
    return instance;
  }

  AuthService._internal();

  static const String _authBoxName = 'auth';
  static const String _tokenKey = 'token';
  static const String _userDataKey = 'user_data';

  Future<void> init() async {
    await Hive.openBox(_authBoxName);
  }

  Future<void> saveToken(String token) async {
    final box = await Hive.openBox(_authBoxName);
    await box.put(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final box = await Hive.openBox(_authBoxName);
    return box.get(_tokenKey);
  }

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final box = await Hive.openBox(_authBoxName);
    await box.put(_userDataKey, userData);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final box = await Hive.openBox(_authBoxName);
    final data = box.get(_userDataKey);
    if (data == null) return null;
    // Convert LinkedMap to Map<String, dynamic>
    return Map<String, dynamic>.from(data);
  }

  Future<void> logout() async {
    final box = await Hive.openBox(_authBoxName);
    await box.clear(); // This will remove all stored data
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
} 