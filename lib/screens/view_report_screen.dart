import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/inspection_service.dart';
import 'package:carauction/utils/image_helper.dart';
import 'package:carauction/screens/login_screen.dart';

class ViewReportScreen extends StatefulWidget {
  final Car car;
  final String? inspectionId; // Optional inspection ID

  const ViewReportScreen({
    super.key,
    required this.car,
    this.inspectionId,
  });

  @override
  State<ViewReportScreen> createState() => _ViewReportScreenState();
}

class _ViewReportScreenState extends State<ViewReportScreen> {
  int _selectedTab = 0; // 0: Inspection Report, 1: Vehicle History, 2: Documents
  final InspectionService _inspectionService = InspectionService();
  Map<String, dynamic>? _inspectionDetails;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInspectionDetails();
  }

  Future<void> _loadInspectionDetails() async {
    if (widget.inspectionId == null) {
      try {
        final vehicleInspection = await _inspectionService.getVehicleInspection(widget.car.id);
        if (vehicleInspection != null) {
          String? inspectionId;
          Map<String, dynamic>? inline;
          if (vehicleInspection['inspection'] is Map<String, dynamic>) {
            final obj = vehicleInspection['inspection'] as Map<String, dynamic>;
            inspectionId = obj['id']?.toString();
            inline = obj;
          } else if (vehicleInspection['inspections'] is List) {
            final list = List<Map<String, dynamic>>.from(vehicleInspection['inspections'] as List);
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
              inline = list.first;
              inspectionId = inline['id']?.toString();
            }
          }
          if (inline != null && (inline['report'] != null || inline['inspection_data'] != null)) {
            setState(() {
              _inspectionDetails = inline;
              _isLoading = false;
            });
            return;
          }
          if (inspectionId != null) {
            await _fetchInspectionDetails(inspectionId);
            return;
          }
        }
      } catch (e) {
        print('Could not get vehicle inspection: $e');
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'No inspection found for this vehicle';
      });
    } else {
      await _fetchInspectionDetails(widget.inspectionId!);
    }
  }

  Future<void> _fetchInspectionDetails(String inspectionId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final details = await _inspectionService.getInspectionDetails(inspectionId);
      Map<String, dynamic>? data = details['inspection'] as Map<String, dynamic>?;
      if (data != null && data['report'] == null && data['reports'] is List && (data['reports'] as List).isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(data['reports'] as List);
        list.sort((a, b) {
          DateTime? ad;
          DateTime? bd;
          try { ad = DateTime.parse((a['created_at'] ?? '').toString()); } catch (_) {}
          try { bd = DateTime.parse((b['created_at'] ?? '').toString()); } catch (_) {}
          if (ad != null && bd != null) return bd.compareTo(ad);
          return 0;
        });
        data = Map<String, dynamic>.from(data);
        data!['report'] = list.first;
        if (data['photos'] == null && list.first['photos'] != null) {
          data['photos'] = list.first['photos'];
        }
      }
      setState(() {
        _inspectionDetails = data;
        _isLoading = false;
      });
    } catch (e) {
      final errStr = e.toString();
      final looksUnauthorized = errStr.contains('Unauthorized') || errStr.contains('403');
      if (looksUnauthorized) {
        try {
          final alt = await _inspectionService.getVehicleInspection(widget.car.id);
          Map<String, dynamic>? picked;
          if (alt['inspection'] is Map<String, dynamic>) {
            picked = alt['inspection'] as Map<String, dynamic>;
          } else if (alt['inspections'] is List) {
            final list = List<Map<String, dynamic>>.from(alt['inspections'] as List);
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
          if (picked != null) {
            if (picked['report'] == null && picked['reports'] is List && (picked['reports'] as List).isNotEmpty) {
              final rlist = List<Map<String, dynamic>>.from(picked['reports'] as List);
              rlist.sort((a, b) {
                DateTime? ad;
                DateTime? bd;
                try { ad = DateTime.parse((a['created_at'] ?? '').toString()); } catch (_) {}
                try { bd = DateTime.parse((b['created_at'] ?? '').toString()); } catch (_) {}
                if (ad != null && bd != null) return bd.compareTo(ad);
                return 0;
              });
              picked = Map<String, dynamic>.from(picked);
              picked['report'] = rlist.first;
              if (picked['photos'] == null && rlist.first['photos'] != null) {
                picked['photos'] = rlist.first['photos'];
              }
            }
            setState(() {
              _inspectionDetails = picked;
              _isLoading = false;
            });
            return;
          }
        } catch (e2) {
          // Fall through to show original error below
          print('Fallback load by vehicle failed: $e2');
        }
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load inspection details: $errStr';
      });
      print('Error loading inspection details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for better card contrast
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1, // Subtle shadow for premium feel
        toolbarHeight: 60,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kBlackColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'Vehicle Report',
          style: const TextStyle(
            color: kBlackColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                        if (_errorMessage!.toLowerCase().contains('unauthorized')) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
                            child: const Text('Login to view report', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Modern Header with Car Identity
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        '${widget.car.year} ${widget.car.make} ${widget.car.model}'.trim().toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kAccentColor, letterSpacing: 1.1),
                      ),
                    ),
                    // Modern Tabs
                    _buildTabs(),
                    
                    // Content
                    Expanded(
                      child: _buildTabContent(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Inspection', 'History', 'Documents'];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  print('Tab clicked: $index');
                  setState(() => _selectedTab = index);
                },
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          color: isSelected ? kBlackColor : Colors.grey[400],
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? kAccentColor : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildInspectionReport();
      case 1:
        return _buildVehicleHistory();
      case 2:
        return _buildDocuments();
      default:
        return _buildInspectionReport();
    }
  }

  Widget _buildInspectionReport() {
    if (_inspectionDetails == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No inspection details available',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final top = _inspectionDetails!;
    final report = (top['report'] as Map<String, dynamic>?) ??
        (top['detailed_report'] as Map<String, dynamic>?) ??
        (top['report_data'] as Map<String, dynamic>?) ??
        (top['inspection_report'] as Map<String, dynamic>?) ??
        top;
    final inspectionDataRaw = report['inspection_data'] ?? top['inspection_data'];
    final inspectionData = _normalizeInspectionData(inspectionDataRaw);
    final photos = (top['photos'] as List<dynamic>?) ??
        (report['photos'] as List<dynamic>?) ??
        (report['inspection_photos'] as List<dynamic>?) ??
        <dynamic>[];
    final overallGrade = (report['overall_grade'] ?? report['grade'] ?? report['vehicle_grade'] ?? '').toString().isEmpty
        ? 'N/A'
        : (report['overall_grade'] ?? report['grade'] ?? report['vehicle_grade']).toString();
    final summary = (report['summary'] ?? report['notes'] ?? report['overall_summary'] ?? '').toString().isEmpty
        ? 'No summary available'
        : (report['summary'] ?? report['notes'] ?? report['overall_summary']).toString();
    final recommendations = (report['recommendations'] ?? report['recs'])?.toString();

    return SingleChildScrollView(
      child: Padding(
        padding: ResponsiveHelper.padding(context, all: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Info Card
            _buildVehicleInfoCard(),
            const SizedBox(height: 24),
            
            // Inspection Summary
            _buildSectionTitle('Inspection Summary'),
            const SizedBox(height: 12),
            _buildInspectionSummaryCard(overallGrade, summary),
            
            if (recommendations != null && recommendations.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionTitle('Recommendations'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Text(
                  recommendations,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Inspection Categories
            if (inspectionData != null && inspectionData.isNotEmpty) ...[
              _buildSectionTitle('Detailed Inspection Results'),
              const SizedBox(height: 12),
              ..._buildInspectionCategories(inspectionData),
            ],
            
            const SizedBox(height: 24),
            
            // Inspection Photos
            if (photos.isNotEmpty) ...[
              _buildSectionTitle('Inspection Photos'),
              const SizedBox(height: 12),
              _buildPhotosGrid(photos),
              const SizedBox(height: 24),
            ],
            
            // Inspector Details
            _buildInspectorDetails(),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _normalizeInspectionData(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List) {
      final Map<String, dynamic> out = {};
      int i = 1;
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final key = (e['category'] ?? e['name'] ?? 'Section $i').toString();
          if (e['items'] is List) {
            out[key] = {'items': e['items']};
          } else {
            out[key] = e;
          }
        } else {
          out['Section $i'] = {'items': [e]};
        }
        i++;
      }
      return out;
    }
    return null;
  }

  Widget _buildVehicleInfoCard() {
    final vehicleData = _inspectionDetails?['vehicle'] as Map<String, dynamic>?;
    final vehicleImageUrl = vehicleData?['image_url']?.toString() ?? widget.car.imageUrl;
    final year = vehicleData?['year']?.toString() ?? widget.car.year.toString();
    final make = vehicleData?['make']?.toString() ?? widget.car.make;
    final model = vehicleData?['model']?.toString() ?? widget.car.model;
    final vin = vehicleData?['vin']?.toString() ?? widget.car.vin;
    final mileage = vehicleData?['mileage']?.toString() ?? widget.car.mileage.toString();
    final completedAt = _inspectionDetails?['completed_at']?.toString();

    String inspectionDate = 'N/A';
    if (completedAt != null && completedAt.isNotEmpty) {
      try {
        final date = DateTime.parse(completedAt).toUtc().subtract(const Duration(hours: 5));
        inspectionDate = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey[100],
                child: vehicleImageUrl != null && vehicleImageUrl.startsWith('http')
                    ? Image.network(
                        ImageHelper.normalizeImageUrl(vehicleImageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_car, color: Colors.grey),
                      )
                    : const Icon(Icons.directions_car, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    '$year $make $model'.toUpperCase(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kBlackColor),
                  ),
                  const SizedBox(height: 8),
                  _buildCompactInfoRow('VIN', vin ?? 'N/A'),
                  _buildCompactInfoRow('Mileage', '$mileage miles'),
                  _buildCompactInfoRow('Report Date', inspectionDate),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlackColor))),
        ],
      ),
    );
  }

  Widget _buildInspectionSummaryCard(String overallGrade, String summary) {
    Color gradeColor;
    switch (overallGrade.toLowerCase()) {
      case 'excellent': gradeColor = kThemeColorBlue; break;
      case 'good': gradeColor = kThemeColor2; break;
      case 'fair': gradeColor = kThemeColor3; break;
      case 'poor':
      case 'unsatisfactory': gradeColor = kThemeColor; break;
      default: gradeColor = Colors.grey;
    }

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('VEHICLE GRADE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gradeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    overallGrade.toUpperCase(),
                    style: TextStyle(color: gradeColor, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              summary,
              style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey[800]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.grey[600],
          letterSpacing: 1.1,
        ),
      ),
    );
  }


  Widget _buildConditionSection(String condition, List<String> points) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Condition Rating',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  condition,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map((point) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInspectorDetails() {
    Map<String, dynamic>? inspector = _inspectionDetails?['inspector'] as Map<String, dynamic>?;
    inspector ??= {
      'name': _inspectionDetails?['inspector_name'],
      'email': _inspectionDetails?['inspector_email'],
      'phone': _inspectionDetails?['inspector_phone'],
    };
    final completedAt = _inspectionDetails?['completed_at']?.toString();

    String inspectionDate = 'N/A';
    if (completedAt != null && completedAt.isNotEmpty) {
      try {
        final date = DateTime.parse(completedAt).toUtc().subtract(const Duration(hours: 5));
        inspectionDate = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {}
    }

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
            const Text('INSPECTOR INFORMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _buildCompactInfoRow('Name', inspector['name']?.toString() ?? 'N/A'),
            _buildCompactInfoRow('Email', inspector['email']?.toString() ?? 'N/A'),
            _buildCompactInfoRow('Phone', inspector['phone']?.toString() ?? 'N/A'),
            _buildCompactInfoRow('Inspection Date', inspectionDate),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInspectionCategories(Map<String, dynamic> inspectionData) {
    List<Widget> sections = [];
    List<String> keys = inspectionData.keys.map((k) => k.toString()).toList();
    if (keys.isEmpty) return sections;

    String prettify(String k) {
      final s = k.replaceAll('_', ' ').trim();
      return s.isEmpty ? 'Section' : s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
    }

    for (final key in keys) {
      final raw = inspectionData[key];
      List<dynamic> items = [];
      String? notes;

      if (raw is List) {
        items = raw;
      } else if (raw is Map<String, dynamic>) {
        if (raw['items'] is List) { items = raw['items'] as List; }
        else if (raw['list'] is List) { items = raw['list'] as List; }
        else if (raw['data'] is List) { items = raw['data'] as List; }
        else { items = raw.values.whereType<Map<String, dynamic>>().toList(); }
        if (raw['notes'] != null) notes = raw['notes']?.toString();
      }

      if (items.isEmpty) continue;

      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: ExpansionTile(
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              title: Text(prettify(key), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kBlackColor)),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                ...items.map((item) {
                  final map = item as Map<String, dynamic>;
                  final itemName = map['name']?.toString() ?? '';
                  final itemCondition = map['grade']?.toString() ?? map['condition']?.toString() ?? 'N/A';
                  final itemNotes = map['notes']?.toString();
                  final conditionColor = _getConditionColor(itemCondition);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(itemName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[800]))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: conditionColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(itemCondition, style: TextStyle(fontSize: 10, color: conditionColor, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        if (itemNotes != null && itemNotes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Text(itemNotes, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  );
                }),
                if (notes != null && notes.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Notes: $notes', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return sections;
  }

  Widget _buildHistoryItem(String date, String event, String description) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
       color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(date.split('-')[2], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kThemeColorBlue)),
                  Text('${date.split('-')[1]}/${date.split('-')[0].substring(2)}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue[300])),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kBlackColor)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(String title, String type, String size, IconData icon) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
       color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: kThemeColorBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kBlackColor)),
                  const SizedBox(height: 2),
                  Text('$type • $size', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded, color: kAccentColor, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloading $title...'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'excellent':
      case 'good':
        return Colors.green;
      case 'fair':
        return Colors.orange;
      case 'poor':
      case 'unsatisfactory':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPhotosGrid(List<dynamic> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index] as Map<String, dynamic>;
        final photoUrl = (photo['photo_url'] ?? photo['url'] ?? photo['image_url'] ?? photo['path'] ?? '').toString();
        final caption = photo['caption']?.toString() ?? '';

        return GestureDetector(
          onTap: () {
            // Show full screen image viewer
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                child: Stack(
                  children: [
                    Center(
                      child: Image.network(
                        ImageHelper.normalizeImageUrl(photoUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.error, size: 64, color: Colors.red);
                        },
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 20,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    ImageHelper.normalizeImageUrl(photoUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, size: 40),
                      );
                    },
                  ),
                  if (caption.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Text(
                          caption,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleHistory() {
    final history = (_inspectionDetails?['vehicle_history'] as List<dynamic>?) ??
        ((_inspectionDetails?['report'] as Map<String, dynamic>?)?['vehicle_history'] as List<dynamic>?) ??
        (_inspectionDetails?['history'] as List<dynamic>?) ??
        ((_inspectionDetails?['report'] as Map<String, dynamic>?)?['history'] as List<dynamic>?) ??
        const [];
    
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'No vehicle history available',
                style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Vehicle History Report'),
            const SizedBox(height: 12),
            ...history.map((h) {
              final m = h as Map<String, dynamic>;
              final date = m['date']?.toString() ?? '';
              final event = m['event']?.toString() ?? m['title']?.toString() ?? 'Event';
              final desc = m['description']?.toString() ?? m['details']?.toString() ?? '';
              return _buildHistoryItem(date.isEmpty ? 'N/A' : date, event, desc);
            })
          ],
        ),
      ),
    );
  }

  Widget _buildDocuments() {
    final docs = (_inspectionDetails?['documents'] as List<dynamic>?) ??
        ((_inspectionDetails?['report'] as Map<String, dynamic>?)?['documents'] as List<dynamic>?) ??
        (_inspectionDetails?['files'] as List<dynamic>?) ??
        const [];
    
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'No documents available',
                style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Available Documents'),
            const SizedBox(height: 12),
            ...docs.map((d) {
              final m = d as Map<String, dynamic>;
              final title = m['title']?.toString() ?? m['name']?.toString() ?? 'Document';
              final type = m['type']?.toString() ?? 'File';
              final size = m['size']?.toString() ?? '';
              final icon = type.toLowerCase().contains('pdf') ? Icons.picture_as_pdf : Icons.description;
              return _buildDocumentCard(title, type.toUpperCase(), size, icon);
            }),
          ],
        ),
      ),
    );
  }
}

