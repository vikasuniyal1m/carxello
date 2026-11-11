import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/services/dispute_service.dart';

class DisputeDetailScreen extends StatefulWidget {
  final String disputeId;

  const DisputeDetailScreen({super.key, required this.disputeId});

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  final DisputeService _service = DisputeService();
  Map<String, dynamic>? _dispute;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDispute();
  }

  Future<void> _loadDispute() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _service.getDispute(widget.disputeId);
      setState(() {
        _dispute = data['dispute'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dispute: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_review':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        title: const Text('Dispute Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dispute == null
              ? const Center(child: Text('Dispute not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(_dispute!['status'] as String).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (_dispute!['status'] as String).toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(_dispute!['status'] as String),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Vehicle Details
                      const Text(
                        'Vehicle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailCard('Make/Model', '${_dispute!['vehicle']['year']} ${_dispute!['vehicle']['make']} ${_dispute!['vehicle']['model']}'),
                      _buildDetailCard('VIN', _dispute!['vehicle']['vin'] ?? 'N/A'),
                      const SizedBox(height: 24),
                      // Dispute Details
                      const Text(
                        'Dispute Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailCard(
                        'Type',
                        (_dispute!['dispute_type'] as String).replaceAll('_', ' ').toUpperCase(),
                      ),
                      _buildDetailCard('Description', _dispute!['description'] as String),
                      const SizedBox(height: 24),
                      // Parties
                      const Text(
                        'Parties',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_dispute!['buyer'] != null)
                        _buildDetailCard('Buyer', _dispute!['buyer']['name'] as String),
                      if (_dispute!['seller'] != null)
                        _buildDetailCard('Seller', _dispute!['seller']['name'] as String),
                      if (_dispute!['resolution'] != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resolution',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(_dispute!['resolution'] as String),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Created: ${DateTime.parse(_dispute!['created_at'] as String).toString().split('T')[0]}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kBlackColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

