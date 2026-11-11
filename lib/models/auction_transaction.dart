import 'package:flutter/foundation.dart';

/// Represents the status of an auction transaction in the escrow workflow
enum TransactionStatus {
  /// 1. Auction has ended, winner is being determined
  auctionEnded,
  
  /// 2. Winner has been notified
  winnerNotified,
  
  /// 3. Invoice has been generated for the winner
  invoiceGenerated,
  
  /// 4. Buyer is processing payment
  buyerPaymentProcessing,
  
  /// 5. Funds are held in escrow (trust account)
  fundsHeldInEscrow,
  
  /// 6. Seller has shipped the vehicle
  sellerShipsVehicle,
  
  /// 7. Buyer has confirmed receipt of vehicle
  buyerConfirmsReceipt,
  
  /// 8. Funds released to seller
  fundsReleasedToSeller,
  
  /// 9. Platform fee has been deducted
  platformFeeDeducted,
  
  /// 10. Transaction is complete
  transactionComplete,
  
  /// Transaction was cancelled or disputed
  cancelled,
  
  /// Transaction is under dispute
  disputed,
}

/// Extension to get display information for each status
extension TransactionStatusExtension on TransactionStatus {
  /// Get the display name for this status
  String get displayName {
    switch (this) {
      case TransactionStatus.auctionEnded:
        return 'Auction Ended';
      case TransactionStatus.winnerNotified:
        return 'Winner Notified';
      case TransactionStatus.invoiceGenerated:
        return 'Invoice Generated';
      case TransactionStatus.buyerPaymentProcessing:
        return 'Payment Processing';
      case TransactionStatus.fundsHeldInEscrow:
        return 'Funds in Escrow';
      case TransactionStatus.sellerShipsVehicle:
        return 'Vehicle Shipping';
      case TransactionStatus.buyerConfirmsReceipt:
        return 'Buyer Confirmation';
      case TransactionStatus.fundsReleasedToSeller:
        return 'Funds Released';
      case TransactionStatus.platformFeeDeducted:
        return 'Fee Deducted';
      case TransactionStatus.transactionComplete:
        return 'Transaction Complete';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.disputed:
        return 'Under Dispute';
    }
  }

  /// Get description for this status
  String get description {
    switch (this) {
      case TransactionStatus.auctionEnded:
        return 'Auction has ended. Determining the winning bidder.';
      case TransactionStatus.winnerNotified:
        return 'Winner has been notified and invoice is being prepared.';
      case TransactionStatus.invoiceGenerated:
        return 'Invoice generated. Awaiting buyer payment.';
      case TransactionStatus.buyerPaymentProcessing:
        return 'Payment is being processed securely.';
      case TransactionStatus.fundsHeldInEscrow:
        return 'Funds are safely held in escrow until delivery is confirmed.';
      case TransactionStatus.sellerShipsVehicle:
        return 'Seller is preparing and shipping the vehicle.';
      case TransactionStatus.buyerConfirmsReceipt:
        return 'Buyer to confirm vehicle receipt and condition.';
      case TransactionStatus.fundsReleasedToSeller:
        return 'Funds are being transferred to the seller.';
      case TransactionStatus.platformFeeDeducted:
        return 'Platform fee has been deducted from the transaction.';
      case TransactionStatus.transactionComplete:
        return 'Transaction is complete. Thank you for using our platform!';
      case TransactionStatus.cancelled:
        return 'Transaction has been cancelled.';
      case TransactionStatus.disputed:
        return 'Transaction is under dispute resolution.';
    }
  }

  /// Get the step number (1-10) for this status, or null if not part of main flow
  int? get stepNumber {
    switch (this) {
      case TransactionStatus.auctionEnded:
        return 1;
      case TransactionStatus.winnerNotified:
        return 2;
      case TransactionStatus.invoiceGenerated:
        return 3;
      case TransactionStatus.buyerPaymentProcessing:
        return 4;
      case TransactionStatus.fundsHeldInEscrow:
        return 5;
      case TransactionStatus.sellerShipsVehicle:
        return 6;
      case TransactionStatus.buyerConfirmsReceipt:
        return 7;
      case TransactionStatus.fundsReleasedToSeller:
        return 8;
      case TransactionStatus.platformFeeDeducted:
        return 9;
      case TransactionStatus.transactionComplete:
        return 10;
      default:
        return null;
    }
  }

  /// Check if this status is part of the main transaction flow
  bool get isMainFlow => stepNumber != null;

  /// Check if this status is completed/final
  bool get isFinal => this == TransactionStatus.transactionComplete || 
                      this == TransactionStatus.cancelled;

  /// Check if this status indicates an active/pending state
  bool get isActive => !isFinal && this != TransactionStatus.disputed;
}

