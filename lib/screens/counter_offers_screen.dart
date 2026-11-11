import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/services/counter_offer_service.dart';
import 'package:carauction/models/car.dart';

class CounterOffersScreen extends StatefulWidget {
  final String? vehicleId;
  final bool forBuyer;

  const CounterOffersScreen({super.key, this.vehicleId, this.forBuyer = false});

  @override
  State<CounterOffersScreen> createState() => _CounterOffersScreenState();
}

class _CounterOffersScreenState extends State<CounterOffersScreen> {
  final CounterOfferService _service = CounterOfferService();
  List<Map<String, dynamic>> _counterOffers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounterOffers();
  }

  Future<void> _loadCounterOffers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final offers = await _service.getCounterOffers(
        vehicleId: widget.vehicleId,
        forBuyer: widget.forBuyer,
      );
      setState(() {
        _counterOffers = offers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load counter offers: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acceptOffer(String offerId) async {
    try {
      await _service.acceptCounterOffer(offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Counter offer accepted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCounterOffers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectOffer(String offerId) async {
    try {
      await _service.rejectCounterOffer(offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Counter offer rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadCounterOffers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        title: Text(widget.forBuyer ? 'Counter Offers' : 'My Counter Offers'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _counterOffers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No counter offers found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.forBuyer
                              ? 'Counter offers from sellers will appear here'
                              : 'Create counter offers for your vehicles',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCounterOffers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _counterOffers.length,
                    itemBuilder: (context, index) {
                      final offer = _counterOffers[index];
                      return _buildOfferCard(offer);
                    },
                  ),
                ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final vehicle = offer['vehicle'] as Map<String, dynamic>;
    final status = offer['status'] as String;
    final isPending = status == 'pending';
    final expiresAt = offer['expires_at'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (vehicle['image_url'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      vehicle['image_url'] as String,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.car_rental, size: 40),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.car_rental, size: 40),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${vehicle['year']} ${vehicle['make']} ${vehicle['model']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Counter Offer: ${_formatCurrency((offer['counter_amount'] as num).toDouble())}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kAccentColor,
                        ),
                      ),
                      if (offer['message'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          offer['message'] as String,
                          style: TextStyle(color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'accepted'
                        ? Colors.green[100]
                        : status == 'rejected'
                            ? Colors.red[100]
                            : Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: status == 'accepted'
                          ? Colors.green[800]
                          : status == 'rejected'
                              ? Colors.red[800]
                              : Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (expiresAt != null && isPending)
                  Text(
                    'Expires: ${DateTime.parse(expiresAt).toString().split(' ')[0]}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
            if (widget.forBuyer && isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectOffer(offer['id'].toString()),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red[300]!),
                      ),
                      child: Text(
                        'Reject',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptOffer(offer['id'].toString()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

