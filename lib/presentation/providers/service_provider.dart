import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/data/models/provider_model.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:uuid/uuid.dart';

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

  void _safeNotifyListeners() {
    Future.microtask(() {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  Future<bool> addService({
    required String name,
    required String description,
    required String category,
    required double basePrice,
    String imageUrl = '',
    List<String> subServices = const [],
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Generate unique ID
      final serviceId = const Uuid().v4();

      // Create service model
      final newService = ServiceModel(
        id: serviceId,
        name: name,
        description: description,
        category: category,
        basePrice: basePrice,
        imageUrl: imageUrl,
        subServices: subServices,
        providerId: currentUser.uid, // Add provider ID
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .set(newService.toFireStore());

      // Add to local list
      _services.add(newService);

      _isLoading = false;
      _safeNotifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _safeNotifyListeners();
      return false;
    }
  }

  Future<void> loadServices() async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _services = [];
        _isLoading = false;
        _safeNotifyListeners();
        return;
      }

      // Load services for current provider
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _services = snapshot.docs
          .map((doc) => ServiceModel.fromFireStore(doc))
          .toList();

      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _safeNotifyListeners();
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

  Future<bool> updateService({
    required String id,
    required String name,
    required String description,
    required String category,
    required double basePrice,
    String imageUrl = '',
    List<String> subServices = const [],
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Update in Firestore
      await FirebaseFirestore.instance.collection('services').doc(id).update({
        'name': name,
        'description': description,
        'category': category,
        'basePrice': basePrice,
        'imageUrl': imageUrl,
        'subServices': subServices,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Update in local list
      final index = _services.indexWhere((service) => service.id == id);
      if (index != -1) {
        _services[index] = ServiceModel(
          id: id,
          name: name,
          description: description,
          category: category,
          basePrice: basePrice,
          imageUrl: imageUrl,
          subServices: subServices,
          providerId: _services[index].providerId,
          createdAt: _services[index].createdAt,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeService(String id) async {
    try {
      // Remove from Firestore
      await FirebaseFirestore.instance.collection('services').doc(id).delete();

      // Remove from local list
      _services.removeWhere((service) => service.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
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
    if (_isLoading != loading) {
      _isLoading = loading;
      // Only call notifyListeners if we're not in a build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
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