/// Represents a financial breakdown in the transaction
class TransactionFinancials {
  final double vehiclePrice;
  final double platformFee;
  final double platformFeePercentage;
  final double? shippingCost;
  final double? taxAmount;
  final double? otherFees;
  final double totalAmount;
  final double sellerReceives;

  const TransactionFinancials({
    required this.vehiclePrice,
    required this.platformFee,
    required this.platformFeePercentage,
    this.shippingCost,
    this.taxAmount,
    this.otherFees,
    required this.totalAmount,
    required this.sellerReceives,
  });

  factory TransactionFinancials.fromJson(Map<String, dynamic> json) {
    return TransactionFinancials(
      vehiclePrice: (json['vehicle_price'] as num).toDouble(),
      platformFee: (json['platform_fee'] as num).toDouble(),
      platformFeePercentage: (json['platform_fee_percentage'] as num).toDouble(),
      shippingCost: json['shipping_cost'] != null ? (json['shipping_cost'] as num).toDouble() : null,
      taxAmount: json['tax_amount'] != null ? (json['tax_amount'] as num).toDouble() : null,
      otherFees: json['other_fees'] != null ? (json['other_fees'] as num).toDouble() : null,
      totalAmount: (json['total_amount'] as num).toDouble(),
      sellerReceives: (json['seller_receives'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_price': vehiclePrice,
      'platform_fee': platformFee,
      'platform_fee_percentage': platformFeePercentage,
      'shipping_cost': shippingCost,
      'tax_amount': taxAmount,
      'other_fees': otherFees,
      'total_amount': totalAmount,
      'seller_receives': sellerReceives,
    };
  }
}

/// Represents shipping/tracking information
class ShippingInfo {
  final String? carrier;
  final String? trackingNumber;
  final DateTime? shippedAt;
  final DateTime? estimatedDelivery;
  final DateTime? deliveredAt;
  final String? pickupLocation;
  final String? deliveryLocation;
  final String? specialInstructions;

  const ShippingInfo({
    this.carrier,
    this.trackingNumber,
    this.shippedAt,
    this.estimatedDelivery,
    this.deliveredAt,
    this.pickupLocation,
    this.deliveryLocation,
    this.specialInstructions,
  });

  factory ShippingInfo.fromJson(Map<String, dynamic> json) {
    return ShippingInfo(
      carrier: json['carrier'],
      trackingNumber: json['tracking_number'],
      shippedAt: json['shipped_at'] != null ? DateTime.parse(json['shipped_at']) : null,
      estimatedDelivery: json['estimated_delivery'] != null ? DateTime.parse(json['estimated_delivery']) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at']) : null,
      pickupLocation: json['pickup_location'],
      deliveryLocation: json['delivery_location'],
      specialInstructions: json['special_instructions'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'carrier': carrier,
      'tracking_number': trackingNumber,
      'shipped_at': shippedAt?.toIso8601String(),
      'estimated_delivery': estimatedDelivery?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'pickup_location': pickupLocation,
      'delivery_location': deliveryLocation,
      'special_instructions': specialInstructions,
    };
  }
}

/// Main model representing an auction transaction with escrow workflow
class AuctionTransaction {
  final String id;
  final String auctionId;
  final String vehicleId;
  final String? vehicleTitle;
  final String? vehicleImageUrl;
  final String buyerId;
  final String? buyerName;
  final String sellerId;
  final String? sellerName;
  final TransactionStatus status;
  final TransactionFinancials financials;
  final ShippingInfo? shippingInfo;
  final String? invoiceId;
  final String? paymentReference;
  final DateTime? paymentProcessedAt;
  final DateTime? escrowReleasedAt;
  final DateTime? buyerConfirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
  final bool buyerConfirmationReceived;
  final bool sellerFundsReleased;

  const AuctionTransaction({
    required this.id,
    required this.auctionId,
    required this.vehicleId,
    this.vehicleTitle,
    this.vehicleImageUrl,
    required this.buyerId,
    this.buyerName,
    required this.sellerId,
    this.sellerName,
    required this.status,
    required this.financials,
    this.shippingInfo,
    this.invoiceId,
    this.paymentReference,
    this.paymentProcessedAt,
    this.escrowReleasedAt,
    this.buyerConfirmedAt,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.buyerConfirmationReceived = false,
    this.sellerFundsReleased = false,
  });

  factory AuctionTransaction.fromJson(Map<String, dynamic> json) {
    return AuctionTransaction(
      id: json['id'],
      auctionId: json['auction_id'],
      vehicleId: json['vehicle_id'],
      vehicleTitle: json['vehicle_title'],
      vehicleImageUrl: json['vehicle_image_url'],
      buyerId: json['buyer_id'],
      buyerName: json['buyer_name'],
      sellerId: json['seller_id'],
      sellerName: json['seller_name'],
      status: TransactionStatus.values.byName(json['status']),
      financials: TransactionFinancials.fromJson(json['financials']),
      shippingInfo: json['shipping_info'] != null 
          ? ShippingInfo.fromJson(json['shipping_info']) 
          : null,
      invoiceId: json['invoice_id'],
      paymentReference: json['payment_reference'],
      paymentProcessedAt: json['payment_processed_at'] != null 
          ? DateTime.parse(json['payment_processed_at']) 
          : null,
      escrowReleasedAt: json['escrow_released_at'] != null 
          ? DateTime.parse(json['escrow_released_at']) 
          : null,
      buyerConfirmedAt: json['buyer_confirmed_at'] != null 
          ? DateTime.parse(json['buyer_confirmed_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      notes: json['notes'],
      buyerConfirmationReceived: json['buyer_confirmation_received'] ?? false,
      sellerFundsReleased: json['seller_funds_released'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auction_id': auctionId,
      'vehicle_id': vehicleId,
      'vehicle_title': vehicleTitle,
      'vehicle_image_url': vehicleImageUrl,
      'buyer_id': buyerId,
      'buyer_name': buyerName,
      'seller_id': sellerId,
      'seller_name': sellerName,
      'status': status.name,
      'financials': financials.toJson(),
      'shipping_info': shippingInfo?.toJson(),
      'invoice_id': invoiceId,
      'payment_reference': paymentReference,
      'payment_processed_at': paymentProcessedAt?.toIso8601String(),
      'escrow_released_at': escrowReleasedAt?.toIso8601String(),
      'buyer_confirmed_at': buyerConfirmedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'notes': notes,
      'buyer_confirmation_received': buyerConfirmationReceived,
      'seller_funds_released': sellerFundsReleased,
    };
  }

  /// Create a copy of this transaction with updated fields
  AuctionTransaction copyWith({
    TransactionStatus? status,
    ShippingInfo? shippingInfo,
    String? invoiceId,
    String? paymentReference,
    DateTime? paymentProcessedAt,
    DateTime? escrowReleasedAt,
    DateTime? buyerConfirmedAt,
    DateTime? updatedAt,
    String? notes,
    bool? buyerConfirmationReceived,
    bool? sellerFundsReleased,
  }) {
    return AuctionTransaction(
      id: id,
      auctionId: auctionId,
      vehicleId: vehicleId,
      vehicleTitle: vehicleTitle,
      vehicleImageUrl: vehicleImageUrl,
      buyerId: buyerId,
      buyerName: buyerName,
      sellerId: sellerId,
      sellerName: sellerName,
      status: status ?? this.status,
      financials: financials,
      shippingInfo: shippingInfo ?? this.shippingInfo,
      invoiceId: invoiceId ?? this.invoiceId,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentProcessedAt: paymentProcessedAt ?? this.paymentProcessedAt,
      escrowReleasedAt: escrowReleasedAt ?? this.escrowReleasedAt,
      buyerConfirmedAt: buyerConfirmedAt ?? this.buyerConfirmedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      buyerConfirmationReceived: buyerConfirmationReceived ?? this.buyerConfirmationReceived,
      sellerFundsReleased: sellerFundsReleased ?? this.sellerFundsReleased,
    );
  }

  /// Check if buyer action is required
  bool get isBuyerActionRequired {
    return status == TransactionStatus.invoiceGenerated ||
           status == TransactionStatus.buyerConfirmsReceipt;
  }

  /// Check if seller action is required
  bool get isSellerActionRequired {
    return status == TransactionStatus.fundsHeldInEscrow;
  }

  /// Get the expected next status in the workflow
  TransactionStatus? get expectedNextStatus {
    switch (status) {
      case TransactionStatus.auctionEnded:
        return TransactionStatus.winnerNotified;
      case TransactionStatus.winnerNotified:
        return TransactionStatus.invoiceGenerated;
      case TransactionStatus.invoiceGenerated:
        return TransactionStatus.buyerPaymentProcessing;
      case TransactionStatus.buyerPaymentProcessing:
        return TransactionStatus.fundsHeldInEscrow;
      case TransactionStatus.fundsHeldInEscrow:
        return TransactionStatus.sellerShipsVehicle;
      case TransactionStatus.sellerShipsVehicle:
        return TransactionStatus.buyerConfirmsReceipt;
      case TransactionStatus.buyerConfirmsReceipt:
        return TransactionStatus.fundsReleasedToSeller;
      case TransactionStatus.fundsReleasedToSeller:
        return TransactionStatus.platformFeeDeducted;
      case TransactionStatus.platformFeeDeducted:
        return TransactionStatus.transactionComplete;
      default:
        return null;
    }
  }
}
