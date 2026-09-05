import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentConfigModel {
  final String id;
  final String bankName;
  final String accountTitle;
  final String accountNumber;
  final String iban;
  final String easypaisaTitle;
  final String easypaisaNumber;
  final String jazzcashTitle;
  final String jazzcashNumber;
  final String paymentInstructions;
  final bool isBankTransferEnabled;
  final bool isEasypaisaEnabled;
  final bool isJazzcashEnabled;
  final bool isGatewayEnabled;
  final DateTime? updatedAt;

  PaymentConfigModel({
    this.id = 'academy_payment_config',
    required this.bankName,
    required this.accountTitle,
    required this.accountNumber,
    required this.iban,
    required this.easypaisaTitle,
    required this.easypaisaNumber,
    required this.jazzcashTitle,
    required this.jazzcashNumber,
    required this.paymentInstructions,
    this.isBankTransferEnabled = true,
    this.isEasypaisaEnabled = true,
    this.isJazzcashEnabled = true,
    this.isGatewayEnabled = false,
    this.updatedAt,
  });

  factory PaymentConfigModel.defaultConfig() {
    return PaymentConfigModel(
      bankName: 'Meezan Bank Ltd.',
      accountTitle: 'Quaid Academy Official',
      accountNumber: '01020304050607',
      iban: 'PK36MEZN0001020304050607',
      easypaisaTitle: 'Quaid Academy Merchant',
      easypaisaNumber: '03001234567',
      jazzcashTitle: 'Quaid Academy Merchant',
      jazzcashNumber: '03011234567',
      paymentInstructions:
          '1. Transfer exact fee amount via Online Banking, Easypaisa, or JazzCash.\n'
          '2. Enter your Transaction Reference ID / Order ID in the payment submission form.\n'
          '3. Our Finance Department will verify your transaction within 24 hours.',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bankName': bankName,
      'accountTitle': accountTitle,
      'accountNumber': accountNumber,
      'iban': iban,
      'easypaisaTitle': easypaisaTitle,
      'easypaisaNumber': easypaisaNumber,
      'jazzcashTitle': jazzcashTitle,
      'jazzcashNumber': jazzcashNumber,
      'paymentInstructions': paymentInstructions,
      'isBankTransferEnabled': isBankTransferEnabled,
      'isEasypaisaEnabled': isEasypaisaEnabled,
      'isJazzcashEnabled': isJazzcashEnabled,
      'isGatewayEnabled': isGatewayEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PaymentConfigModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return PaymentConfigModel.defaultConfig();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentConfigModel(
      id: doc.id,
      bankName: data['bankName'] as String? ?? 'Meezan Bank Ltd.',
      accountTitle: data['accountTitle'] as String? ?? 'Quaid Academy Official',
      accountNumber: data['accountNumber'] as String? ?? '01020304050607',
      iban: data['iban'] as String? ?? 'PK36MEZN0001020304050607',
      easypaisaTitle: data['easypaisaTitle'] as String? ?? 'Quaid Academy Merchant',
      easypaisaNumber: data['easypaisaNumber'] as String? ?? '03001234567',
      jazzcashTitle: data['jazzcashTitle'] as String? ?? 'Quaid Academy Merchant',
      jazzcashNumber: data['jazzcashNumber'] as String? ?? '03011234567',
      paymentInstructions: data['paymentInstructions'] as String? ??
          'Transfer exact fee amount and enter the reference number for verification.',
      isBankTransferEnabled: data['isBankTransferEnabled'] as bool? ?? true,
      isEasypaisaEnabled: data['isEasypaisaEnabled'] as bool? ?? true,
      isJazzcashEnabled: data['isJazzcashEnabled'] as bool? ?? true,
      isGatewayEnabled: data['isGatewayEnabled'] as bool? ?? false,
      updatedAt: data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
