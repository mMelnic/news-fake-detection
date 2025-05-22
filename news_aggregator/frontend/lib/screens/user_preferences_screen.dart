import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';  // Add import for GoRouter

class UserPreferencesScreen extends StatefulWidget {
  final bool isInitialSetup;
  
  const UserPreferencesScreen({
    super.key, 
    this.isInitialSetup = false
  });

  @override
  UserPreferencesScreenState createState() => UserPreferencesScreenState();
}

class UserPreferencesScreenState extends State<UserPreferencesScreen> {
  final List<String> availableTopics = [
    'Technology', 'Business', 'Science', 'Health', 
    'Entertainment', 'Sports', 'Politics', 'Environment'
  ];
  
  final List<String> availableLanguages = [
    'en', 'fr', 'es', 'de', 'it', 'ru', 'zh'
  ];
  
  final Map<String, String> languageNames = {
    'en': 'English',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
    'it': 'Italian',
    'ru': 'Russian',
    'zh': 'Chinese',
  };
  
  final Map<String, String> availableCountries = {
    'us': 'United States',
    'gb': 'United Kingdom',
    'fr': 'France',
    'de': 'Germany',
    'ca': 'Canada',
    'au': 'Australia',
    'in': 'India',
  };
  
  Set<String> selectedTopics = {};
  String selectedLanguage = 'en';
  String? selectedCountry;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      selectedTopics = Set<String>.from(prefs.getStringList('selectedTopics') ?? ['Technology', 'Business', 'Science']);
      selectedLanguage = prefs.getString('language') ?? 'en';
      selectedCountry = prefs.getString('country');
    });
  }
  
  Future<void> _savePreferences() async {
    if (selectedTopics.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 3 topics')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selectedTopics', selectedTopics.toList());
      await prefs.setString('language', selectedLanguage);
      
      if (selectedCountry != null) {
        await prefs.setString('country', selectedCountry!);
      } else {
        await prefs.remove('country');
      }
      
      if (widget.isInitialSetup) {
        if (mounted) {
          // Use GoRouter instead of named routes
          context.go('/home');
        }
      } else {
        if (mounted) {
          Navigator.pop(context, true); // Return that preferences were updated
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving preferences: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitialSetup ? 'Setup Your News Feed' : 'News Preferences'),
        actions: [
          if (!widget.isInitialSetup)
            TextButton(
              child: const Text('RESET', style: TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() {
                  selectedTopics = {'Technology', 'Business', 'Science'};
                  selectedLanguage = 'en';
                  selectedCountry = null;
                });
              },
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Select Topics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose at least 3 topics you\'re interested in',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
                const SizedBox(height: 16),
                
                // Topics grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableTopics.map((topic) {
                    final isSelected = selectedTopics.contains(topic);
                    return FilterChip(
                      label: Text(topic),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTopics.add(topic);
                          } else {
                            if (selectedTopics.length > 3) {
                              selectedTopics.remove(topic);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('You must select at least 3 topics')),
                              );
                            }
                          }
                        });
                      },
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                // Language dropdown
                DropdownButtonFormField<String>(
                  value: selectedLanguage,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: availableLanguages
                      .map((lang) => DropdownMenuItem(
                            value: lang,
                            child: Text(languageNames[lang] ?? lang),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedLanguage = value;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Country (Optional)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                // Country dropdown
                DropdownButtonFormField<String?>(
                  value: selectedCountry,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select a country (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Countries'),
                    ),
                    ...availableCountries.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ))
                        .toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedCountry = value;
                    });
                  },
                ),
              ],
            ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton(
            onPressed: _savePreferences,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save Preferences'),
          ),
        ),
      ),
    );
  }
}