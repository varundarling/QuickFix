import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
  List<ServiceModel> _providerServices = [];
  List<ProviderModel> _providers = [];
  List<ProviderModel> _nearbyProviders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'All';

  List<ServiceModel> get services => _services;
  List<ServiceModel> get providerServices => _providerServices;
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
    'Carpentry',
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
    required String mobileNumber,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    if (hasListeners) {
      notifyListeners();
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Generate unique ID
      final serviceId = const Uuid().v4();

      // Create service model with location
      final newService = ServiceModel(
        id: serviceId,
        name: name,
        description: description,
        category: category,
        basePrice: basePrice,
        imageUrl: imageUrl,
        subServices: subServices,
        availability: 'available',
        mobileNumber: mobileNumber,
        providerId: currentUser.uid,
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        address: address,
        isBooked: false, // ✅ NEW: Initialize as not booked
        metadata: {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        },
      );

      // ✅ BATCH WRITE: Create service and update provider services list
      final batch = FirebaseFirestore.instance.batch();

      // Add service
      final serviceRef = FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId);
      batch.set(serviceRef, newService.toFireStore());

      // Update provider's services list
      final providerRef = FirebaseFirestore.instance
          .collection('providers')
          .doc(currentUser.uid);
      batch.update(providerRef, {
        'services': FieldValue.arrayUnion([serviceId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await batch.commit();

      // Add to local lists
      _services.add(newService);
      _providerServices.add(newService);

      _isLoading = false;
      if (hasListeners) {
        notifyListeners();
      }
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      if (hasListeners) {
        notifyListeners();
      }
      return false;
    }
  }

  // ✅ NEW: Mark service as booked by a specific user
  Future<bool> markServiceAsBooked(
    String serviceId,
    String userId, {
    String? customerName,
    String? customerPhone,
  }) async {
    try {
      debugPrint('🔄 Marking service $serviceId as booked by user $userId');

      final serviceIndex = _services.indexWhere((s) => s.id == serviceId);
      if (serviceIndex == -1) {
        debugPrint('❌ Service not found in local list');
        return false;
      }

      // Update local service
      final updatedService = _services[serviceIndex].copyWith(
        isBooked: true,
        bookedByUserId: userId,
        bookedAt: DateTime.now(),
        availability: 'booked',
        customerName: customerName,
        customerPhone: customerPhone,
      );

      _services[serviceIndex] = updatedService;

      // Update provider services if it exists there
      final providerIndex = _providerServices.indexWhere(
        (s) => s.id == serviceId,
      );
      if (providerIndex != -1) {
        _providerServices[providerIndex] = updatedService;
      }

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .update({
            'isBooked': true,
            'bookedByUserId': userId,
            'bookedAt': Timestamp.fromDate(DateTime.now()),
            'availability': 'booked',
            'customerName': customerName,
            'customerPhone': customerPhone,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

      debugPrint('✅ Service marked as booked successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error marking service as booked: $e');
      _errorMessage = 'Failed to book service: $e';
      notifyListeners();
      return false;
    }
  }

  // ✅ NEW: Mark service as available (unbook)
  Future<bool> markServiceAsAvailable(String serviceId) async {
    try {
      final serviceIndex = _services.indexWhere((s) => s.id == serviceId);
      if (serviceIndex == -1) return false;

      final updatedService = _services[serviceIndex].copyWith(
        isBooked: false,
        bookedByUserId: null,
        bookedAt: null,
        availability: 'available',
        customerName: null,
        customerPhone: null,
      );

      _services[serviceIndex] = updatedService;

      // Update provider services if it exists there
      final providerIndex = _providerServices.indexWhere(
        (s) => s.id == serviceId,
      );
      if (providerIndex != -1) {
        _providerServices[providerIndex] = updatedService;
      }

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .update({
            'isBooked': false,
            'bookedByUserId': FieldValue.delete(),
            'bookedAt': FieldValue.delete(),
            'availability': 'available',
            'customerName': FieldValue.delete(),
            'customerPhone': FieldValue.delete(),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to mark service as available: $e';
      notifyListeners();
      return false;
    }
  }

  // ✅ NEW: Get available (not booked) services
  List<ServiceModel> get availableServices {
    return _services.where((service) => service.isAvailableForBooking).toList();
  }

  // ✅ NEW: Get booked services
  List<ServiceModel> get bookedServices {
    return _services.where((service) => service.isBooked).toList();
  }

  // ✅ NEW: Get services booked by a specific user
  List<ServiceModel> getServicesBookedByUser(String userId) {
    return _services
        .where(
          (service) => service.isBooked && service.bookedByUserId == userId,
        )
        .toList();
  }

  // ✅ NEW: Get services provided by a specific provider
  Future<void> loadProviderServices(String providerId) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      _providerServices = snapshot.docs
          .map((doc) => ServiceModel.fromFireStore(doc))
          .toList();

      debugPrint('✅ Loaded ${_providerServices.length} provider services');

      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading provider services: $e');
      _isLoading = false;
      _errorMessage = e.toString();
      _safeNotifyListeners();
    }
  }

  Future<void> loadMyServices() async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      // ✅ Wait for authentication to be ready
      await Future.delayed(const Duration(milliseconds: 100));

      final currentUser = FirebaseAuth.instance.currentUser;

      // ✅ Add extensive debugging
      debugPrint('🔍 Loading services for user: ${currentUser?.uid}');
      debugPrint('🔍 User email: ${currentUser?.email}');

      if (currentUser == null) {
        debugPrint('❌ No current user found, clearing services');
        _providerServices = [];
        _isLoading = false;
        _safeNotifyListeners();
        return;
      }

      // ✅ Force token refresh to ensure authentication is valid
      await currentUser.getIdToken(true);

      debugPrint('🔍 Querying services with providerId: ${currentUser.uid}');

      // Load services for current provider
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timed out. Please check your connection.',
              );
            },
          );

      debugPrint('🔍 Found ${snapshot.docs.length} services in Firestore');

      // ✅ Debug each service found
      for (var doc in snapshot.docs) {
        final data = doc.data();
        debugPrint(
          '📄 Service: ${data['name']} (ID: ${doc.id}) - Provider: ${data['providerId']} - Booked: ${data['isBooked'] ?? false}',
        );
      }

      _providerServices = snapshot.docs
          .map((doc) => ServiceModel.fromFireStore(doc))
          .toList();

      debugPrint('✅ Successfully loaded ${_providerServices.length} services');

      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading services: $e');
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
          return distance <= 20.0; //within 20km
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
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Update in local lists
      void updateServiceInList(List<ServiceModel> list) {
        final index = list.indexWhere((service) => service.id == id);
        if (index != -1) {
          list[index] = list[index].copyWith(
            name: name,
            description: description,
            category: category,
            basePrice: basePrice,
            imageUrl: imageUrl,
            subServices: subServices,
          );
        }
      }

      updateServiceInList(_services);
      updateServiceInList(_providerServices);

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

      // Remove from local lists
      _services.removeWhere((service) => service.id == id);
      _providerServices.removeWhere((service) => service.id == id);

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

  // ✅ NEW: Filter services by booking status
  List<ServiceModel> getServicesByStatus(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return services.where((s) => s.isAvailableForBooking).toList();
      case 'booked':
        return services.where((s) => s.isBooked).toList();
      case 'in_progress':
        return services.where((s) => s.isInProgress).toList();
      default:
        return services;
    }
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

  // Method to load all services (for customers)
  Future<void> loadAllServices({double? userLat, double? userLng}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      debugPrint('🔄 Loading all services for customers...');

      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true)
          .get();

      List<ServiceModel> allServices = snapshot.docs
          .map((doc) => ServiceModel.fromFireStore(doc))
          .toList();

      debugPrint('📊 Total services loaded: ${allServices.length}');
      debugPrint(
        '📊 Available services: ${allServices.where((s) => s.isAvailableForBooking).length}',
      );
      debugPrint(
        '📊 Booked services: ${allServices.where((s) => s.isBooked).length}',
      );

      // Filter by location if provided (within 20km radius)
      if (userLat != null && userLng != null) {
        allServices = allServices.where((service) {
          if (service.latitude != null && service.longitude != null) {
            final distance = _locationService.calculateDistance(
              userLat,
              userLng,
              service.latitude!,
              service.longitude!,
            );
            return distance <= 20.0; // Within 20km
          }
          return true; // Include services without location data
        }).toList();

        // Sort by distance
        allServices.sort((a, b) {
          if (a.latitude == null || b.latitude == null) {
            return 0;
          }
          final distanceA = _locationService.calculateDistance(
            userLat,
            userLng,
            a.latitude!,
            a.longitude!,
          );
          final distanceB = _locationService.calculateDistance(
            userLat,
            userLng,
            b.latitude!,
            b.longitude!,
          );
          return distanceA.compareTo(distanceB);
        });
      }

      _services = allServices;
      _isLoading = false;
      _safeNotifyListeners();

      debugPrint(
        '✅ Successfully loaded and filtered ${_services.length} services',
      );
    } catch (e) {
      debugPrint('❌ Error loading all services: $e');
      _isLoading = false;
      _errorMessage = e.toString();
      _safeNotifyListeners();
    }
  }

  // ✅ Enhanced: Add booking fields to existing services
  Future<void> addBookingFieldsToExistingServices() async {
    try {
      debugPrint('🔄 Adding booking fields to existing services...');

      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('✅ No existing services to update');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Only update if booking fields don't exist
        if (!data.containsKey('isBooked')) {
          batch.update(doc.reference, {
            'isBooked': false,
            'bookedByUserId': null,
            'bookedAt': null,
            'customerName': null,
            'customerPhone': null,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      }

      await batch.commit();
      debugPrint(
        '✅ Updated ${snapshot.docs.length} existing services with booking fields',
      );
    } catch (e) {
      debugPrint('❌ Error updating existing services: $e');
    }
  }

  // ✅ Enhanced: Add availability to existing services (keeping original method)
  Future<void> addAvailabilityToExistingServices() async {
    try {
      debugPrint('🔄 Adding availability field to existing services...');

      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('✅ No existing services to update');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        // Only update if availability field doesn't exist
        final data = doc.data();
        if (!data.containsKey('availability')) {
          batch.update(doc.reference, {
            'availability': 'available',
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      }

      await batch.commit();
      debugPrint(
        '✅ Updated ${snapshot.docs.length} existing services with availability field',
      );
    } catch (e) {
      debugPrint('❌ Error updating existing services: $e');
    }
  }

  // ✅ NEW: Get service by ID
  ServiceModel? getServiceById(String serviceId) {
    try {
      return _services.firstWhere((service) => service.id == serviceId);
    } catch (e) {
      return null;
    }
  }

  // ✅ NEW: Refresh a specific service from Firestore
  Future<ServiceModel?> refreshService(String serviceId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .get();

      if (doc.exists) {
        final updatedService = ServiceModel.fromFireStore(doc);

        // Update in local lists
        void updateInList(List<ServiceModel> list) {
          final index = list.indexWhere((s) => s.id == serviceId);
          if (index != -1) {
            list[index] = updatedService;
          }
        }

        updateInList(_services);
        updateInList(_providerServices);

        notifyListeners();
        return updatedService;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error refreshing service: $e');
      return null;
    }
  }

  // Add this method to ServiceProvider class
  Future<void> migrateExistingServicesToProviders() async {
    try {
      debugPrint('🔄 Starting migration of existing services...');

      // Get all services
      final servicesSnapshot = await FirebaseFirestore.instance
          .collection('services')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      final processedProviders = <String>{};

      for (var serviceDoc in servicesSnapshot.docs) {
        final service = ServiceModel.fromFireStore(serviceDoc);
        final providerId = service.providerId;

        // Skip if we've already processed this provider
        if (processedProviders.contains(providerId)) {
          continue;
        }

        processedProviders.add(providerId);

        // Check if provider document already exists
        final providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .get();

        if (!providerDoc.exists) {
          // Get user data from Realtime Database
          final userSnapshot = await FirebaseDatabase.instance
              .ref('users')
              .child(providerId)
              .get();

          if (userSnapshot.exists && userSnapshot.value != null) {
            final userData = Map<String, dynamic>.from(
              userSnapshot.value as Map,
            );

            // Create provider document
            final providerData = {
              'userId': providerId,
              'businessName':
                  userData['businessName'] ??
                  userData['name'] ??
                  'Service Provider',
              'description':
                  userData['description'] ?? 'Professional service provider',
              'services': [],
              'rating': 0.0,
              'totalReviews': 0,
              'certifications': [],
              'latitude': service.latitude ?? 0.0,
              'longitude': service.longitude ?? 0.0,
              'address': service.address ?? userData['address'] ?? '',
              'availability': {
                'monday': true,
                'tuesday': true,
                'wednesday': true,
                'thursday': true,
                'friday': true,
                'saturday': true,
                'sunday': true,
              },
              'isVerified': false,
              'isActive': true,
              'createdAt': Timestamp.fromDate(DateTime.now()),
              'portfolioImages': [],
              'mobileNumber': service.mobileNumber,
              'experience': userData['experience'] ?? '1+ years',
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            };

            final providerRef = FirebaseFirestore.instance
                .collection('providers')
                .doc(providerId);
            batch.set(providerRef, providerData);
          }
        }
      }

      // Now update all provider documents with their service IDs
      for (var serviceDoc in servicesSnapshot.docs) {
        final service = ServiceModel.fromFireStore(serviceDoc);
        final providerId = service.providerId;

        final providerRef = FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId);

        batch.update(providerRef, {
          'services': FieldValue.arrayUnion([service.id]),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      await batch.commit();
      debugPrint('✅ Migration completed successfully!');
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
      rethrow;
    }
  }
}
