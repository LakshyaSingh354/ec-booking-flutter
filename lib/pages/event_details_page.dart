import 'package:flutter/material.dart';

class EventDetailsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final event = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final consultants = event['consultants'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(title: Text(event['title']), backgroundColor: Colors.blue),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(event['description'], style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Text("Duration: ${event['duration']} min", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            const Text("Available Consultants:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: consultants.length,
                itemBuilder: (context, index) {
                  final consultant = consultants[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: consultant['avatar'] == ""
                          ? const NetworkImage("https://upload.wikimedia.org/wikipedia/commons/7/7c/Profile_avatar_placeholder_large.png")
                          : AssetImage("lib/images${consultant['avatar']}") as ImageProvider,
                    ),
                    title: Text(consultant['name']),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          "/book_event",
                          arguments: {"eventId": event['_id'].toString(), "consultantId": consultant['_id'].toString()},
                        );
                      },
                      child: const Text("Book"),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text("Not Sure? Book without a consultant and we'll assign one for you.", style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 10),
            // Button to book without a consultant
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    "/book_event",
                    arguments: {"eventId": event['_id'].toString()}, // No consultantId provided
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Custom color
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text("Book Without a Consultant", style: TextStyle(color: Colors.white),),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
