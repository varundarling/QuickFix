import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service_model.dart';
import '../models/provider_model.dart';
import '../../core/services/firebase_service.dart';

class ServiceRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;

  Future<List<ServiceModel>> getAllServices() async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'services',
        queryBuilder: (query) => query.where('isActive', isEqualTo: true),
      );

      return querySnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
          .map((doc) => ServiceModel.fromFireStore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ServiceModel?> getServiceById(String serviceId) async {
    try {
      final doc = await _firebaseService.getDocument('services', serviceId);
      if (doc.exists) {
        final castedDoc = doc as DocumentSnapshot<Map<String, dynamic>>;
        return ServiceModel.fromFireStore(castedDoc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ServiceModel>> getServicesByCategory(String category) async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'services',
        queryBuilder: (query) => query
            .where('category', isEqualTo: category)
            .where('isActive', isEqualTo: true),
      );

      return querySnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
          .map((doc) => ServiceModel.fromFireStore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ProviderModel>> getAllProviders() async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'providers',
        queryBuilder: (query) => query
            .where('isActive', isEqualTo: true)
            .where('isVerified', isEqualTo: true),
      );

      return querySnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
          .map((doc) => ProviderModel.fromFireStore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ProviderModel?> getProviderById(String providerId) async {
    try {
      final doc = await _firebaseService.getDocument('providers', providerId);
      if (doc.exists) {
        final castedDoc = doc as DocumentSnapshot<Map<String, dynamic>>;
        return ProviderModel.fromFireStore(castedDoc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ProviderModel>> getProvidersByService(String serviceId) async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'providers',
        queryBuilder: (query) => query
            .where('services', arrayContains: serviceId)
            .where('isActive', isEqualTo: true)
            .where('isVerified', isEqualTo: true),
      );

      return querySnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
          .map((doc) => ProviderModel.fromFireStore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ProviderModel>> getNearbyProviders({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // Note: For production, you would use GeoHash or similar for efficient geo queries
      final querySnapshot = await _firebaseService.getCollection(
        'providers',
        queryBuilder: (query) => query
            .where('isActive', isEqualTo: true)
            .where('isVerified', isEqualTo: true),
      );

      return querySnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
          .map((doc) => ProviderModel.fromFireStore(doc))
          .where((provider) {
            final distance = _calculateDistance(
              latitude,
              longitude,
              provider.latitude,
              provider.longitude,
            );
            return distance <= radiusKm;
          })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createService(ServiceModel service) async {
    try {
      await _firebaseService.createDocument(
        'services',
        service.id,
        service.toFireStore(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateService(ServiceModel service) async {
    try {
      await _firebaseService.updateDocument(
        'services',
        service.id,
        service.toFireStore(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createProvider(ProviderModel provider) async {
    try {
      await _firebaseService.createDocument(
        'providers',
        provider.id,
        provider.toFireStore(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProvider(ProviderModel provider) async {
    try {
      await _firebaseService.updateDocument(
        'providers',
        provider.id,
        provider.toFireStore(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getServiceCategories() async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'services',
        queryBuilder: (query) => query.where('isActive', isEqualTo: true),
      );

      final categories = <String>{};
      for (final doc
          in querySnapshot.docs
              .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()) {
        final service = ServiceModel.fromFireStore(doc);
        categories.add(service.category);
      }
      return categories.toList()..sort();
    } catch (e) {
      rethrow;
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Simple distance calculation - in production, use more accurate formula
    const double earthRadius = 6371; // Earth's radius in km

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
}