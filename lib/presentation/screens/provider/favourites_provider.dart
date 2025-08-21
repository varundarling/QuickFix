// lib/presentation/providers/favorites_provider.dart
import 'package:flutter/material.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  List<String> _favoriteServiceIds = [];
  List<ServiceModel> _favoriteServices = [];
  bool _isLoading = false;

  List<String> get favoriteServiceIds => _favoriteServiceIds;
  List<ServiceModel> get favoriteServices => _favoriteServices;
  bool get isLoading => _isLoading;

  static const String _favoritesKey = 'favorite_services';

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _favoriteServiceIds = prefs.getStringList(_favoritesKey) ?? [];
    } catch (e) {
      print('Error loading favorites: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleFavorite(ServiceModel service) async {
    try {
      if (_favoriteServiceIds.contains(service.id)) {
        _favoriteServiceIds.remove(service.id);
        _favoriteServices.removeWhere((s) => s.id == service.id);
      } else {
        _favoriteServiceIds.add(service.id);
        _favoriteServices.add(service);
      }

      await _saveFavorites();
      notifyListeners();
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  bool isFavorite(String serviceId) {
    return _favoriteServiceIds.contains(serviceId);
  }

  void updateFavoriteServices(List<ServiceModel> allServices) {
    _favoriteServices = allServices
        .where((service) => _favoriteServiceIds.contains(service.id))
        .toList();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoriteServiceIds);
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  Future<void> removeFavorite(String serviceId) async {
    _favoriteServiceIds.remove(serviceId);
    _favoriteServices.removeWhere((s) => s.id == serviceId);
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> clearAllFavorites() async {
    _favoriteServiceIds.clear();
    _favoriteServices.clear();
    await _saveFavorites();
    notifyListeners();
  }
}
