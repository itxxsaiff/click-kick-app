import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/stripe_config.dart';
import '../firebase_options.dart';

class PaymentService {
  PaymentService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  static bool _stripeConfigured = false;

  String _appBaseUrl() {
    if (kIsWeb) return Uri.base.origin;
    final authDomain = DefaultFirebaseOptions.web.authDomain;
    if (authDomain != null && authDomain.isNotEmpty) {
      return 'https://$authDomain';
    }
    return 'https://${DefaultFirebaseOptions.web.projectId}.firebaseapp.com';
  }

  Future<void> _ensureStripeConfigured() async {
    if (kIsWeb || _stripeConfigured) return;
    Stripe.publishableKey = StripeConfig.publishableKey;
    await Stripe.instance.applySettings();
    _stripeConfigured = true;
  }

  String _invoiceNumber() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand = (Random().nextInt(900000) + 100000).toString();
    return 'INV-$date-$rand';
  }

  String _ymd(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Uint8List> _buildInvoicePdf({
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String sponsorName,
    required String sponsorEmail,
    required String companyName,
    required String applicationName,
    required String country,
    required double amount,
    required String currency,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(26),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF2A1847),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Video Contest Show',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Sponsorship Invoice',
                      style: pw.TextStyle(
                        color: const PdfColor.fromInt(0xFFE859C3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _pdfLine('Invoice #', invoiceNumber),
                    _pdfLine('Date', _ymd(invoiceDate)),
                    _pdfLine('Currency', currency.toUpperCase()),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _pdfSection(
                  title: 'Billed To',
                  children: [
                    sponsorName,
                    sponsorEmail,
                    if (companyName.isNotEmpty) companyName,
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _pdfSection(
                  title: 'Sponsorship Application',
                  children: [
                    applicationName,
                    'Region: $country',
                    'Invoice Date: ${_ymd(invoiceDate)}',
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEFE7FA),
                ),
                children: [
                  _pdfCell('Description', bold: true),
                  _pdfCell('Amount', bold: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfCell('Sponsorship Campaign Fee'),
                  _pdfCell('\$${amount.toStringAsFixed(2)}'),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfCell('Total'),
                  _pdfCell(
                    '\$${amount.toStringAsFixed(2)}',
                    bold: true,
                    color: const PdfColor.fromInt(0xFF7A2CA0),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Thank you for your sponsorship application.',
            style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(color: PdfColors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSection({
    required String title,
    required List<String> children,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF7A2CA0),
              fontSize: 11,
            ),
          ),
          pw.SizedBox(height: 6),
          ...children.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(line, style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> paySponsorshipApplicationDemo({
    required String applicationId,
    required String sponsorId,
  }) async {
    final applicationRef = _firestore
        .collection('sponsorship_applications')
        .doc(applicationId);
    final paymentRef = _firestore.collection('payments').doc();
    final nowDate = DateTime.now();
    final now = Timestamp.fromDate(nowDate);
    final invoiceNumber = _invoiceNumber();

    final applicationSnap = await applicationRef.get();
    if (!applicationSnap.exists) {
      throw Exception('application-not-found');
    }
    final application = applicationSnap.data()!;
    if ((application['paymentStatus'] ?? '').toString() == 'paid' &&
        (application['paymentId'] ?? '').toString().isNotEmpty) {
      return {
        'paymentId': (application['paymentId'] ?? '').toString(),
        'invoiceNumber': (application['invoiceNumber'] ?? '').toString(),
      };
    }

    final amount = ((application['applicationFee'] ?? 1000) as num).toDouble();
    final sponsorSnap = await _firestore
        .collection('users')
        .doc(sponsorId)
        .get();
    final sponsor = sponsorSnap.data() ?? const <String, dynamic>{};
    final sponsorName = (sponsor['displayName'] ?? 'Sponsor').toString();
    final sponsorEmail = (sponsor['email'] ?? '').toString();
    final companyName = (sponsor['companyName'] ?? '').toString();

    final targetCountry = (application['targetCountry'] ?? 'ALL').toString();

    final pdfBytes = await _buildInvoicePdf(
      invoiceNumber: invoiceNumber,
      invoiceDate: nowDate,
      sponsorName: sponsorName,
      sponsorEmail: sponsorEmail,
      companyName: companyName,
      applicationName:
          (application['applicationName'] ?? 'Sponsorship Application')
              .toString(),
      country: targetCountry,
      amount: amount,
      currency: 'usd',
    );

    final invoiceRef = _storage.ref('invoices/$invoiceNumber.pdf');
    await invoiceRef.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    final invoiceUrl = await invoiceRef.getDownloadURL();

    final batch = _firestore.batch();
    batch.set(paymentRef, {
      'applicationId': applicationId,
      'sponsorId': sponsorId,
      'amount': amount,
      'currency': 'usd',
      'status': 'paid',
      'provider': 'demo',
      'invoiceNumber': invoiceNumber,
      'invoiceGeneratedAt': now,
      'invoiceUrl': invoiceUrl,
      'createdAt': now,
      'paidAt': now,
      'updatedAt': now,
    });
    batch.set(applicationRef, {
      'paymentStatus': 'paid',
      'paymentId': paymentRef.id,
      'invoiceNumber': invoiceNumber,
      'invoiceUrl': invoiceUrl,
      'paidAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await batch.commit();

    return {
      'paymentId': paymentRef.id,
      'invoiceNumber': invoiceNumber,
      'invoiceUrl': invoiceUrl,
    };
  }

  Future<String> createSponsorshipCheckoutSession({
    required String applicationId,
  }) async {
    final origin = _appBaseUrl();
    final callable = FirebaseFunctions.instance.httpsCallable(
      'createSponsorshipCheckoutSession',
    );

    final response = await callable.call({
      'applicationId': applicationId,
      'successUrl':
          '$origin/#/sponsor/payment-success?applicationId=$applicationId',
      'cancelUrl':
          '$origin/#/sponsor/payment-cancel?applicationId=$applicationId',
    });

    final data = Map<String, dynamic>.from(
      (response.data as Map?) ?? const <String, dynamic>{},
    );
    final url = (data['url'] ?? '').toString();
    if (url.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Stripe checkout URL is missing from function response.',
      );
    }
    return url;
  }

  Future<Map<String, String>> createSponsorshipPaymentIntentData({
    required String applicationId,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'createSponsorshipPaymentIntent',
    );
    final response = await callable.call({'applicationId': applicationId});
    final data = Map<String, dynamic>.from(
      (response.data as Map?) ?? const <String, dynamic>{},
    );
    final paymentIntentClientSecret = (data['paymentIntentClientSecret'] ?? '')
        .toString();
    final customerId = (data['customerId'] ?? '').toString();
    final ephemeralKeySecret = (data['ephemeralKeySecret'] ?? '').toString();
    final merchantDisplayName =
        (data['merchantDisplayName'] ?? 'Video Contest Show').toString();

    if (paymentIntentClientSecret.isEmpty ||
        customerId.isEmpty ||
        ephemeralKeySecret.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Stripe payment data is incomplete.',
      );
    }

    return {
      'paymentIntentClientSecret': paymentIntentClientSecret,
      'customerId': customerId,
      'ephemeralKeySecret': ephemeralKeySecret,
      'merchantDisplayName': merchantDisplayName,
    };
  }

  Future<void> paySponsorshipApplicationWithStripe({
    required String applicationId,
  }) async {
    if (kIsWeb) {
      throw FirebaseFunctionsException(
        code: 'unimplemented',
        message:
            'Use Stripe Checkout on web. PaymentSheet is used on Android/iOS.',
      );
    }

    await _ensureStripeConfigured();

    final data = await createSponsorshipPaymentIntentData(
      applicationId: applicationId,
    );
    final paymentIntentClientSecret =
        data['paymentIntentClientSecret'] ?? '';
    final customerId = data['customerId'] ?? '';
    final ephemeralKeySecret = data['ephemeralKeySecret'] ?? '';
    final merchantDisplayName =
        data['merchantDisplayName'] ?? 'Video Contest Show';

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: merchantDisplayName,
        paymentIntentClientSecret: paymentIntentClientSecret,
        customerId: customerId,
        customerEphemeralKeySecret: ephemeralKeySecret,
        style: ThemeMode.dark,
      ),
    );

    await Stripe.instance.presentPaymentSheet();
  }

  Future<void> openSponsorshipCheckout({
    required String applicationId,
  }) async {
    final url = await createSponsorshipCheckoutSession(
      applicationId: applicationId,
    );
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Failed to launch Stripe checkout.',
      );
    }
  }

  Future<void> confirmSponsorshipPaymentWithCard({
    required String applicationId,
    required String cardholderName,
  }) async {
    if (kIsWeb) {
      final url = await createSponsorshipCheckoutSession(
        applicationId: applicationId,
      );
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }

    await _ensureStripeConfigured();

    final data = await createSponsorshipPaymentIntentData(
      applicationId: applicationId,
    );
    final paymentIntentClientSecret =
        data['paymentIntentClientSecret'] ?? '';
    if (paymentIntentClientSecret.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Stripe payment data is incomplete.',
      );
    }

    await Stripe.instance.confirmPayment(
      paymentIntentClientSecret: paymentIntentClientSecret,
      data: PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(
          billingDetails: BillingDetails(name: cardholderName.trim()),
        ),
      ),
    );
  }

  Future<void> waitForApplicationPaid(
    String applicationId, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final started = DateTime.now();
    while (DateTime.now().difference(started) < timeout) {
      final snap = await _firestore
          .collection('sponsorship_applications')
          .doc(applicationId)
          .get();
      final status = (snap.data()?['paymentStatus'] ?? 'unpaid').toString();
      if (status == 'paid') {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}
