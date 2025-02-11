import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:ec_booking/pages/book_event_page.dart';
import 'package:ec_booking/pages/event_details_page.dart';
import 'package:ec_booking/pages/events_page.dart';
import 'package:ec_booking/pages/home.dart';
import 'package:ec_booking/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Epitome Consulting',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(), // Check authentication state
      routes: {
        "/home": (context) => const HomePage(),
        "events": (context) => EventsPage(),
        "/event_details": (context) => EventDetailsPage(),
        "/login": (context) => LoginPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/book_event') {
          final args = settings.arguments as Map<String, String?>;
          return MaterialPageRoute(
            builder: (context) => BookEventPage(
              eventId: args['eventId']!,
              consultantId: args['consultantId'],
            ),
          );
        }
        return null;
      },
    );
  }
}

/// Wrapper to check authentication state and redirect accordingly
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator()); // Show loading state
        }
        if (snapshot.hasData) {
          return EventsPage(); // User is authenticated
        } else {
          return LoginPage(); // User is not authenticated
        }
      },
    );
  }
}