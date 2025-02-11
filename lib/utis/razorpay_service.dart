import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RazorpayService {
  late Razorpay _razorpay;

  RazorpayService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print("Payment Successful: ${response.paymentId}");
    // Proceed to booking confirmation
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print("Payment Failed: ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("External Wallet Selected: ${response.walletName}");
  }

  Future<void> makePayment(String eventId, double amount, String guestName, String guestEmail) async {
    try {
      // Step 1: Create Razorpay Order
      final res = await http.post(
        Uri.parse("https://yourdomain.com/api/payment/createOrder"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"event": eventId, "amount": amount}),
      );

      final data = jsonDecode(res.body);
      if (data["error"] != null) {
        print("Payment Order Creation Failed: ${data['error']}");
        return;
      }

      // Step 2: Start Razorpay Payment
      var options = {
        "key": "YOUR_RAZORPAY_KEY",
        "amount": (amount * 100).toInt(),
        "currency": "INR",
        "name": "Epitome Consulting",
        "description": "Booking for Event",
        "order_id": data["id"],
        "prefill": {"name": guestName, "email": guestEmail},
        "theme": {"color": "#00cc66"}
      };

      _razorpay.open(options);
    } catch (e) {
      print("Error in Payment: $e");
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
