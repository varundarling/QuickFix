import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/widgets/buttons/primary_button.dart';
import 'package:quickfix/presentation/widgets/common/custom_text_field.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _phoneController.text = user.phone;
      // Load other provider-specific data if available
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            context.go('/provider-dashboard');
          },
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        child: IconButton(
                          onPressed: () {
                            // Add image picker functionality
                          },
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              CustomTextField(
                controller: _businessNameController,
                label: 'Business Name',
                hintText: 'Enter your business name',
              ),

              const SizedBox(height: 16),

              CustomTextField(
                controller: _descriptionController,
                label: 'Business Description',
                hintText: 'Describe your business and services',
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              CustomTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hintText: 'Enter phone number',
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 16),

              CustomTextField(
                controller: _addressController,
                label: 'Business Address',
                hintText: 'Enter your business address',
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return PrimaryButton(
                    onPressed: authProvider.isUpdatingProfile
                        ? null
                        : _saveProfile,
                    text: 'Save Profile',
                    isLoading: authProvider.isUpdatingProfile,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Add profile saving logic here using your AuthProvider
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
