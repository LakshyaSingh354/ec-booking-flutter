import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;

class BookEventPage extends StatefulWidget {
  final String eventId;
  final String? consultantId;

  const BookEventPage({super.key, required this.eventId, this.consultantId});

  @override
  _BookEventPageState createState() => _BookEventPageState();
}

class _BookEventPageState extends State<BookEventPage> {
  Map<String, dynamic>? event;
  Map<String, dynamic>? consultant;
  String guestName = "";
  String guestEmail = "";
  DateTime? selectedTime;
  bool isLoading = true;
  bool isBooking = false;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    fetchEventAndConsultant();
    fetchBookedSlots(); // Fetch booked slots when page loads

    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  List<Map<String, dynamic>> bookedSlots = [];

  Future<void> fetchBookedSlots() async {
    try {
      final response = await http.get(Uri.parse(
          "https://ec-booking-pink.vercel.app/api/bookings/${widget.consultantId}"));
      if (response.statusCode == 200) {
        List<dynamic> bookings = jsonDecode(response.body);

        setState(() {
          bookedSlots = bookings.map((b) {
            return {
              "startTime": DateTime.parse(b['startTime'])
                  .toLocal(), // Convert UTC to local
              "endTime": DateTime.parse(b['endTime'])
                  .toLocal(), // Convert UTC to local
            };
          }).toList();
        });
      }
    } catch (e) {
      print("Error fetching booked slots: $e");
    }
  }

