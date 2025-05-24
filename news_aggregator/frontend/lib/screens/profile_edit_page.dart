// import 'package:flutter/material.dart';
// import '../services/user_service.dart';

// class ProfileEditPage extends StatefulWidget {
//   const ProfileEditPage({super.key});

//   @override
//   State<ProfileEditPage> createState() => _ProfileEditPageState();
// }

// class _ProfileEditPageState extends State<ProfileEditPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _displayNameController = TextEditingController();
//   final _bioController = TextEditingController();
//   final _userService = UserService();
  
//   bool _isLoading = true;
//   bool _isSaving = false;
//   String _errorMessage = '';
  
//   @override
//   void initState() {
//     super.initState();
//     _loadUserProfile();
//   }
  
//   Future<void> _loadUserProfile() async {
//     try {
//       final profile = await _userService.getCurrentUserProfile();
      
//       setState(() {
//         _displayNameController.text = profile.displayName ?? '';
//         _bioController.text = profile.bio ?? '';
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to load profile: $e';
//         _isLoading = false;
//       });
//     }
//   }
  
//   Future<void> _saveProfile() async {
//     if (!_formKey.currentState!.validate()) return;
    
//     setState(() {
//       _isSaving = true;
//       _errorMessage = '';
//     });
    
//     try {
//       await _userService.updateUserProfile(
//         displayName: _displayNameController.text.trim(),
//         bio: _bioController.text.trim(),
//       );
      
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Profile updated successfully')),
//         );
//         Navigator.of(context).pop();
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to update profile: $e';
//         _isSaving = false;
//       });
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Edit Profile'),
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     if (_errorMessage.isNotEmpty)
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         margin: const EdgeInsets.only(bottom: 16),
//                         decoration: BoxDecoration(
//                           color: Colors.red.shade50,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Row(
//                           children: [
//                             const Icon(Icons.error_outline, color: Colors.red),
//                             const SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 _errorMessage,
//                                 style: const TextStyle(color: Colors.red),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
                      
//                     const Text(
//                       'Display Name *',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 8),
//                     TextFormField(
//                       controller: _displayNameController,
//                       decoration: const InputDecoration(
//                         hintText: 'Enter your display name',
//                         border: OutlineInputBorder(),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Display name is required';
//                         }
//                         return null;
//                       },
//                     ),
                    
//                     const SizedBox(height: 16),
//                     const Text(
//                       'Bio (Optional)',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 8),
//                     TextFormField(
//                       controller: _bioController,
//                       decoration: const InputDecoration(
//                         hintText: 'Tell us about yourself',
//                         border: OutlineInputBorder(),
//                       ),
//                       maxLines: 3,
//                     ),
                    
//                     const SizedBox(height: 24),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _isSaving ? null : _saveProfile,
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                         ),
//                         child: _isSaving
//                             ? const SizedBox(
//                                 height: 20,
//                                 width: 20,
//                                 child: CircularProgressIndicator(strokeWidth: 2),
//                               )
//                             : const Text('Save Profile'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }
  
//   @override
//   void dispose() {
//     _displayNameController.dispose();
//     _bioController.dispose();
//     super.dispose();
//   }
// }