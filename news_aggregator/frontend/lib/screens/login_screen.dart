import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import 'package:dio/dio.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  void _login() async {
    if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    
    try {
      final response = await _authService.login(
        _email.text.trim(),
        _password.text.trim(),
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        Provider.of<AuthState>(context, listen: false).login();
        context.go('/home');
      } else {
        setState(() {
          _errorMessage = 'Login failed: Unexpected response';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.response?.data['error'] ?? 'Network error occurred';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'An unexpected error occurred';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppTheme.instagramGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.newspaper,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // App name
                  const Text(
                    'NEWS FEED',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Real-time news with smart analysis',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Error message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Email field
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: AppTheme.inputDecoration.copyWith(
                      hintText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password field
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    decoration: AppTheme.inputDecoration.copyWith(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Forgot password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Handle forgot password
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Login button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Log In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account?',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}