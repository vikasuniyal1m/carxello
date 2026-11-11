import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/models/car.dart';

class ValuationReportScreen extends StatefulWidget {
  final Car car;

  const ValuationReportScreen({super.key, required this.car});

  @override
  State<ValuationReportScreen> createState() => _ValuationReportScreenState();
}

class _ValuationReportScreenState extends State<ValuationReportScreen> {
  int _selectedReportTab = 0; // 0: CARFAX Report, 1: AutoCheck Report

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        title: Text('Valuation Tools - ${widget.car.year} ${widget.car.make} ${widget.car.model}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Schedule inspection text
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Schedule a professional vehicle inspection.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            
            // Report Type Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildReportTabButton('CARFAX Report', 0, _selectedReportTab == 0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildReportTabButton('AutoCheck Report', 1, _selectedReportTab == 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Report Content
            if (_selectedReportTab == 0)
              _buildCarfaxReport()
            else
              _buildAutoCheckReport(),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTabButton(String text, int index, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReportTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[100] : Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarfaxReport() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CARFAX Header
          Row(
            children: [
              Container(
                width: 80,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'CARFAX',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARFAX Vehicle History Report',
                      style: TextStyle(color: Colors.blue[700], fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'VIN : ${widget.car.vin ?? '1HGBH4JXMN109186'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ElevatedButton(
                  onPressed: () {
                    // Handle purchase report
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Redirecting to purchase CARFAX report...'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Purchase Report'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Summary Cards
          _buildSummaryCard(
            'No Accidents Reported',
            'No Damage reported to CARFAX',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            '1 Previous Owner',
            'Personal use vehicle',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Service Records',
            '12 service records available',
            Colors.green,
          ),
          const SizedBox(height: 24),
          
          // Recent Service History
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Service History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildServiceHistoryRow('Oil change service', '01/10/2024 - 44,850 mi'),
                const Divider(height: 24),
                _buildServiceHistoryRow('Tire Rotation', '12/15/2023 - 43,200 mi'),
                const Divider(height: 24),
                _buildServiceHistoryRow('Brake inspection', '10/20/2023 - 41,500 mi'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoCheckReport() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AutoCheck Header
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.blue[700], size: 32),
              const SizedBox(width: 8),
              Text(
                'AutoCheck by Experian',
                style: TextStyle(color: Colors.blue[700], fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Flexible(
                child: ElevatedButton(
                  onPressed: () {
                    // Handle purchase report
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Redirecting to purchase AutoCheck report...'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Purchase Report'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'VIN : ${widget.car.vin ?? '1HGBH4JXMN109186'}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // AutoCheck Score Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      '85',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto Check Score : 85/100',
                        style: TextStyle(color: Colors.blue[700], fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Above average for this vehicle type.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Title Information
          const Text(
            'Title Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Title Brand:', 'Clean Title', Colors.green),
          _buildInfoRow('Lemon History:', 'No', Colors.green),
          _buildInfoRow('Flood Damage:', 'No', Colors.green),
          const SizedBox(height: 24),
          
          // Ownership History
          const Text(
            'Ownership History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Previous Owners:', '1', Colors.green),
          _buildInfoRow('Personal Use:', 'Yes', Colors.green),
          _buildInfoRow('Rental/Fleet:', 'No', Colors.green),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String detail, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color.shade800, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(color: color.shade700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHistoryRow(String service, String dateMileage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          service,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Text(
          dateMileage,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

