import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'signup_page.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  final FocusNode _focusNodePassword = FocusNode();
  final TextEditingController _controllerUsername = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();

  bool _obscurePassword = true;
  final Box _boxLogin = Hive.box("login");
  final Box _boxAccounts = Hive.box("accounts");

  bool _showSpinner = false;

  // Simulate a login delay for UI feedback
  Future<void> _simulateLogin() async {
    setState(() => _showSpinner = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _showSpinner = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: Stack(
        children: [
          if (_showSpinner) const Center(child: CircularProgressIndicator()),
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  const SizedBox(height: 150),
                  Text(
                    "Welcome back",
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Login to your account",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 60),
                  TextFormField(
                    controller: _controllerUsername,
                    keyboardType: TextInputType.name,
                    decoration: InputDecoration(
                      labelText: "Username",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onEditingComplete: () => _focusNodePassword.requestFocus(),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter username.";
                      } else if (!_boxAccounts.containsKey(value)) {
                        return "Username is not registered.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _controllerPassword,
                    focusNode: _focusNodePassword,
                    obscureText: _obscurePassword,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.password_outlined),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon:
                            _obscurePassword
                                ? const Icon(Icons.visibility_outlined)
                                : const Icon(Icons.visibility_off_outlined),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter password.";
                      } else if (value !=
                          _boxAccounts.get(_controllerUsername.text)) {
                        return "Wrong password.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 60),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        await _simulateLogin();
                        _boxLogin.put("loginStatus", true);
                        _boxLogin.put("userName", _controllerUsername.text);

                        if (!mounted) return;
                        // Navigate to home or dashboard
                        // Navigator.pushReplacement(
                        //   context,
                        //   MaterialPageRoute(builder: (_) => const Home()),
                        // );
                      }
                    },
                    child: const Text("Login"),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          _formKey.currentState?.reset();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignUp()),
                          );
                        },
                        child: const Text("Signup"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focusNodePassword.dispose();
    _controllerUsername.dispose();
    _controllerPassword.dispose();
    super.dispose();
  }
}