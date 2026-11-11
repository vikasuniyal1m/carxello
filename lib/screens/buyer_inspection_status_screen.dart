import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:carauction/screens/view_report_screen.dart';
import 'package:intl/intl.dart';

/// Buyer-facing inspection portal: shows status (Pending, Accepted, Assigned, In Progress, Completed)
/// and inspection details below.
class BuyerInspectionStatusScreen extends StatefulWidget {
  final Car car;
  final Map<String, dynamic>? initialInspection;

  const BuyerInspectionStatusScreen({
    super.key,
    required this.car,
    this.initialInspection,
  });

  @override
  State<BuyerInspectionStatusScreen> createState() => _BuyerInspectionStatusScreenState();
}

class _BuyerInspectionStatusScreenState extends State<BuyerInspectionStatusScreen> {
  final InspectionService _inspectionService = InspectionService();
  Map<String, dynamic>? _inspection;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inspection = widget.initialInspection;
    _loadInspection();
  }

  Future<void> _loadInspection() async {
    if (widget.initialInspection != null && !_isLoading) {
      setState(() => _isLoading = true);
    }
    setState(() {
      _error = null;
      if (_inspection == null) _isLoading = true;
    });
    try {
      final result = await _inspectionService.getVehicleInspection(widget.car.id.toString());
      if (mounted) {
        setState(() {
          Map<String, dynamic>? picked;
          if (result['inspection'] is Map<String, dynamic>) {
            picked = result['inspection'] as Map<String, dynamic>;
          } else if (result['inspections'] is List) {
            final list = List<Map<String, dynamic>>.from(result['inspections'] as List);
            if (list.isNotEmpty) {
              list.sort((a, b) {
                final as = (a['status'] ?? '').toString().toLowerCase();
                final bs = (b['status'] ?? '').toString().toLowerCase();
                if (as == 'completed' && bs != 'completed') return -1;
                if (bs == 'completed' && as != 'completed') return 1;
                DateTime? ad;
                DateTime? bd;
                try { ad = DateTime.parse((a['completed_at'] ?? a['created_at'] ?? '').toString()); } catch (_) {}
                try { bd = DateTime.parse((b['completed_at'] ?? b['created_at'] ?? '').toString()); } catch (_) {}
                if (ad != null && bd != null) return bd.compareTo(ad);
                return 0;
              });
              picked = list.first;
            }
          }
          _inspection = picked;
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

  (Color color, IconData icon, String text, double progress) _statusStyle(String? raw) {
    final status = (raw ?? '').toString().toLowerCase().trim();
    switch (status) {
      case 'completed':
        return (kThemeColorBlue, Icons.check_circle, 'Completed', 1.0);
      case 'in_progress':
        return (kThemeColor2, Icons.hourglass_empty, 'In Progress', 0.75);
      case 'assigned':
        return (kThemeColor3, Icons.person_add, 'Assigned', 0.5);
      case 'accepted':
        return (kAccentColor, Icons.check_circle_outline, 'Accepted', 0.25);
      case 'pending':
      case 'requested':
        return (kThemeColor3.withOpacity(0.8), status == 'requested' ? Icons.schedule : Icons.pending, status == 'requested' ? 'Requested' : 'Pending', 0.1);
      default:
        return (Colors.grey[400]!, Icons.info_outline, raw != null && raw.toString().isNotEmpty ? raw.toString() : 'Unknown', 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: kBlackColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Inspection Status',
          style: TextStyle(
            color: kBlackColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        toolbarHeight: 56,
      ),
      body: _isLoading && _inspection == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) // Added strokeWidth
          : RefreshIndicator(
        onRefresh: _loadInspection,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12), // Pehle 16 tha
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12), // Pehle 16 tha
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red[700], fontSize: 13), // Pehle 14 tha
                  ),
                ),
              if (_inspection == null && !_isLoading)
                Card(
                  elevation: 1, // Added
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Added
                  child: const Padding(
                    padding: EdgeInsets.all(20), // Pehle 24 tha
                    child: Text('No inspection request found for this vehicle.', style: TextStyle(fontSize: 14)), // Added fontSize
                  ),
                )
              else if (_inspection != null) ...[
                _buildStatusCard(),
                const SizedBox(height: 12),
                _buildInspectionDetailsCard(),
                if (_isCompleted) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewReportScreen(
                              car: widget.car,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.description, size: 16),
                      label: const Text('View Inspection Report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _isCompleted {
    final s = (_inspection?['status'] ?? '').toString().toLowerCase().trim();
    return s == 'completed';
  }

  Widget _buildStatusCard() {
    final raw = _inspection!['status']?.toString();
    final (color, icon, text, progress) = _statusStyle(raw);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey[100],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Icon(icon, color: color, size: 32),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'INSPECTION STATUS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            if (progress < 1.0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).toInt()}% Complete',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionDetailsCard() {
    final Map<String, dynamic> inspection = _inspection!;
    final List<Widget> rows = [];

    void addRow(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.5,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: kBlackColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ));
    }

    if (inspection['scheduled_date'] != null) {
      try {
        final d = DateTime.parse(inspection['scheduled_date'].toString()).toUtc().subtract(const Duration(hours: 5));
        addRow('Scheduled Date', DateFormat('MMM d, yyyy').format(d));
        addRow('Scheduled Time', DateFormat('h:mm a').format(d));
      } catch (_) {
        addRow('Scheduled Date', inspection['scheduled_date'].toString());
      }
    }
    if (inspection['created_at'] != null) {
      try {
        final d = DateTime.parse(inspection['created_at'].toString()).toUtc().subtract(const Duration(hours: 5));
        addRow('Requested On', DateFormat('MMM d, yyyy @ h:mm a').format(d));
      } catch (_) {}
    }
    addRow('Location', inspection['location']?.toString());
    addRow('Inspector Address', inspection['inspector_address']?.toString());
    addRow('Inspector', inspection['inspector_name']?.toString());
    addRow('Inspector Email', inspection['inspector_email']?.toString());
    addRow('Inspector Phone', inspection['inspector_phone']?.toString());
    addRow('Instructions', inspection['instructions']?.toString());

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kAccentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.assignment_outlined, color: kAccentColor, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'INSPECTION DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w800,
                    color: kBlackColor,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            const SizedBox(height: 6),
            if (rows.isEmpty)
              const Text(
                'No additional details available.',
                style: TextStyle(fontSize: 13, color: Colors.grey), // Pehle 14 tha
              )
            else
              ...rows,
          ],
        ),
      ),
    );
  }
}
