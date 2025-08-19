import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/widgets/buttons/primary_button.dart';
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
  final _mobileNumberController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Service'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            context.go('/provider-dashboard');
          },
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
                value: _selectedCategory,
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

              // Add Sub Service
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
              Consumer<ServiceProvider>(
                builder: (context, serviceProvider, child) {
                  return PrimaryButton(
                    onPressed: serviceProvider.isLoading
                        ? null
                        : _createService,
                    text: 'Create Service',
                    isLoading: serviceProvider.isLoading,
                  );
                },
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
    if (!_formKey.currentState!.validate()) return;

    final serviceProvider = context.read<ServiceProvider>();

    final success = await serviceProvider.addService(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      basePrice: double.parse(_basePriceController.text.trim()),
      imageUrl: '', // You can add image picker later
      subServices: _subServices,
      mobileNumber: _mobileNumberController.text.trim(),
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
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serviceProvider.errorMessage ?? 'Failed to create service',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _basePriceController.dispose();
    _subServiceController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }
}
