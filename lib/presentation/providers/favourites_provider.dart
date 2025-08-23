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

  // ✅ IMPORTANT: Store favorites locally on customer device
  static const String _favoritesKey = 'customer_favorite_services';

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _favoriteServiceIds = prefs.getStringList(_favoritesKey) ?? [];
      debugPrint(
        '✅ Loaded ${_favoriteServiceIds.length} favorites from local storage',
      );
    } catch (e) {
      debugPrint('❌ Error loading favorites: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleFavorite(ServiceModel service) async {
    try {
      if (_favoriteServiceIds.contains(service.id)) {
        _favoriteServiceIds.remove(service.id);
        _favoriteServices.removeWhere((s) => s.id == service.id);
        debugPrint('💔 Removed ${service.name} from favorites');
      } else {
        _favoriteServiceIds.add(service.id);
        _favoriteServices.add(service);
        debugPrint('❤️ Added ${service.name} to favorites');
      }

      await _saveFavorites();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
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
    debugPrint(
      '🔄 Updated favorite services list: ${_favoriteServices.length}',
    );
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoriteServiceIds);
      debugPrint(
        '💾 Saved favorites to local storage: ${_favoriteServiceIds.length}',
      );
    } catch (e) {
      debugPrint('❌ Error saving favorites: $e');
    }
  }

  Future<void> removeFavorite(String serviceId) async {
    _favoriteServiceIds.remove(serviceId);
    _favoriteServices.removeWhere((s) => s.id == serviceId);
    await _saveFavorites();
    notifyListeners();
    debugPrint('🗑️ Removed favorite: $serviceId');
  }

  Future<void> clearAllFavorites() async {
    _favoriteServiceIds.clear();
    _favoriteServices.clear();
    await _saveFavorites();
    notifyListeners();
    debugPrint('🧹 Cleared all favorites');
  }

  // ✅ Additional method to export favorites for backup
  Map<String, dynamic> exportFavorites() {
    return {
      'favoriteServiceIds': _favoriteServiceIds,
      'exportDate': DateTime.now().toIso8601String(),
      'count': _favoriteServiceIds.length,
    };
  }

  // ✅ Additional method to import favorites from backup
  Future<void> importFavorites(Map<String, dynamic> favoritesData) async {
    try {
      final importedIds = List<String>.from(
        favoritesData['favoriteServiceIds'] ?? [],
      );
      _favoriteServiceIds = importedIds;
      await _saveFavorites();
      notifyListeners();
      debugPrint('📥 Imported ${importedIds.length} favorites');
    } catch (e) {
      debugPrint('❌ Error importing favorites: $e');
    }
  }
}
