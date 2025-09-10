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
      // 1) Load provider aggregates
      final provRef = _firebaseService.firestore
          .collection('providers')
          .doc(service.providerId);
      final provSnap = await provRef.get();

      double seedRating = 0.0;
      int seedCount = 0;

      if (provSnap.exists && provSnap.data() != null) {
        final data = provSnap.data() as Map<String, dynamic>;
        // Accept both 'rating' and legacy 'raitng' just in case
        final rawRating = (data['rating'] ?? data['raitng'] ?? 0.0);
        final rawCount = (data['totalReviews'] ?? 0);
        seedRating = (rawRating is num) ? rawRating.toDouble() : 0.0;
        seedCount = (rawCount is num) ? rawCount.toInt() : 0;
      }

      // 2) Build service data with seeded aggregates
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(service.toFireStore())..addAll({
            'providerRating': seedRating,
            'providerTotalReviews': seedCount,
            'lastRatingUpdate': FieldValue.serverTimestamp(),
          });

      // 3) Write
      await _firebaseService.firestore
          .collection('services')
          .doc(service.id)
          .set(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateService(ServiceModel service) async {
    try {
      final servicesRef = _firebaseService.firestore
          .collection('services')
          .doc(service.id);

      // Check if missing denormalized fields
      final existing = await servicesRef.get();
      bool needsSeed = true;
      if (existing.exists && existing.data() != null) {
        final d = existing.data() as Map<String, dynamic>;
        final hasRating = d.containsKey('providerRating');
        final hasCount = d.containsKey('providerTotalReviews');
        needsSeed = !(hasRating && hasCount);
      }

      double seedRating = service.providerRating ?? 0.0;
      int seedCount = service.providerTotalReviews ?? 0;

      if (needsSeed || seedRating == 0.0 && seedCount == 0) {
        // Load from provider aggregates if not present on the model
        final provSnap = await _firebaseService.firestore
            .collection('providers')
            .doc(service.providerId)
            .get();
        if (provSnap.exists && provSnap.data() != null) {
          final d = provSnap.data() as Map<String, dynamic>;
          final rawRating = (d['rating'] ?? d['raitng'] ?? 0.0);
          final rawCount = (d['totalReviews'] ?? 0);
          seedRating = (rawRating is num) ? rawRating.toDouble() : seedRating;
          seedCount = (rawCount is num) ? rawCount.toInt() : seedCount;
        }
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(service.toFireStore())
            ..putIfAbsent('providerRating', () => seedRating)
            ..putIfAbsent('providerTotalReviews', () => seedCount)
            ..putIfAbsent(
              'lastRatingUpdate',
              () => FieldValue.serverTimestamp(),
            );

      await _firebaseService.firestore
          .collection('services')
          .doc(service.id)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> backfillServiceRatingsForAllProviders() async {
    final fs = _firebaseService.firestore;

    // Load providers with aggregates
    final providers = await fs.collection('providers').get();

    for (final p in providers.docs) {
      final pdata = p.data() as Map<String, dynamic>;
      final rawRating = (pdata['rating'] ?? pdata['raitng'] ?? 0.0);
      final rawCount = (pdata['totalReviews'] ?? 0);
      final avg = (rawRating is num) ? rawRating.toDouble() : 0.0;
      final count = (rawCount is num) ? rawCount.toInt() : 0;

      // Update all services for this provider that are missing fields
      final servicesSnap = await fs
          .collection('services')
          .where('providerId', isEqualTo: p.id)
          .get();

      final batch = fs.batch();
      for (final s in servicesSnap.docs) {
        final sdata = s.data();
        final hasRating = sdata.containsKey('providerRating');
        final hasCount = sdata.containsKey('providerTotalReviews');
        if (!hasRating || !hasCount) {
          batch.set(s.reference, {
            'providerRating': avg,
            'providerTotalReviews': count,
            'lastRatingUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      await batch.commit();
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
