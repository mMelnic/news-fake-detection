import 'package:flutter/material.dart';
import 'package:frontend/android/view/widgets/calendar_popup_view.dart';
import 'android/view/screens/news_page.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';
import 'services/logger.dart';
import 'services/dio_client.dart';
// import 'package:go_router/go_router.dart';
import 'services/auth_state.dart';
import 'package:provider/provider.dart';
import 'screens/home_page.dart';
import 'theme/app_theme.dart'; // Import our new theme
import 'package:hive_flutter/hive_flutter.dart';
import 'android/login_screen.dart';
import 'android/view/screens/discovery_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final authService = AuthService();
  final isLoggedIn = await authService.checkInitialLoginStatus();
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo Login',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(32, 63, 129, 1.0),
        ),
        fontFamily: 'Abel',
      ),
      home: isLoggedIn ? const NewsPage() : const Login(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HexColor extends Color {
  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }
}

// void main() async {
//   setupLogging();
//   WidgetsFlutterBinding.ensureInitialized();
  
//   final authState = AuthState();
//   await authState.checkInitialLoginStatus();

//   runApp(
//     ChangeNotifierProvider(create: (_) => authState, child: const MyApp()),
//   );
// }

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   bool _isCheckingAuth = true;
//   late final GoRouter _router;

//   @override
//   void initState() {
//     super.initState();
//     _setupRouter();
//   }

//   // Update the GoRouter configuration to use a history state router to properly handle browser history

//   void _setupRouter() {
//     setState(() {
//       _isCheckingAuth = false;
//       _router = GoRouter(
//         navigatorKey: DioClient.navigatorKey,
//         routes: [
//           GoRoute(
//             path: '/login',
//             builder: (context, state) => const LoginScreen(),
//           ),
//           GoRoute(
//             path: '/register',
//             builder: (context, state) => const RegisterScreen(),
//           ),
//           GoRoute(
//             path: '/home',
//             builder: (context, state) => const HomePage(),
//           ),
//           // Add other routes as needed
//         ],
//         initialLocation: '/login',
//         redirect: (BuildContext context, GoRouterState state) {
//           final bool isLoggedIn = Provider.of<AuthState>(context, listen: false).isLoggedIn;
//           final String path = state.path ?? '';
          
//           // Don't redirect when pressing back button (only check auth for direct navigation attempts)
//           final extra = state.extra;
//           if (extra is Map && extra['fromBack'] == true) {
//             return null;
//           }
          
//           if (!isLoggedIn && 
//               !path.startsWith('/login') && 
//               !path.startsWith('/register')) {
//             return '/login';
//           }
//           if (isLoggedIn && 
//               (path.startsWith('/login') || 
//                path.startsWith('/register'))) {
//             return '/home';
//           }
//           return null;
//         },
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     Provider.of<AuthState>(context);
    
//     if (_isCheckingAuth) {
//       return MaterialApp(
//         home: Container(
//           color: AppTheme.backgroundColor,
//           child: const Center(
//             child: CircularProgressIndicator(
//               color: AppTheme.primaryColor,
//             ),
//           ),
//         ),
//       );
//     }

//     return MaterialApp.router(
//       title: 'News App',
//       theme: AppTheme.lightTheme,
//       routerConfig: _router,
//     );
//   }
// }


// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // TRY THIS: Try changing the color here to a specific color (to
//         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
//         // change color while the other colors stay the same.
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: const Text('Home Page'),
//       ),
//       body: Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           //
//           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
//           // action in the IDE, or press "p" in the console), to see the
//           // wireframe for each widget.
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text('You have pushed the button this many times:'),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }
