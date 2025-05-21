import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/logger.dart';
import 'services/dio_client.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_state.dart';
import 'package:provider/provider.dart';

void main() async {
  setupLogging();
  WidgetsFlutterBinding.ensureInitialized();
  final authState = AuthState();
  await authState.checkInitialLoginStatus();

  runApp(
    ChangeNotifierProvider(create: (_) => authState, child: const MyApp()),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late GoRouter _router;
  bool _isLoggedIn = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // First try auto-login with existing refresh token
      final autoLoginSuccess = await DioClient.tryAutoLogin();
      
      if (autoLoginSuccess) {
        // If auto-login worked, try to get user data to confirm
        try {
          final response = await DioClient.dio.get('/auth/user/');
          if (response.statusCode == 200) {
            _isLoggedIn = true;
          }
        } catch (e) {
          debugPrint('Error getting user data: $e');
          _isLoggedIn = false;
        }
      } else {
        _isLoggedIn = false;
      }
    } catch (e) {
      debugPrint('Authentication check error: $e');
      _isLoggedIn = false;
    } finally {
      // After authentication check, set up the router
      setState(() {
        _isCheckingAuth = false;
        _router = GoRouter(
          navigatorKey: DioClient.navigatorKey,
          initialLocation: _isLoggedIn ? '/home' : '/login',
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const MyHomePage(title: 'Home Page'),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginScreen(),
            ),
            GoRoute(
              path: '/register',
              builder: (context, state) => const RegisterScreen(),
            ),
          ],
          // Route redirect logic with compatible syntax for older go_router
          redirect: (BuildContext context, GoRouterState state) {
            final String path = state.path ?? '';
            
            // If the user is not logged in and not on login or register page, redirect to login
            if (!_isLoggedIn && 
                !path.startsWith('/login') && 
                !path.startsWith('/register')) {
              return '/login';
            }
            // If the user is logged in and tries to access login or register, redirect to home
            if (_isLoggedIn && 
                (path.startsWith('/login') || 
                 path.startsWith('/register'))) {
              return '/home';
            }
            return null; // No redirect needed
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ); // Show loading while checking auth
    }

    return MaterialApp.router(
      title: 'News App',
      theme: ThemeData(primarySwatch: Colors.blue),
      routerConfig: _router,
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
