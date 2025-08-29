import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorage {
  static LocalStorage? _instance;
  static LocalStorage get instance => _instance ??= LocalStorage._();

  LocalStorage._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // String operations
  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  // Int operations
  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  // Bool operations
  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  // Double operations
  Future<void> setDouble(String key, double value) async {
    await _prefs?.setDouble(key, value);
  }

  double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  // List operations
  Future<void> setStringList(String key, List<String> value) async {
    await _prefs?.setStringList(key, value);
  }

  List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  // JSON operations
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    final jsonString = json.encode(value);
    await _prefs?.setString(key, jsonString);
  }

  Map<String, dynamic>? getJson(String key) {
    final jsonString = _prefs?.getString(key);
    if (jsonString != null) {
      return json.decode(jsonString);
    }
    return null;
  }

  // Remove operations
  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }

  bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  Set<String> getKeys() {
    return _prefs?.getKeys() ?? {};
  }

  // App-specific operations
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyUserToken = 'user_token';
  static const String _keyUserData = 'user_data';
  static const String _keyAppSettings = 'app_settings';
  static const String _keyLastLocation = 'last_location';
  static const String _keySearchHistory = 'search_history';
  static const String _keyFavoriteServices = 'favorite_services';

  Future<void> setFirstLaunch(bool isFirst) async {
    await setBool(_keyFirstLaunch, isFirst);
  }

  bool isFirstLaunch() {
    return getBool(_keyFirstLaunch) ?? true;
  }

  Future<void> setUserToken(String token) async {
    await setString(_keyUserToken, token);
  }

  String? getUserToken() {
    return getString(_keyUserToken);
  }

  Future<void> setUserData(Map<String, dynamic> userData) async {
    await setJson(_keyUserData, userData);
  }

  Map<String, dynamic>? getUserData() {
    return getJson(_keyUserData);
  }

  Future<void> setAppSettings(Map<String, dynamic> settings) async {
    await setJson(_keyAppSettings, settings);
  }

  Map<String, dynamic>? getAppSettings() {
    return getJson(_keyAppSettings);
  }

  Future<void> setLastLocation(double lat, double lng) async {
    await setJson(_keyLastLocation, {'lat': lat, 'lng': lng});
  }

  Map<String, double>? getLastLocation() {
    final location = getJson(_keyLastLocation);
    if (location != null) {
      return {
        'lat': location['lat']?.toDouble() ?? 0.0,
        'lng': location['lng']?.toDouble() ?? 0.0,
      };
    }
    return null;
  }

  Future<void> addToSearchHistory(String query) async {
    final history = getStringList(_keySearchHistory) ?? [];
    if (!history.contains(query)) {
      history.insert(0, query);
      if (history.length > 10) {
        history.removeLast();
      }
      await setStringList(_keySearchHistory, history);
    }
  }

  List<String> getSearchHistory() {
    return getStringList(_keySearchHistory) ?? [];
  }

  Future<void> clearSearchHistory() async {
    await remove(_keySearchHistory);
  }

  Future<void> addFavoriteService(String serviceId) async {
    final favorites = getStringList(_keyFavoriteServices) ?? [];
    if (!favorites.contains(serviceId)) {
      favorites.add(serviceId);
      await setStringList(_keyFavoriteServices, favorites);
    }
  }

  Future<void> removeFavoriteService(String serviceId) async {
    final favorites = getStringList(_keyFavoriteServices) ?? [];
    favorites.remove(serviceId);
    await setStringList(_keyFavoriteServices, favorites);
  }

  List<String> getFavoriteServices() {
    return getStringList(_keyFavoriteServices) ?? [];
  }

  bool isFavoriteService(String serviceId) {
    final favorites = getFavoriteServices();
    return favorites.contains(serviceId);
  }
}
