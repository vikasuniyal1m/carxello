import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/services/dispute_service.dart';
import 'package:carauction/screens/create_dispute_screen.dart';
import 'package:carauction/screens/dispute_detail_screen.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  final DisputeService _service = DisputeService();
  List<Map<String, dynamic>> _disputes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final disputes = await _service.getDisputes();
      setState(() {
        _disputes = disputes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load disputes: ${e.toString()}'),
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
        title: const Text('Disputes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateDisputeScreen(),
                ),
              ).then((_) => _loadDisputes());
            },
            tooltip: 'Create Dispute',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _disputes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gavel, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No disputes found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a dispute if you have issues with a purchase',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDisputes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _disputes.length,
                    itemBuilder: (context, index) {
                      final dispute = _disputes[index];
                      return _buildDisputeCard(dispute);
                    },
                  ),
                ),
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> dispute) {
    final vehicle = dispute['vehicle'] as Map<String, dynamic>;
    final status = dispute['status'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DisputeDetailScreen(disputeId: dispute['id'].toString()),
            ),
          ).then((_) => _loadDisputes());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                        const SizedBox(height: 4),
                        Text(
                          dispute['dispute_type'].toString().replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                dispute['description'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                'Created: ${DateTime.parse(dispute['created_at'] as String).toString().split('T')[0]}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

