import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:language_picker/language_picker.dart';
import 'package:language_picker/languages.dart';
import '../../../services/auth_service.dart';
import '../../login_screen.dart';
import '../../model/user.dart';
import '../../model/collection.dart';
import '../../services/user_profile_service.dart';
import 'collections_page.dart';
import 'page_switch_with_animation.dart';

class CombinedProfilePage extends StatefulWidget {
  const CombinedProfilePage({super.key});

  @override
  State<CombinedProfilePage> createState() => _CombinedProfilePageState();
}

class _CombinedProfilePageState extends State<CombinedProfilePage> {
  bool _isLoading = true;
  User? _user;
  int _likesCount = 0;
  int _commentsCount = 0;
  int _savedCount = 0;
  List<Collection> _collections = [];
  
  final String defaultImage = 'assets/images/newspaper_beige.jpg';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final profileData = await UserProfileService.getUserProfile();
      final user = User.fromMap(profileData);
      
      final statsData = await UserProfileService.getUserStats();
      
      final collectionsData = await UserProfileService.getSavedCollections();
      final collections = collectionsData.map((c) => Collection.fromMap(c)).toList();
      
      setState(() {
        _user = user;
        _likesCount = statsData['likes_count'] ?? 0;
        _commentsCount = statsData['comments_count'] ?? 0;
        _savedCount = statsData['saved_count'] ?? 0;
        _collections = collections;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user data: $e')),
      );
    }
  }
  
  Future<void> _updateUserProfile({
    String? displayName,
    String? bio,
    String? preferredLanguage,
    String? country,
  }) async {
    try {
      final updatedData = await UserProfileService.updateUserProfile(
        displayName: displayName,
        bio: bio,
        preferredLanguage: preferredLanguage,
        country: country,
      );
      
      setState(() {
        _user = User.fromMap(updatedData);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }
  
  void _editDisplayName() {
    final TextEditingController controller = TextEditingController(text: _user?.displayName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your display name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserProfile(displayName: controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _editBio() {
    final TextEditingController controller = TextEditingController(text: _user?.bio);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bio'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tell us about yourself',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserProfile(bio: controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _selectLanguage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Preferred Language'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: LanguagePickerDropdown(
            initialValue: Languages.defaultLanguages.firstWhere(
              (lang) => lang.isoCode == _user?.preferredLanguage,
              orElse: () => Languages.english,
            ),
            languages: Languages.defaultLanguages,
            onValuePicked: (Language language) {
              _updateUserProfile(preferredLanguage: language.isoCode);
            },
            itemBuilder: (Language language) => Row(
              children: <Widget>[
                const SizedBox(width: 8.0),
                Text(language.name),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _selectCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, color: Colors.blueGrey),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color(0xFF8C98A8).withOpacity(0.2),
            ),
          ),
        ),
      ),
      onSelect: (Country country) {
        _updateUserProfile(country: country.countryCode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Stack(
            children: <Widget>[
              SizedBox(
                height: 250,
                width: double.infinity,
                child: Image.asset(
                  defaultImage,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16.0, 200.0, 16.0, 16.0),
                child: Column(
                  children: <Widget>[
                    // User info card
                    Stack(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          margin: const EdgeInsets.only(top: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                margin: const EdgeInsets.only(left: 96.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        Text(
                                          _user?.displayName ?? _user?.username ?? 'User',
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 16),
                                          onPressed: _editDisplayName,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _user?.country.isNotEmpty == true 
                                              ? _user!.country 
                                              : 'Select country',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 16),
                                          onPressed: _selectCountry,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10.0),
                              // Interaction stats
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      children: <Widget>[
                                        Text("$_likesCount"),
                                        const Text("Liked"),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: <Widget>[
                                        Text("$_commentsCount"),
                                        const Text("Commented"),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: <Widget>[
                                        Text("$_savedCount"),
                                        const Text("Saved"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Profile image
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            image: DecorationImage(
                              image: AssetImage(defaultImage),
                              fit: BoxFit.cover,
                            ),
                          ),
                          margin: const EdgeInsets.only(left: 16.0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    // User details card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      child: Column(
                        children: <Widget>[
                          const ListTile(title: Text("User information")),
                          const Divider(),
                          // Email
                          ListTile(
                            title: const Text("Email"),
                            subtitle: Text(_user?.email ?? 'No email'),
                            leading: const Icon(Icons.email),
                          ),
                          // Bio
                          ListTile(
                            title: Row(
                              children: [
                                const Text("Bio"),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  onPressed: _editBio,
                                ),
                              ],
                            ),
                            subtitle: Text(_user?.bio.isNotEmpty == true ? _user!.bio : 'Add your bio'),
                            leading: const Icon(Icons.person),
                          ),
                          // Language
                          ListTile(
                            title: Row(
                              children: [
                                const Text("Preferred Language"),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  onPressed: _selectLanguage,
                                ),
                              ],
                            ),
                            subtitle: Text(_user?.preferredLanguage.isNotEmpty == true 
                                ? _user!.preferredLanguage 
                                : 'Select language'),
                            leading: const Icon(Icons.language),
                          ),
                          // Username
                          ListTile(
                            title: const Text("Username"),
                            subtitle: Text(_user?.username ?? 'User'),
                            leading: const Icon(Icons.account_circle),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    // Saved collections
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Saved Collections",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            // Show dialog to create new collection
                            final TextEditingController controller = TextEditingController();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Create New Collection'),
                                content: TextField(
                                  controller: controller,
                                  decoration: const InputDecoration(
                                    hintText: 'Collection name',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // Create new collection and refresh
                                      Navigator.pop(context);
                                      _loadUserData();
                                    },
                                    child: const Text('Create'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    _collections.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No saved collections yet. Save articles to create collections!',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _collections.length,
                              itemBuilder: (context, index) {
                                final collection = _collections[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10.0),
                                  child: _buildSavedCard(
                                    context,
                                    collection.name,
                                    collection.articleCount,
                                    collection.coverImage,
                                    onTap: () {
                                      // Navigate to collection detail screen
                                      // Implement this later
                                    },
                                    collectionIndex: index,
                                  ),
                                );
                              },
                            ),
                          ),
                    // Add visual separator before logout
                    const Divider(thickness: 1, height: 32),
                    _buildLogoutButton(context),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              AppBar(backgroundColor: Colors.transparent, elevation: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedCard(
    BuildContext context, 
    String title, 
    int articleCount,
    String imageUrl, {
    VoidCallback? onTap,
    int? collectionIndex,
  }) {
    return GestureDetector(
      onTap: () {
        if (collectionIndex != null) {
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => CollectionsPage(
                collections: _collections,
                initialCollectionIndex: collectionIndex,
              ),
            ),
          ).then((_) => _loadUserData()); // Refresh data when returning
        }
      },
      child: SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          children: [
            // Shadow layers for 3D effect
            Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(10.0),
              ),
              height: double.infinity,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(10.0),
              ),
              height: double.infinity,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            ),
            // Main card with image
            Container(
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              height: double.infinity,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image with caching
                  imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            'assets/images/newspaper_hand.jpg',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/newspaper_hand.jpg',
                          fit: BoxFit.cover,
                        ),
                  // Overlay for better text visibility
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ],
              ),
            ),
            // Title and count
            Container(
              alignment: Alignment.center,
              height: double.infinity,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$articleCount articles',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
        ),
        onPressed: () => _handleLogout(context),
        child: const Text(
          'Log Out',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

Future<void> _handleLogout(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final authService = AuthService();
      await authService.logout();

      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Login()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }
}
