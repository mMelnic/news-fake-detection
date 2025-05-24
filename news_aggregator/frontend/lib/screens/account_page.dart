// import 'package:flutter/material.dart';
// import '../services/auth_service.dart';
// import '../services/auth_state.dart';
// import '../services/user_service.dart';
// import '../models/user_profile.dart';
// import 'package:provider/provider.dart';
// import 'package:go_router/go_router.dart';
// import 'profile_edit_page.dart';

// class AccountPage extends StatefulWidget {
//   const AccountPage({super.key});

//   @override
//   State<AccountPage> createState() => _AccountPageState();
// }

// class _AccountPageState extends State<AccountPage> {
//   final UserService _userService = UserService();
//   bool _isLoading = true;
//   UserProfile? _userProfile;
//   String? _errorMessage;
  
//   @override
//   void initState() {
//     super.initState();
//     _loadUserProfile();
//   }
  
//   Future<void> _loadUserProfile() async {
//     try {
//       final profile = await _userService.getCurrentUserProfile();
//       setState(() {
//         _userProfile = profile;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to load profile: $e';
//         _isLoading = false;
//       });
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('My Account')),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _errorMessage != null
//               ? _buildErrorView()
//               : _buildProfileView(),
//     );
//   }
  
//   Widget _buildErrorView() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.error_outline, size: 48, color: Colors.red),
//           const SizedBox(height: 16),
//           Text(_errorMessage ?? 'Unknown error occurred'),
//           const SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () {
//               setState(() {
//                 _isLoading = true;
//                 _errorMessage = null;
//               });
//               _loadUserProfile();
//             },
//             child: const Text('Try Again'),
//           ),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildProfileView() {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // Profile avatar
//             const CircleAvatar(
//               radius: 60,
//               child: Icon(Icons.person, size: 80),
//             ),
//             const SizedBox(height: 20),
            
//             // Username and display name
//             Text(
//               _userProfile?.displayName ?? 'Set Up Profile',
//               style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             Text(
//               '@${_userProfile?.username}',
//               style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//             ),
            
//             const SizedBox(height: 16),
            
//             // Bio
//             if (_userProfile?.bio != null && _userProfile!.bio!.isNotEmpty)
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(_userProfile!.bio!),
//               ),
            
//             const SizedBox(height: 24),
            
//             // Edit profile button
//             OutlinedButton.icon(
//               icon: const Icon(Icons.edit),
//               label: const Text('Edit Profile'),
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const ProfileEditPage(),
//                   ),
//                 ).then((_) => _loadUserProfile());
//               },
//               style: OutlinedButton.styleFrom(
//                 minimumSize: const Size.fromHeight(50),
//               ),
//             ),
            
//             const SizedBox(height: 12),
            
//             // Logout button
//             ElevatedButton.icon(
//               icon: const Icon(Icons.logout),
//               label: const Text('Logout'),
//               onPressed: () async {
//                 try {
//                   await AuthService().logout();
//                   if (context.mounted) {
//                     Provider.of<AuthState>(context, listen: false).logout();
//                     context.go('/login');
//                   }
//                 } catch (e) {
//                   if (context.mounted) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(content: Text('Error logging out: $e')),
//                     );
//                   }
//                 }
//               },
//               style: ElevatedButton.styleFrom(
//                 minimumSize: const Size.fromHeight(50),
//                 backgroundColor: Colors.red,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }