// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> signInWithGoogle() async {
    try {
      // Start Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled sign-in

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Get Firebase ID token
        String? firebaseToken = await user.getIdToken();

        // Send user details to your Next.js backend
        await sendUserToBackend(user, firebaseToken);

        // Navigate to Home Page (Replace with your route)
        Navigator.pushReplacementNamed(context, "/events");
      }
    } catch (error) {
      print("Google Sign-In Error: $error");
    }
  }

  Future<void> sendUserToBackend(User user, String? firebaseToken) async {
    final response = await http.post(
      Uri.parse("http://10.12.31.122:3000/api/firebase-auth"),
      headers: {
        "Authorization": "Bearer $firebaseToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "name": user.displayName,
        "email": user.email,
        "avatar": user.photoURL,
      }),
    );

    if (response.statusCode == 200) {
      print("User Signed In sucessfully");
    }else if(response.statusCode == 201){
      print("User added to database");
    } else {
      print("Failed to save user: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: signInWithGoogle,
          child: const Text("Sign in with Google"),
        ),
      ),
    );
  }
}
