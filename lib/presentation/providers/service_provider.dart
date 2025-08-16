import 'package:flutter/material.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/data/models/provider_model.dart';
import 'package:quickfix/data/models/service_model.dart';

class ServiceProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService.instance;
  final LocationService _locationService = LocationService.instance;

  List<ServiceModel> _services = [];
  List<ProviderModel> _providers = [];
  List<ProviderModel> _nearbyProviders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'All';

  List<ServiceModel> get services => _services;
  List<ProviderModel> get providers => _providers;
  List<ProviderModel> get nearbyProviders => _nearbyProviders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;

  List<String> get categories => [
    'All',
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Appliance Repair',
    'Painting',
    'Carepentry',
  ];

  Future<void> loadServices() async {
    try {
      _setLoading(true);

      final querySnapshot = await _firebaseService.getCollection(
        'services',
        queryBuilder: (query) => query.where('isActive', isEqualTo: true),
      );

      _services = querySnapshot.docs
          .map((doc) => ServiceModel.fromFireStore(doc))
          .toList();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load services:$e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadProviders({double? userLat, double? userLng}) async {
    try {
      _setLoading(true);

      final querySnapshot = await _firebaseService.getCollection(
        'providers',
        queryBuilder: (query) => query
            .where('isActive', isEqualTo: true)
            .where('isVerified', isEqualTo: true),
      );

      _providers = querySnapshot.docs
          .map((doc) => ProviderModel.fromFireStore(doc))
          .toList();

      //calculate nearby providers if location is provided
      if (userLat != null && userLng != null) {
        _nearbyProviders = _providers.where((provider) {
          final distance = _locationService.calculateDistance(
            userLat,
            userLng,
            provider.latitude,
            provider.longitude,
          );
          return distance <= 10.0; //within 10km
        }).toList();

        //sort by distance
        _nearbyProviders.sort((a, b) {
          final distanceA = _locationService.calculateDistance(
            userLat,
            userLng,
            a.latitude,
            a.longitude,
          );
          final distanceB = _locationService.calculateDistance(
            userLat,
            userLng,
            b.latitude,
            b.longitude,
          );

          return distanceA.compareTo(distanceB);
        });
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load provider:$e');
    } finally {
      _setLoading(false);
    }
  }

  List<ServiceModel> getServicesByCategory() {
    if (_selectedCategory == 'All') {
      return services;
    }
    return services
        .where((service) => service.category == selectedCategory)
        .toList();
  }

  List<ProviderModel> getProvidersByService(String serviceId) {
    return _providers
        .where((provider) => provider.services.contains(serviceId))
        .toList();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
