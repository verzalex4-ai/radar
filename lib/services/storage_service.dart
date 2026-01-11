import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String _currentUserKey = 'current_user';
  static const String _nearbyUsersKey = 'nearby_users';
  static const String _userNameKey = 'user_name';

  Future<void> saveCurrentUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, user.toJsonString());
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString(_currentUserKey);

    if (userJson != null) {
      return UserModel.fromJsonString(userJson);
    }
    return null;
  }

  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  Future<void> saveNearbyUsers(List<UserModel> users) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> usersJson = users
        .map((user) => user.toJsonString())
        .toList();
    await prefs.setStringList(_nearbyUsersKey, usersJson);
  }

  Future<List<UserModel>> getNearbyUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? usersJson = prefs.getStringList(_nearbyUsersKey);

    if (usersJson != null) {
      return usersJson.map((json) => UserModel.fromJsonString(json)).toList();
    }
    return [];
  }

  Future<void> clearNearbyUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nearbyUsersKey);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
