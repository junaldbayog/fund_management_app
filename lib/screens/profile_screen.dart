import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _name = '';
  String _email = '';
  dynamic _profileImage; // Can be String (path) or Uint8List (web)

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.instance.getUserData();
      setState(() {
        _name = userData?['name'] ?? '';
        _email = userData?['email'] ?? '';
        _profileImage = userData?['profileImage'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileImage() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        image: _getProfileImage(),
      ),
      child: _profileImage == null
          ? Icon(
              Icons.person_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }

  DecorationImage? _getProfileImage() {
    if (_profileImage == null) return null;
    
    if (kIsWeb) {
      if (_profileImage is Uint8List) {
        return DecorationImage(
          image: MemoryImage(_profileImage),
          fit: BoxFit.cover,
        );
      }
      return null;
    }
    
    if (_profileImage is String) {
      return DecorationImage(
        image: FileImage(File(_profileImage)),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    );

    if (result == true) {
      _loadUserData(); // Refresh profile data after successful edit
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        _buildProfileImage(),
                        const SizedBox(height: 16),
                        Text(
                          _name.isNotEmpty ? _name : 'No name set',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email.isNotEmpty ? _email : 'No email set',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Account Settings Section
                  Text(
                    'Account Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline_rounded),
                          title: const Text('Edit Profile'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _navigateToEditProfile,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_outline_rounded),
                          title: const Text('Change Password'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            // TODO: Implement change password
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: const Text('Notifications'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            // TODO: Implement notifications settings
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Preferences Section
                  Text(
                    'Preferences',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.color_lens_outlined),
                          title: const Text('Theme'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            // TODO: Implement theme settings
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.language_rounded),
                          title: const Text('Language'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            // TODO: Implement language settings
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // About Section
                  Text(
                    'About',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline_rounded),
                          title: const Text('App Info'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            // TODO: Show app info
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            // TODO: Show privacy policy
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: const Text('Terms of Service'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            // TODO: Show terms of service
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 