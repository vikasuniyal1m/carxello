import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/swap_offer_service.dart';

/// Shows swap offer status (Pending / Accepted / Rejected) and offer details for the buyer.
class SwapOfferStatusScreen extends StatefulWidget {
  final Car car;
  final Map<String, dynamic>? initialOffer;

  const SwapOfferStatusScreen({
    super.key,
    required this.car,
    this.initialOffer,
  });

  @override
  State<SwapOfferStatusScreen> createState() => _SwapOfferStatusScreenState();
}

class _SwapOfferStatusScreenState extends State<SwapOfferStatusScreen> {
  final SwapOfferService _swapOfferService = SwapOfferService();
  Map<String, dynamic>? _offer;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _offer = widget.initialOffer;
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    setState(() {
      _error = null;
      if (_offer == null) _isLoading = true;
    });
    try {
      final data = await _swapOfferService.getMySwapOffer(widget.car.id.toString());
      if (mounted) {
        setState(() {
          _offer = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  (Color color, IconData icon, String text) _statusStyle(String? raw) {
    final status = (raw ?? '').toString().toLowerCase().trim();
    switch (status) {
      case 'accepted':
        return (Colors.green, Icons.check_circle, 'Accepted');
      case 'rejected':
        return (Colors.red, Icons.cancel, 'Rejected');
      case 'pending':
      default:
        return (Colors.orange, Icons.schedule, 'Pending');
    }
  }

  String _formatNumber(num? n) {
    if (n == null) return '0';
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Swap Offer Status'),
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading && _offer == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOffer,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700], fontSize: 14),
                        ),
                      ),
                    if (_offer == null && !_isLoading)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No swap offer found for this vehicle.'),
                        ),
                      )
                    else if (_offer != null) ...[
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      _buildOfferDetailsCard(),
                      const SizedBox(height: 16),
                      _buildTargetVehicleCard(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final status = _offer!['status'] as String? ?? 'pending';
    final (color, icon, text) = _statusStyle(status);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status == 'pending'
                  ? 'Seller will review your swap offer'
                  : status == 'accepted'
                      ? 'Seller has accepted your swap offer'
                      : 'Seller has declined your swap offer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferDetailsCard() {
    final vin = _offer!['buyer_vehicle_vin'] as String? ?? '—';
    final value = (_offer!['buyer_vehicle_value'] as num?)?.toDouble() ?? 0.0;
    final additional = (_offer!['additional_payment'] as num?)?.toDouble() ?? 0.0;
    final total = (_offer!['total_offer'] as num?)?.toDouble() ?? 0.0;
    final offerId = _offer!['id']?.toString() ?? '—';
    final createdAt = _offer!['created_at']?.toString();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offer Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            _detailRow('Offer ID', '#$offerId'),
            _detailRow('Your Vehicle VIN', vin),
            _detailRow('Your Vehicle Value', '\$${_formatNumber(value)}'),
            _detailRow('Additional Payment', '\$${_formatNumber(additional)}'),
            _detailRow('Total Offer Value', '\$${_formatNumber(total)}'),
            if (createdAt != null && createdAt.isNotEmpty)
              _detailRow('Submitted', createdAt),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetVehicleCard() {
    final car = widget.car;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target Vehicle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            _detailRow('Vehicle', '${car.year} ${car.make} ${car.model}'),
            _detailRow('VIN', car.vin ?? '—'),
            _detailRow('Price', '\$${_formatNumber(car.buyNowPrice ?? car.startingBid)}'),
            _detailRow('Mileage', '${_formatNumber(car.mileage)} mi'),
          ],
        ),
      ),
    );
  }
}
