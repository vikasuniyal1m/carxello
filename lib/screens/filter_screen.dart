import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/screen_size.dart';

// ════════════════════════════════════════════════════════════════════
// Cars24-style Filter Screen — ALL checkbox-based, multi-select
// ════════════════════════════════════════════════════════════════════

class FilterScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onApplyFilters;
  final VoidCallback? onClearFilters;
  final Map<String, dynamic>? initialFilters;
  final Map<String, dynamic>? dynamicOptions;

  const FilterScreen({
    super.key,
    this.onApplyFilters,
    this.onClearFilters,
    this.initialFilters,
    this.dynamicOptions,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // ── Controllers ──
  final TextEditingController _minYearCtrl = TextEditingController();
  final TextEditingController _maxYearCtrl = TextEditingController();
  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();
  final TextEditingController _minMileageCtrl = TextEditingController();
  final TextEditingController _maxMileageCtrl = TextEditingController();
  final TextEditingController _zipCodeCtrl = TextEditingController();
  final TextEditingController _openingPriceCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // ── All multi-select sets ──
  final Set<String> _selMakes = {};
  final Set<String> _selModels = {};
  final Set<String> _selBodyStyles = {};
  final Set<String> _selSellerTypes = {};
  final Set<String> _selConditions = {};
  final Set<String> _selDoors = {};
  final Set<String> _selTransmissions = {};
  final Set<String> _selFuels = {};
  final Set<String> _selExtColors = {};
  final Set<String> _selIntColors = {};
  final Set<String> _selDistances = {};
  final Set<String> _selSortBy = {};

  // ── Highlight toggles ──
  bool _thirdPartyInspected = false;
  bool _excludeRedLight = false;
  bool _excludeSmoker = false;
  bool _excludeReviewed = false;
  bool _canadianOnly = false;

  // ── Dynamic data ──
  List<String> _makeOptions = [];
  List<String> _modelOptions = [];
  Map<String, List<String>> _makeToModels = {};
  Map<String, int> _makeCounts = {};
  Map<String, int> _modelCounts = {};

  // ── Static lists (matching Auctions-list.php) ──
  static const _kBodyStyles = ['Sedan', 'Coupe', 'Hatchback', 'SUV', 'Pickup', 'Convertible', 'Wagon', 'Van'];
  static const _kSellerTypes = ['Dealer', 'Private Seller'];
  static const _kDoors = ['2', '3', '4', '5'];
  static const _kConditions = ['Excellent', 'Very Good', 'Good', 'Fair', 'Poor'];
  static const _kTransmissions = ['Automatic', 'Manual', 'CVT', 'Dual-Clutch'];
  static const _kFuels = ['Gasoline', 'Diesel', 'Electric', 'Hybrid', 'Plug-in Hybrid', 'Flexible Fuel', 'Natural Gas'];
  static const _kExtColors = ['Black', 'White', 'Silver', 'Gray', 'Red', 'Blue', 'Brown', 'Green', 'Gold', 'Beige', 'Yellow', 'Orange', 'Purple', 'Other'];
  static const _kIntColors = ['Black', 'Beige', 'Gray', 'Tan', 'White', 'Brown', 'Red', 'Blue', 'Other'];
  static const _kDistances = ['50 miles', '100 miles', '200 miles', '500 miles'];
  static const _kSortOptions = ['Ending Soon', 'Newest', 'Most Bids', 'Price: Low to High', 'Price: High to Low'];

  // ── Section nav ──
  static const _kSections = [
    'Sort By',
    'Highlights',
    'Vehicle Type',
    'Inventory Type',
    'Year',
    'Make',
    'Model',
    'Condition',
    'Door Count',
    'Price & Mileage',
    'Transmission & Fuel',
    'Colors',
    'Location & Distance',
    'Canadian Vehicles',
  ];
  int _selSection = 0;

  // ══════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadDynamic();
    _restoreFilters();
  }

  @override
  void dispose() {
    _minYearCtrl.dispose();
    _maxYearCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _minMileageCtrl.dispose();
    _maxMileageCtrl.dispose();
    _zipCodeCtrl.dispose();
    _openingPriceCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _jumpTop() {
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // DYNAMIC OPTIONS
  // ══════════════════════════════════════════════════════════════════

  void _loadDynamic() {
    final o = widget.dynamicOptions;
    if (o == null) return;

    List<String> _u(List? src) {
      if (src == null) return [];
      final c = src.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet().toList();
      c.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return c;
    }

    _makeOptions = _u(o['makes'] as List?);
    _modelOptions = _u(o['models'] as List?);

    if (o['make_models'] is Map) {
      _makeToModels = (o['make_models'] as Map).map((k, v) {
        final l = (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        l.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return MapEntry(k.toString(), l);
      });
    }
    if (o['make_counts'] is Map) {
      _makeCounts = (o['make_counts'] as Map).map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0));
    }
    if (o['model_counts'] is Map) {
      _modelCounts = (o['model_counts'] as Map).map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0));
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // RESTORE SAVED FILTERS
  // ══════════════════════════════════════════════════════════════════

  void _restoreFilters() {
    final f = widget.initialFilters;
    if (f == null || f.isEmpty) return;

    _minYearCtrl.text = (f['minYear'] ?? f['year_min'] ?? '').toString();
    _maxYearCtrl.text = (f['maxYear'] ?? f['year_max'] ?? '').toString();
    _minPriceCtrl.text = (f['minPrice'] ?? f['price_min'] ?? '').toString();
    _maxPriceCtrl.text = (f['maxPrice'] ?? f['price_max'] ?? '').toString();
    _minMileageCtrl.text = (f['fromOdometer'] ?? f['mileage_min'] ?? '').toString();
    _maxMileageCtrl.text = (f['toOdometer'] ?? f['mileage_max'] ?? '').toString();
    _zipCodeCtrl.text = (f['zipCode'] ?? f['location'] ?? '').toString();
    _openingPriceCtrl.text = (f['openingPrice'] ?? f['opening_price'] ?? '').toString();

    void _addSplit(Set<String> set, dynamic val) {
      if (val == null) return;
      if (val is List) { set.addAll(val.map((e) => e.toString())); return; }
      set.addAll(val.toString().split(RegExp(r'[,;|]+')).map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    _addSplit(_selMakes, f['make'] ?? f['makes']);
    _addSplit(_selModels, f['model'] ?? f['models']);
    _addSplit(_selBodyStyles, f['body_style'] ?? f['bodyStyle']);
    _addSplit(_selSellerTypes, f['seller_type'] ?? f['sellerType']);
    _addSplit(_selConditions, f['condition']);
    _addSplit(_selDoors, f['doors']);
    _addSplit(_selFuels, f['fuel_type'] ?? f['engineFuelType']);
    _addSplit(_selTransmissions, f['transmission'] ?? f['driveTrain']);
    _addSplit(_selExtColors, f['exterior_color'] ?? f['exteriorInteriorColor']);
    _addSplit(_selIntColors, f['interior_color']);
    _addSplit(_selDistances, f['distance']);
    _addSplit(_selSortBy, f['sort'] ?? f['sortBy']);

    _thirdPartyInspected = f['third_party_inspected'] == true || f['thirdPartyInspection'] == true;
    _excludeRedLight = f['exclude_red_light'] == true || f['excludeRedLight'] == true;
    _excludeSmoker = f['exclude_smoker'] == true || f['excludeSmokers'] == true;
    _excludeReviewed = f['exclude_reviewed'] == true || f['excludeReviewedVehicles'] == true;
    _canadianOnly = f['plant_country'] == 'Canada' || f['canadianOnly'] == true;

    if (f['_initialSection'] is int) {
      final idx = f['_initialSection'] as int;
      if (idx >= 0 && idx < _kSections.length) _selSection = idx;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // APPLY / CLEAR
  // ══════════════════════════════════════════════════════════════════

  void _apply() {
    final d = <String, dynamic>{};

    if (_minYearCtrl.text.isNotEmpty) d['year_min'] = _minYearCtrl.text;
    if (_maxYearCtrl.text.isNotEmpty) d['year_max'] = _maxYearCtrl.text;
    if (_minPriceCtrl.text.isNotEmpty) d['price_min'] = _minPriceCtrl.text;
    if (_maxPriceCtrl.text.isNotEmpty) d['price_max'] = _maxPriceCtrl.text;
    if (_minMileageCtrl.text.isNotEmpty) d['mileage_min'] = _minMileageCtrl.text;
    if (_maxMileageCtrl.text.isNotEmpty) d['mileage_max'] = _maxMileageCtrl.text;
    if (_zipCodeCtrl.text.isNotEmpty) d['location'] = _zipCodeCtrl.text;
    if (_openingPriceCtrl.text.isNotEmpty) d['opening_price'] = _openingPriceCtrl.text;

    if (_selMakes.isNotEmpty) d['makes'] = _selMakes.toList();
    if (_selModels.isNotEmpty) d['models'] = _selModels.toList();
    if (_selBodyStyles.isNotEmpty) d['body_style'] = _selBodyStyles.join(',');
    if (_selSellerTypes.isNotEmpty) {
      d['seller_type'] = _selSellerTypes.map((s) => s == 'Dealer' ? 'dealer' : 'private').join(',');
    }
    if (_selConditions.isNotEmpty) d['condition'] = _selConditions.join(',');
    if (_selDoors.isNotEmpty) d['doors'] = _selDoors.join(',');
    if (_selFuels.isNotEmpty) d['fuel_type'] = _selFuels.join(',');
    if (_selTransmissions.isNotEmpty) d['transmission'] = _selTransmissions.join(',');
    if (_selExtColors.isNotEmpty) d['exterior_color'] = _selExtColors.join(',');
    if (_selIntColors.isNotEmpty) d['interior_color'] = _selIntColors.join(',');
    if (_selDistances.isNotEmpty) d['distance'] = _selDistances.first.replaceAll(RegExp(r'[^0-9]'), '');
    if (_selSortBy.isNotEmpty) {
      const map = {
        'Ending Soon': 'ending_soon',
        'Newest': 'newest',
        'Most Bids': 'bid_count',
        'Price: Low to High': 'price_low',
        'Price: High to Low': 'price_high',
      };
      d['sort'] = map[_selSortBy.first] ?? 'ending_soon';
    }

    if (_thirdPartyInspected) d['third_party_inspected'] = true;
    if (_excludeRedLight) d['exclude_red_light'] = true;
    if (_excludeSmoker) d['exclude_smoker'] = true;
    if (_excludeReviewed) d['exclude_reviewed'] = true;
    if (_canadianOnly) d['plant_country'] = 'Canada';

    Navigator.pop(context, d);
  }

  void _clear() {
    setState(() {
      for (final c in [_minYearCtrl, _maxYearCtrl, _minPriceCtrl, _maxPriceCtrl, _minMileageCtrl, _maxMileageCtrl, _zipCodeCtrl, _openingPriceCtrl, _searchCtrl]) {
        c.clear();
      }
      for (final s in [_selMakes, _selModels, _selBodyStyles, _selSellerTypes, _selConditions, _selDoors, _selTransmissions, _selFuels, _selExtColors, _selIntColors, _selDistances, _selSortBy]) {
        s.clear();
      }
      _thirdPartyInspected = false;
      _excludeRedLight = false;
      _excludeSmoker = false;
      _excludeReviewed = false;
      _canadianOnly = false;
    });
    Navigator.pop(context, <String, dynamic>{});
  }

  int get _activeCount {
    int c = 0;
    for (final s in [_selMakes, _selModels, _selBodyStyles, _selSellerTypes, _selConditions, _selDoors, _selTransmissions, _selFuels, _selExtColors, _selIntColors, _selDistances, _selSortBy]) {
      c += s.length;
    }
    for (final ctrl in [_minYearCtrl, _maxYearCtrl, _minPriceCtrl, _maxPriceCtrl, _minMileageCtrl, _maxMileageCtrl, _zipCodeCtrl, _openingPriceCtrl]) {
      if (ctrl.text.isNotEmpty) c++;
    }
    if (_thirdPartyInspected) c++;
    if (_excludeRedLight) c++;
    if (_excludeSmoker) c++;
    if (_excludeReviewed) c++;
    if (_canadianOnly) c++;
    return c;
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    final isTab = ScreenSize.isTablet;
    final leftW = isTab ? 150.0 : 110.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      // ── APP BAR — Cars24 style ──
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87)),
            if (_activeCount > 0)
              Text('$_activeCount selected', style: TextStyle(fontSize: 11.sp, color: kAccentColor, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Search saved!'), backgroundColor: kAccentColor, duration: const Duration(seconds: 1)),
              );
            },
            child: Text('Save', style: TextStyle(fontSize: 12.sp, color: kAccentColor, fontWeight: FontWeight.w600)),
          ),
          Container(width: 1, height: 20, color: Colors.grey[300], margin: EdgeInsets.symmetric(vertical: 16.h)),
          TextButton(
            onPressed: () {
              setState(() {
                for (final c in [_minYearCtrl, _maxYearCtrl, _minPriceCtrl, _maxPriceCtrl, _minMileageCtrl, _maxMileageCtrl, _zipCodeCtrl, _openingPriceCtrl, _searchCtrl]) c.clear();
                for (final s in [_selMakes, _selModels, _selBodyStyles, _selSellerTypes, _selConditions, _selDoors, _selTransmissions, _selFuels, _selExtColors, _selIntColors, _selDistances, _selSortBy]) s.clear();
                _thirdPartyInspected = false;
                _excludeRedLight = false;
                _excludeSmoker = false;
                _excludeReviewed = false;
                _canadianOnly = false;
              });
            },
            child: Text('Clear All', style: TextStyle(fontSize: 12.sp, color: Colors.red[400], fontWeight: FontWeight.w600)),
          ),
          SizedBox(width: 4.w),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),

      body: Row(
        children: [
          // ═══════════ LEFT NAV (Cars24 style grey sidebar) ═══════════
          Container(
            width: leftW,
            color: const Color(0xFFF0F1F6),
            child: ListView.builder(
              itemCount: _kSections.length,
              padding: EdgeInsets.zero,
              itemBuilder: (_, i) {
                final sel = i == _selSection;
                final secSet = _setForSection(i);
                final count = secSet?.length ?? 0;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selSection = i);
                    _searchCtrl.clear();
                    _jumpTop();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: sel ? Colors.white : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: sel ? kAccentColor : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _kSections[i],
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel ? kAccentColor : Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (count > 0)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: kAccentColor,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text('$count', style: TextStyle(fontSize: 9.sp, color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ═══════════ RIGHT PANEL ═══════════
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // ── Section header ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _kSections[_selSection],
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)),
                          ),
                        ),
                        if ((_setForSection(_selSection)?.isNotEmpty ?? false))
                          GestureDetector(
                            onTap: () => setState(() => _setForSection(_selSection)?.clear()),
                            child: Text('Clear', style: TextStyle(fontSize: 11.sp, color: Colors.red[400], fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                  // ── Content ──
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 20.h),
                      child: _buildContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ═══════════ BOTTOM BAR ═══════════
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, MediaQuery.of(context).padding.bottom + 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: Row(
          children: [
            // Active filter count
            if (_activeCount > 0)
              Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Text(
                  '$_activeCount filters',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ),
            Expanded(
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                child: Text('Apply Filters', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Get the corresponding Set for a given section index (for badge count)
  Set<String>? _setForSection(int i) {
    switch (i) {
      case 0: return _selSortBy;
      case 2: return _selBodyStyles;
      case 3: return _selSellerTypes;
      case 5: return _selMakes;
      case 6: return _selModels;
      case 7: return _selConditions;
      case 8: return _selDoors;
      case 10: return _selTransmissions; // combine fuel+trans display
      case 11: return _selExtColors; // combine ext+int display
      case 12: return _selDistances;
      default: return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // CONTENT ROUTER
  // ══════════════════════════════════════════════════════════════════

  Widget _buildContent() {
    switch (_selSection) {
      case 0: return _secSortBy();
      case 1: return _secHighlights();
      case 2: return _secCheckboxList('Select vehicle type', _kBodyStyles, _selBodyStyles);
      case 3: return _secCheckboxList('Select inventory type', _kSellerTypes, _selSellerTypes);
      case 4: return _secYear();
      case 5: return _secMake();
      case 6: return _secModel();
      case 7: return _secCheckboxList('Select condition', _kConditions, _selConditions);
      case 8: return _secCheckboxList('Select door count', _kDoors, _selDoors);
      case 9: return _secPriceMileage();
      case 10: return _secTransFuel();
      case 11: return _secColors();
      case 12: return _secLocation();
      case 13: return _secCanadian();
      default: return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // SECTIONS — All checkbox-based
  // ══════════════════════════════════════════════════════════════════

  // ── 0 · SORT BY (single-select checkboxes) ──
  Widget _secSortBy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _kSortOptions.map((opt) {
        final checked = _selSortBy.contains(opt);
        return _cars24Checkbox(
          label: opt,
          checked: checked,
          onTap: () => setState(() {
            _selSortBy.clear();
            _selSortBy.add(opt);
          }),
        );
      }).toList(),
    );
  }

  // ── 1 · HIGHLIGHTS ──
  Widget _secHighlights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cars24Toggle('3rd Party Inspected', _thirdPartyInspected, (v) => setState(() => _thirdPartyInspected = v)),
        _cars24Toggle('Exclude Red Light', _excludeRedLight, (v) => setState(() => _excludeRedLight = v)),
        _cars24Toggle('Exclude Smoker', _excludeSmoker, (v) => setState(() => _excludeSmoker = v)),
        _cars24Toggle('Exclude Reviewed', _excludeReviewed, (v) => setState(() => _excludeReviewed = v)),
      ],
    );
  }

  // ── 4 · YEAR ──
  Widget _secYear() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rangeRow(_minYearCtrl, _maxYearCtrl, 'Min Year', 'Max Year'),
      ],
    );
  }

  // ── 5 · MAKE (searchable checkbox list) ──
  Widget _secMake() {
    final q = _searchCtrl.text.toLowerCase().trim();
    final items = _makeOptions.where((m) => q.isEmpty || m.toLowerCase().contains(q)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchBox('Search make...'),
        SizedBox(height: 8.h),
        if (items.isEmpty)
          _emptyHint('No makes found')
        else
          ...items.map((m) {
            final cnt = _makeCounts[m];
            return _cars24Checkbox(
              label: cnt != null && cnt > 0 ? '$m ($cnt)' : m,
              checked: _selMakes.contains(m),
              onTap: () => setState(() => _selMakes.contains(m) ? _selMakes.remove(m) : _selMakes.add(m)),
            );
          }),
      ],
    );
  }

  // ── 6 · MODEL (filtered by selected makes) ──
  Widget _secModel() {
    List<String> models = [];
    if (_selMakes.isNotEmpty) {
      for (final mk in _selMakes) {
        models.addAll(_makeToModels[mk] ?? []);
      }
      models = models.toSet().toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      models = _modelOptions;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (models.isEmpty)
          _emptyHint('Select a make first to see models')
        else
          ...models.map((m) {
            final cnt = _modelCounts[m];
            return _cars24Checkbox(
              label: cnt != null && cnt > 0 ? '$m ($cnt)' : m,
              checked: _selModels.contains(m),
              onTap: () => setState(() => _selModels.contains(m) ? _selModels.remove(m) : _selModels.add(m)),
            );
          }),
      ],
    );
  }

  // ── 9 · PRICE & MILEAGE ──
  Widget _secPriceMileage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Price Range'),
        _rangeRow(_minPriceCtrl, _maxPriceCtrl, 'Min \$', 'Max \$'),
        SizedBox(height: 16.h),
        _label('Mileage Range'),
        _rangeRow(_minMileageCtrl, _maxMileageCtrl, 'Min miles', 'Max miles'),
        SizedBox(height: 16.h),
        _label('Max Opening Price'),
        _inputField(_openingPriceCtrl, 'Max \$'),
      ],
    );
  }

  // ── 10 · TRANSMISSION & FUEL ──
  Widget _secTransFuel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Transmission'),
        ..._kTransmissions.map((t) => _cars24Checkbox(
          label: t,
          checked: _selTransmissions.contains(t),
          onTap: () => setState(() => _selTransmissions.contains(t) ? _selTransmissions.remove(t) : _selTransmissions.add(t)),
        )),
        SizedBox(height: 16.h),
        Divider(color: Colors.grey[200], height: 1),
        SizedBox(height: 16.h),
        _label('Fuel Type'),
        ..._kFuels.map((f) => _cars24Checkbox(
          label: f,
          checked: _selFuels.contains(f),
          onTap: () => setState(() => _selFuels.contains(f) ? _selFuels.remove(f) : _selFuels.add(f)),
        )),
      ],
    );
  }

  // ── 11 · COLORS ──
  Widget _secColors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Exterior Color'),
        ..._kExtColors.map((c) => _cars24Checkbox(
          label: c,
          checked: _selExtColors.contains(c),
          onTap: () => setState(() => _selExtColors.contains(c) ? _selExtColors.remove(c) : _selExtColors.add(c)),
        )),
        SizedBox(height: 16.h),
        Divider(color: Colors.grey[200], height: 1),
        SizedBox(height: 16.h),
        _label('Interior Color'),
        ..._kIntColors.map((c) => _cars24Checkbox(
          label: c,
          checked: _selIntColors.contains(c),
          onTap: () => setState(() => _selIntColors.contains(c) ? _selIntColors.remove(c) : _selIntColors.add(c)),
        )),
      ],
    );
  }

  // ── 12 · LOCATION ──
  Widget _secLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('ZIP Code'),
        _inputField(_zipCodeCtrl, 'Enter ZIP code'),
        SizedBox(height: 16.h),
        _label('Distance'),
        ..._kDistances.map((d) => _cars24Checkbox(
          label: d,
          checked: _selDistances.contains(d),
          onTap: () => setState(() {
            _selDistances.clear();
            _selDistances.add(d);
          }),
        )),
      ],
    );
  }

  // ── 13 · CANADIAN ──
  Widget _secCanadian() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cars24Toggle('Canadian Vehicles Only', _canadianOnly, (v) => setState(() => _canadianOnly = v)),
      ],
    );
  }

  // ── Generic checkbox section (body style, seller type, condition, doors) ──
  Widget _secCheckboxList(String hint, List<String> items, Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => _cars24Checkbox(
        label: item,
        checked: selected.contains(item),
        onTap: () => setState(() => selected.contains(item) ? selected.remove(item) : selected.add(item)),
      )).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // REUSABLE WIDGETS — Cars24 aesthetic
  // ══════════════════════════════════════════════════════════════════

  /// Cars24-style checkbox row
  Widget _cars24Checkbox({required String label, required bool checked, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                color: checked ? kAccentColor : Colors.white,
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(color: checked ? kAccentColor : Colors.grey[400]!, width: 1.5),
              ),
              child: checked
                  ? Icon(Icons.check, size: 14.sp, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                  color: checked ? const Color(0xFF1A1A2E) : Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cars24-style toggle row (for highlights / booleans)
  Widget _cars24Toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                  color: value ? const Color(0xFF1A1A2E) : Colors.grey[700],
                ),
              ),
            ),
            SizedBox(
              height: 24.h,
              width: 42.w,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: kAccentColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sub label
  Widget _label(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(text, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.grey[600])),
    );
  }

  /// Search input for make
  Widget _searchBox(String hint) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
          prefixIcon: Icon(Icons.search, size: 18.sp, color: Colors.grey),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  /// Range row
  Widget _rangeRow(TextEditingController c1, TextEditingController c2, String h1, String h2) {
    return Row(
      children: [
        Expanded(child: _inputField(c1, h1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Text('to', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
        ),
        Expanded(child: _inputField(c2, h2)),
      ],
    );
  }

  /// Input field
  Widget _inputField(TextEditingController ctrl, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => setState(() {}),
        keyboardType: TextInputType.number,
        style: TextStyle(fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  /// Empty hint text
  Widget _emptyHint(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Center(
        child: Text(text, style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontStyle: FontStyle.italic)),
      ),
    );
  }
}