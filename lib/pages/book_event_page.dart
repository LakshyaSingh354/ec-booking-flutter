import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  Future<void> fetchEventAndConsultant() async {
    try {
      final eventResponse = await http.get(
          Uri.parse("http://10.12.31.122:3000/api/events/${widget.eventId}"));
      if (eventResponse.statusCode == 200) {
        setState(() {
          event = jsonDecode(eventResponse.body);
        });
      }

      if (widget.consultantId != null) {
        final consultantResponse = await http.get(Uri.parse(
            "http://10.12.31.122:3000/api/consultants/${widget.consultantId}"));
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

  Future<void> _handlePayment() async {
    if (guestName.isEmpty || guestEmail.isEmpty || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all details")));
      return;
    }

    setState(() => isBooking = true);

    try {
      final res = await http.post(
        Uri.parse("http://10.12.31.122:3000/api/payment/createOrder"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "event": widget.eventId,
          "amount": event?["price"] ?? 0, // Ensure event price is correct
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
    final startTime = selectedTime!.toIso8601String();
    final endTime = DateTime.parse(startTime)
        .add(Duration(minutes: event?['duration']))
        .toIso8601String();

    final bookingData = {
      "event": widget.eventId,
      "consultant": widget.consultantId,
      "guestName": guestName,
      "guestEmail": guestEmail,
      "startTime": startTime,
      "endTime": endTime,
      "paymentId": paymentId, // Attach the payment ID
    };

    try {
      final firebasetoken = await getToken();
      final response = await http.post(
        Uri.parse("http://10.12.31.122:3000/api/bookings"),
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

  Future<void> _selectDateTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (timePicked != null) {
        setState(() {
          selectedTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Book Event"), backgroundColor: Colors.blue,),
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
                        decoration: const InputDecoration(labelText: "Your Name"),
                        onChanged: (value) => setState(() => guestName = value),
                      ),
                      TextField(
                        decoration: const InputDecoration(labelText: "Your Email"),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (value) => setState(() => guestEmail = value),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _selectDateTime,
                        child: Text(selectedTime == null
                            ? "Pick a date & time"
                            : selectedTime!.toLocal().toString()),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isBooking ? null : _handlePayment,
                        child: isBooking
                            ? const CircularProgressIndicator(color: Colors.white)
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
