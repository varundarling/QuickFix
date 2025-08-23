import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/widgets/common/custom_text_field.dart';

class CreateServiceScreen extends StatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isCreating = false;
  bool _isLoadingLocation = false;

  String _selectedCategory = 'Plumbing';
  final List<String> _categories = [
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Appliance Repair',
    'Painting',
    'Carpentry',
    'Other',
  ];

  final List<String> _subServices = [];
  final _subServiceController = TextEditingController();

  // Location data
  double? _latitude;
  double? _longitude;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        _currentAddress =
            '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';
        _addressController.text = _currentAddress ?? '';
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Service'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => context.go('/provider-dashboard'),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Name
              CustomTextField(
                controller: _nameController,
                label: 'Service Name',
                hintText: 'e.g., Emergency Plumbing Repair',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter service name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                dropdownColor: Colors.white,
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Mobile Number
              CustomTextField(
                controller: _mobileNumberController,
                label: 'Mobile Number',
                hintText: '9876543210',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Location Section
              Card(
                color: Colors.white,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Service Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_isLoadingLocation)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              onPressed: _getCurrentLocation,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Refresh Location',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _addressController,
                        label: 'Address',
                        hintText: 'Enter your service area address',
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter service location';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              CustomTextField(
                controller: _descriptionController,
                label: 'Description',
                hintText: 'Describe your service in detail',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Base Price
              CustomTextField(
                controller: _basePriceController,
                label: 'Base Price (₹)',
                hintText: '500',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter base price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Sub Services Section
              const Text(
                'Sub Services (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subServiceController,
                      decoration: const InputDecoration(
                        hintText: 'Add sub service',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addSubService,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sub Services List
              if (_subServices.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _subServices.map((service) {
                    return Chip(
                      label: Text(service),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => _removeSubService(service),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 32),

              // Create Service Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isCreating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Creating Service...'),
                          ],
                        )
                      : const Text(
                          'Create Service',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSubService() {
    if (_subServiceController.text.trim().isNotEmpty) {
      setState(() {
        _subServices.add(_subServiceController.text.trim());
        _subServiceController.clear();
      });
    }
  }

  void _removeSubService(String service) {
    setState(() {
      _subServices.remove(service);
    });
  }

  void _createService() async {
    if (_isCreating || !mounted) return;
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location to create service'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final serviceProvider = context.read<ServiceProvider>();
      final authProvider = context.read<AuthProvider>(); // Add this
      final currentUser = FirebaseAuth.instance.currentUser!;

      await _createOrUpdateProviderProfile(currentUser.uid, authProvider);

      final success = await serviceProvider.addService(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        basePrice: double.parse(_basePriceController.text.trim()),
        imageUrl: '',
        subServices: _subServices,
        mobileNumber: _mobileNumberController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        address: _addressController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/provider-dashboard');
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  // ✅ NEW METHOD: Create or Update Provider Profile
  Future<void> _createOrUpdateProviderProfile(
    String providerId,
    AuthProvider authProvider,
  ) async {
    try {
      final userModel = authProvider.userModel;
      if (userModel == null) {
        throw Exception('User profile not found');
      }

      // Check if provider document already exists
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();

      final providerData = {
        'userId': providerId,
        'businessName': userModel.businessName ?? userModel.name,
        'description': userModel.description ?? 'Professional service provider',
        'services': [], // Will be updated when services are added
        'rating': 0.0,
        'totalReviews': 0,
        'certifications': [],
        'latitude': _latitude!,
        'longitude': _longitude!,
        'address': _addressController.text.trim(),
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
        'hourlyRate': double.parse(_basePriceController.text.trim()),
        'portfolioImages': [],
        'mobileNumber': _mobileNumberController.text.trim(),
        'experience': userModel.experience ?? '1 year',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (providerDoc.exists) {
        // Update existing provider
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .update({
              ...providerData,
              'services': FieldValue.arrayUnion([]), // Keep existing services
            });
        debugPrint('✅ Provider profile updated');
      } else {
        // Create new provider
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .set(providerData);
        debugPrint('✅ Provider profile created');
      }
    } catch (e) {
      debugPrint('❌ Error creating/updating provider profile: $e');
      throw e;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _basePriceController.dispose();
    _subServiceController.dispose();
    _mobileNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