  Future<void> fetchEventAndConsultant() async {
    try {
      final eventResponse = await http.get(Uri.parse(
          "https://ec-booking-pink.vercel.app/api/events/${widget.eventId}"));
      if (eventResponse.statusCode == 200) {
        setState(() {
          event = jsonDecode(eventResponse.body);
        });
      }

      if (widget.consultantId != null) {
        final consultantResponse = await http.get(Uri.parse(
            "https://ec-booking-pink.vercel.app/api/consultants/${widget.consultantId}"));
        if (consultantResponse.statusCode == 200) {
          setState(() {
            consultant = jsonDecode(consultantResponse.body);
          });
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      print("Error fetching data: $e");
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> generateSlots() {
    if (event == null || event!['duration'] == null) return [];

    int duration = event!['duration'];
    List<Map<String, dynamic>> slots = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      DateTime date = now.add(Duration(days: i));
      List<Map<String, String>> dailySlots = [];

      for (DateTime slotTime = DateTime(date.year, date.month, date.day, 9, 0);
          slotTime.hour < 17;
          slotTime = slotTime.add(Duration(minutes: duration))) {
        if (slotTime.isBefore(now)) continue;

        DateTime endTime = slotTime.add(Duration(minutes: duration));
        if (endTime.hour > 17) break;

        // Convert slot time to local before comparison
        DateTime localSlotTime = slotTime.toLocal();
        DateTime localEndTime = endTime.toLocal();

        // Check if the slot falls within any booked range
        bool isBooked = bookedSlots.any((b) {
          DateTime bookedStart = b['startTime'].toLocal();
          DateTime bookedEnd = b['endTime'].toLocal();
          return (localSlotTime.isAfter(bookedStart) ||
                  localSlotTime.isAtSameMomentAs(bookedStart)) &&
              (localSlotTime.isBefore(bookedEnd));
        });

        dailySlots.add({
          "slotTime": slotTime.toIso8601String(),
          "slotString":
              "${localSlotTime.hour.toString().padLeft(2, '0')}:${localSlotTime.minute.toString().padLeft(2, '0')} - "
                  "${localEndTime.hour.toString().padLeft(2, '0')}:${localEndTime.minute.toString().padLeft(2, '0')}",
          "isBooked": isBooked.toString()
        });
      }

      slots.add({"date": date, "slots": dailySlots});
    }

    return slots;
  }

  void _showSlotSelectionDialog() {
    List<Map<String, dynamic>> slotsByDate = generateSlots();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select a Time Slot"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                children: slotsByDate.map((daySlots) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat("dd-MM-yyyy")
                            .format(daySlots['date'].toLocal()),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      (daySlots['slots'] as List).isEmpty
                          ? const Text("No slots available")
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (daySlots['slots']
                                      as List<Map<String, dynamic>>)
                                  .map((slot) {
                                DateTime slotTime =
                                    DateTime.parse(slot['slotTime']!);
                                String isBooked = slot['isBooked'];

                                return ElevatedButton(
                                  onPressed: isBooked == "true"
                                      ? null
                                      : () {
                                          setState(() {
                                            selectedTime = slotTime;
                                          });
                                          Navigator.pop(context);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 15),
                                    backgroundColor: isBooked == "true"
                                        ? Colors.grey
                                        : Color.fromARGB(255, 15, 168, 244),
                                  ),
                                  child: Text(slot['slotString']!,
                                      style: TextStyle(
                                          color: isBooked == "true"
                                              ? Colors.black54
                                              : Colors.white)),
                                );
                              }).toList(),
                            ),
                      const Divider(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePayment() async {
    if (guestName.isEmpty || guestEmail.isEmpty || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all details")));
      return;
    }

    setState(() => isBooking = true);

    try {
      final res = await http.post(
        Uri.parse("https://ec-booking-pink.vercel.app/api/payment/createOrder"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "event": widget.eventId,
          "amount": event?["price"] ?? 0,
        }),
      );

      final data = jsonDecode(res.body);
      if (data["error"] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Payment Order Failed: ${data['error']}")));
        setState(() => isBooking = false);
        return;
      }

      var options = {
        "key": "rzp_test_p4CmOWDjdxFcgG",
        "amount": (event?["price"] * 100).toInt(),
        "currency": "INR",
        "name": "Epitome Consulting",
        "description": "Booking for Event",
        "order_id": data["id"],
        "prefill": {"name": guestName, "email": guestEmail},
        "theme": {"color": "#00cc66"}
      };

      _razorpay.open(options);
    } catch (e) {
      print("Error starting payment: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Payment Error")));
      setState(() => isBooking = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print("Payment Successful: ${response.paymentId}");
    _confirmBooking(response.paymentId!);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print("Payment Failed: ${response.message}");
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment Failed: ${response.message}")));
    setState(() => isBooking = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("External Wallet Selected: ${response.walletName}");
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("External Wallet: ${response.walletName}")));
  }

  Future<void> _confirmBooking(String paymentId) async {
  final startTime = selectedTime!.toUtc().toIso8601String(); // Convert to UTC
  final endTime = DateTime.parse(startTime)
      .add(Duration(minutes: event?['duration']))
      .toUtc()
      .toIso8601String(); // Convert to UTC

  final bookingData = {
    "event": widget.eventId,
    "consultant": widget.consultantId,
    "guestName": guestName,
    "guestEmail": guestEmail,
    "startTime": startTime,
    "endTime": endTime,
    "paymentId": paymentId,
  };

  try {
    final firebasetoken = await getToken();
    final response = await http.post(
      Uri.parse("https://ec-booking-pink.vercel.app/api/bookings"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $firebasetoken"
      },
      body: jsonEncode(bookingData),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Booking Confirmed!")));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("Booking failed: ${jsonDecode(response.body)['error']}")));
    }
  } catch (e) {
    print("Error booking event: $e");
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("An error occurred")));
  } finally {
    setState(() => isBooking = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text("Book Event"), backgroundColor: Colors.blue),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : event == null
              ? const Center(child: Text("Event not found"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event?['title'] ?? "",
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(event?['price'] != null
                          ? "Price: ₹${event?['price']}"
                          : "Free Event"),
                      TextField(
                        decoration:
                            const InputDecoration(labelText: "Your Name"),
                        onChanged: (value) => setState(() => guestName = value),
                      ),
                      TextField(
                        decoration:
                            const InputDecoration(labelText: "Your Email"),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (value) =>
                            setState(() => guestEmail = value),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _showSlotSelectionDialog,
                        child: Text(selectedTime == null
                            ? "Select Time Slot"
                            : "${selectedTime!.hour}:${selectedTime!.minute.toString().padRight(2, '0')} on ${selectedTime!.day}-${selectedTime!.month}-${selectedTime!.year}"),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isBooking ? null : _handlePayment,
                        child: isBooking
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("Pay & Confirm Booking"),
                      ),
                    ],
                  ),
                ),
    );
  }
}

Future<String?> getToken() async {
  final user = FirebaseAuth.instance.currentUser;
  return user != null ? await user.getIdToken() : null;
}
