// ignore_for_file: library_private_types_in_public_api

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';


class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<dynamic> events = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    try {
      final response =
          await http.get(Uri.parse("http://10.12.31.122:3000/api/events"));
      if (response.statusCode == 200) {
        setState(() {
          events = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load events");
      }
    } catch (e) {
      print("Error fetching events: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Available Events"), 
        backgroundColor: Colors.blue,
          actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshEvents,
                child: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final consultants = event['consultants'] as List<dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event['title'],
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Duration: ${event['duration']} min",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600])),
                            const SizedBox(height: 10),

                            // Display consultants
                            consultants.isNotEmpty
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text("Consultants:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      const SizedBox(height: 8),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children:
                                              consultants.map((consultant) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 10),
                                              child: Column(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundImage: consultant[
                                                                'avatar'] ==
                                                            ""
                                                        ? const NetworkImage(
                                                            "https://upload.wikimedia.org/wikipedia/commons/7/7c/Profile_avatar_placeholder_large.png")
                                                        : AssetImage(
                                                                "lib/images${consultant['avatar']}")
                                                            as ImageProvider,
                                                    radius: 24,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(consultant['name'],
                                                      style: const TextStyle(
                                                          fontSize: 12)),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text("No consultants available",
                                    style: TextStyle(color: Colors.red)),

                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  "/event_details",
                                  arguments: event,
                                );
                              },
                              child: const Text("View Details"),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ));
  }
  Future<void> _refreshEvents() async {
    // Add your refresh logic here
    // For example, you can fetch the events from an API
    setState(() {
      isLoading = true;
    });
    await fetchEvents();
    setState(() {
      isLoading = false;
    });
  }
}
