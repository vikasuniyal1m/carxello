import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/car_service.dart';

class ValuationToolsScreen extends StatefulWidget {
  final Car car;

  const ValuationToolsScreen({super.key, required this.car});

  @override
  State<ValuationToolsScreen> createState() => _ValuationToolsScreenState();
}

class _ValuationToolsScreenState extends State<ValuationToolsScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: JD Power, 1: Value Calculator, 2: Market Trend, 3: Value Overview, 4: KBB Analysis
  int _valueOverviewTab = 0; // For Value Overview sub-tabs
  int _reportTab = 0; // For Report sub-tabs (Report, Photos, MMR)

  late TabController _tabController;

  // Value Calculator state
  String _selectedCondition = 'Excellent';
  final List<String> _conditions = ['Excellent', 'Good', 'Fair', 'Poor'];
  final Map<String, bool> _additionalFactors = {
    'Accident History': false,
    'Flood Damage': false,
    'Service Records': false,
    'Single Owner': false,
  };
  final Map<String, double> _factorDeductions = {
    'Accident History': -2000,
    'Flood Damage': -5000,
    'Service Records': -5000,
    'Single Owner': -400,
  };

  double _baseKBBValue = 26500.0;
  bool _isLoadingValuation = true;
  String? _valuationError;
  Map<String, dynamic>? _valuationData;
  
  // Store listener reference to properly remove it
  late VoidCallback _tabListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabListener = () {
      setState(() {
        _selectedTab = _tabController.index;
      });
    };
    _tabController.addListener(_tabListener);
    _fetchValuation();
  }

  @override
  void dispose() {
    _tabController.removeListener(_tabListener);
    _tabController.dispose();
    super.dispose();
  }

  double _calculateAdjustedValue() {
    double adjusted = _baseKBBValue;
    _additionalFactors.forEach((key, value) {
      if (value) {
        adjusted += _factorDeductions[key]!;
      }
    });
    return adjusted < 0 ? 0 : adjusted;
  }

  Future<void> _fetchValuation() async {
    final vin = (widget.car.vin ?? '').trim();
    final hasVin = vin.length == 17;
    // Same as website sell-a-car.php: Make, Model, Year, Mileage are enough; VIN optional.
    final hasMmy = widget.car.make.isNotEmpty &&
        widget.car.model.isNotEmpty &&
        widget.car.year > 0;
    if (!hasVin && !hasMmy) {
      setState(() {
        _isLoadingValuation = false;
        _valuationError =
            'Enter a valid 17-character VIN or complete Make, Model, and Year for valuation.';
      });
      return;
    }

    setState(() {
      _isLoadingValuation = true;
      _valuationError = null;
    });

    try {
      final condition = _selectedCondition.toLowerCase().replaceAll(' ', '_');
      final result = await CarService().getVehicleValueByVIN(
        hasVin ? vin : null,
        make: widget.car.make,
        model: widget.car.model,
        year: widget.car.year.toString(),
        mileage: widget.car.mileage.toString(),
        condition: condition,
        zipcode: widget.car.location,
      );

      final source = result['source']?.toString();
      final retail = (result['retail_value'] as num?)?.toDouble();
      final market = (result['market_average'] as num?)?.toDouble();
      final hasValue = (retail != null && retail > 0) || (market != null && market > 0);
      if (source == 'error' || !hasValue) {
        setState(() {
          _valuationData = result;
          _valuationError = result['message']?.toString() ??
              'Unable to fetch vehicle value. Please enter manually.';
        });
        return;
      }

      setState(() {
        _valuationData = result;
        _baseKBBValue = (retail != null && retail > 0)
            ? retail!
            : ((market != null && market > 0) ? market! : _baseKBBValue);
      });
    } catch (e) {
      setState(() {
        _valuationError = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingValuation = false;
      });
    }
  }

  double _val(String key, {double fallback = 0}) {
    final raw = _valuationData?[key];
    if (raw is num) return raw.toDouble();
    return fallback;
  }

  String _money(double value) => '\$${value.toStringAsFixed(0)}';

  double _sourceVal(String source, String key, {double fallback = 0}) {
    final sourceMap = _valuationData?['sources'];
    if (sourceMap is Map<String, dynamic>) {
      final src = sourceMap[source];
      if (src is Map<String, dynamic>) {
        final val = src[key];
        if (val is num) return val.toDouble();
      }
    }
    return fallback;
  }

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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'JD Power'),
            Tab(text: 'Value Calculator'),
            Tab(text: 'Market Trend'),
            Tab(text: 'Value Overview'),
            Tab(text: 'KBB Analysis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJDPowerTab(),
          _buildValueCalculatorTab(),
          _buildMarketTrendTab(),
          _buildValueOverviewTab(),
          _buildKBBAnalysisTab(),
        ],
      ),
    );
  }

  Widget _buildJDPowerTab() {
    final jdRetail = _sourceVal('jd_power', 'retail', fallback: _baseKBBValue);
    final jdTradeIn = _sourceVal('jd_power', 'trade_in', fallback: jdRetail * 0.75);
    final jdPrivate = _sourceVal('jd_power', 'private_party', fallback: jdRetail * 0.90);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Schedule inspection text
          Text(
            'Schedule a professional vehicle inspection.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // JD Power estimated values
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JD Power Valuation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _money(jdRetail),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Trade-in ${_money(jdTradeIn)} • Private ${_money(jdPrivate)}',
                  style: TextStyle(color: Colors.blue[700], fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Source comparison
          const Text(
            'Source Comparison',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildRatingBar('JD Power', 4.3, Colors.green),
          const SizedBox(height: 12),
          _buildRatingBar('KBB', 4.1, Colors.blue),
          const SizedBox(height: 12),
          _buildRatingBar('MMR', 4.0, Colors.orange),
          const SizedBox(height: 24),
          
          // Recommended listing
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended Price',
                  style: TextStyle(color: Colors.green[800], fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _money(_val('recommended_price', fallback: jdRetail * 0.95)),
                  style: TextStyle(color: Colors.green[700], fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Insight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (_valuationData?['message'] ?? 'Valuation generated from available market comparables.').toString(),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, double rating, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Text(
              rating.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rating / 5,
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildAwardItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber, size: 24),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildValueCalculatorTab() {
    final adjustedValue = _calculateAdjustedValue();
    final marketAverage = _val('market_average', fallback: _baseKBBValue);
    final source = (_valuationData?['source'] ?? 'internal').toString();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule a professional vehicle inspection.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (_isLoadingValuation)
            const LinearProgressIndicator(),
          if (_valuationError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Valuation load failed: $_valuationError',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ],
          if (!_isLoadingValuation) ...[
            const SizedBox(height: 8),
            Text(
              'Source: $source • Similar vehicles: ${(_valuationData?['similar_vehicles_count'] ?? 0)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          
          // Adjust Parameters
          const Text(
            'Adjust Parameters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Condition Dropdown
          const Text(
            'Condition',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCondition,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: _conditions.map((String condition) {
              return DropdownMenuItem<String>(
                value: condition,
                child: Text(condition),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCondition = newValue!;
              });
              _fetchValuation();
            },
          ),
          const SizedBox(height: 24),
          
          // Additional Factors
          const Text(
            'Additional Factors',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._additionalFactors.entries.map((entry) {
            return CheckboxListTile(
              title: Text('${entry.key} (${_factorDeductions[entry.key]!.toStringAsFixed(0)})'),
              value: entry.value,
              onChanged: (bool? value) {
                setState(() {
                  _additionalFactors[entry.key] = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
            );
          }),
          const SizedBox(height: 24),
          
          // Calculated Value
          const Text(
            'Calculated Value',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adjusted Value',
                  style: TextStyle(color: Colors.blue[700], fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${adjustedValue.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.blue[900], fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Value Breakdown
          const Text(
            'Value BreakDown',
            style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow('Base KBB Value', '\$${_baseKBBValue.toStringAsFixed(0)}'),
          _buildBreakdownRow('Mileage Adjustment', '+\$0'),
          _buildBreakdownRow('Condition Factor', '100%'),
          _buildBreakdownRow('Total Adjusted Value', '\$${adjustedValue.toStringAsFixed(0)}'),
          _buildBreakdownRow('Market Average', _money(marketAverage)),
          const SizedBox(height: 24),
          
          // Recommendation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommendation',
                  style: TextStyle(color: Colors.green[800], fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Good Value opportunity - consider bidding',
                  style: TextStyle(color: Colors.green[700], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMarketTrendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Market Trends',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Price Trends (Last 6 Months)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Simple bar chart representation
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBarChartBar(0.6, '1M', '\$24K'),
                _buildBarChartBar(0.65, '2M', ''),
                _buildBarChartBar(0.7, '3M', ''),
                _buildBarChartBar(0.75, '4M', ''),
                _buildBarChartBar(0.8, '5M', ''),
                _buildBarChartBar(0.78, '6M', '\$26.5K'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green, size: 20),
              const SizedBox(width: 4),
              Text(
                '+8.2 increase over 6 months',
                style: TextStyle(color: Colors.green[700], fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Key Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Demand Level',
                  'High - 23% above average interest',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Inventory Level',
                  'Low - 15% below average supply',
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Days on Market',
                  'Average 18 days ( vs 25 days typical)',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Market Forecast',
                  'Values for this model are expected to remain stable over the next 3 months. High demand and low inventory suggest good resale potential.',
                  Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartBar(double height, String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (value.isNotEmpty)
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 200 * height,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String content, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(color: color.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildValueOverviewTab() {
    final tradeInValue = _val('trade_in_value', fallback: _baseKBBValue * 0.75);
    final privatePartyValue = _val('private_party_value', fallback: _baseKBBValue * 0.90);
    final retailValue = _val('retail_value', fallback: _baseKBBValue);
    final recommended = _val('recommended_price', fallback: retailValue * 0.95);
    final marketAverage = _val('market_average', fallback: _baseKBBValue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule a professional vehicle inspection.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Sub-tabs for Value Overview
          Row(
            children: [
              Expanded(
                child: _buildSubTabButton('Value Overview', 0, _valueOverviewTab == 0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSubTabButton('KBB Analysis', 1, _valueOverviewTab == 1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSubTabButton('JD', 2, _valueOverviewTab == 2),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_valueOverviewTab == 0) ...[
            // Value Cards
            Row(
              children: [
                Expanded(child: _buildValueCard('Trade-In Value', _money(tradeInValue), 'What dealers typically pay', Colors.grey)),
                const SizedBox(width: 8),
                Expanded(child: _buildValueCard('Private Party Value', _money(privatePartyValue), 'Typical private sale price', Colors.blue)),
              ],
            ),
            const SizedBox(height: 12),
            _buildValueCard('Retail Value', _money(retailValue), 'Dealer retail price', Colors.green),
            const SizedBox(height: 12),
            _buildValueCard('Recommended Price', _money(recommended), 'Competitive listing price', Colors.orange),
            const SizedBox(height: 24),
            
            // Value Factors
            const Text(
              'Value Factors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFactorRow('Mileage (${widget.car.mileage} mi)', '--'),
            _buildFactorRow('Condition (${_selectedCondition})', '--'),
            _buildFactorRow('Market Average', _money(marketAverage)),
            _buildFactorRow('Data Source', (_valuationData?['source'] ?? 'internal').toString()),
            _buildFactorRow('Vehicle Found', (_valuationData?['vehicle_found'] == true) ? 'Yes' : 'No'),
            _buildFactorRow('Comparable Vehicles', '${_valuationData?['similar_vehicles_count'] ?? 0}'),
          ] else if (_valueOverviewTab == 1) ...[
            // KBB Analysis content
            Row(
              children: [
                Expanded(child: _buildValueCard('KBB Value', _money(retailValue), 'Kelly Blue Book', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildValueCard('MMR Value', _money(marketAverage), 'Manheim Market Report', Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildValueCard('Current Bid', '\$23,500', 'Auction Price', Colors.purple)),
                const SizedBox(width: 8),
                Expanded(child: _buildValueCard('Buy Now', '\$25,000', 'Instant Purchase', Colors.orange)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Value Analysis
            const Text(
              'Value Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildAnalysisRow('Current Bid vs KBB Value:', _money(retailValue - widget.car.startingBid)),
            _buildAnalysisRow('Buy Now vs KBB Value:', _money(retailValue - widget.car.buyNowPrice)),
            _buildAnalysisRow('Potential Savings (vs KBB):', _money((retailValue - widget.car.startingBid).abs())),
            const SizedBox(height: 24),
            
            // Valuation Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valuation Summary',
                          style: TextStyle(color: Colors.blue[800], fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This vehicle is currently priced competitively in the market. The KBB value suggests good value potential, while the MMR indicates strong wholesale market positioning.',
                          style: TextStyle(color: Colors.blue[700], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubTabButton(String text, int index, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _valueOverviewTab = index;
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

  Widget _buildValueCard(String title, String value, String subtitle, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color.shade700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color.shade900, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: color.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildKBBAnalysisTab() {
    final kbbRetail = _sourceVal('kbb', 'retail', fallback: _val('retail_value', fallback: _baseKBBValue));
    final mmrRetail = _sourceVal('mmr', 'retail', fallback: _val('market_average', fallback: _baseKBBValue));
    final currentBid = widget.car.startingBid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tabs for Report
          Row(
            children: [
              Expanded(
                child: _buildReportSubTabButton('Condition Report', 0, _reportTab == 0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildReportSubTabButton('Photos', 1, _reportTab == 1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildReportSubTabButton('MMR Values', 2, _reportTab == 2),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_reportTab == 0) ...[
            // Condition Report
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Condition Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Last Updated: 2024-01-15',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildConditionItem('Exterior', 'Paint, body panels, lights', 'Excellent', Colors.green),
            const SizedBox(height: 12),
            _buildConditionItem('Interior', 'Seats, dashboard, electronics', 'Good', Colors.blue),
            const SizedBox(height: 12),
            _buildConditionItem('Mechanical', 'Engine, transmission, brakes', 'Excellent', Colors.green),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valuation Summary',
                          style: TextStyle(color: Colors.blue[800], fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This vehicle is currently priced competitively in the market. The KBB value suggests good value potential, while the MMR indicates strong wholesale market positioning.',
                          style: TextStyle(color: Colors.blue[700], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_reportTab == 1) ...[
            // Photos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Condition Photos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '12 Photos Available',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPhotoCard('Exterior Front', 'assets/images/car1.png'),
            const SizedBox(height: 12),
            _buildPhotoCard('Interior Dashboard', 'assets/images/car2.png'),
            const SizedBox(height: 12),
            _buildPhotoCard('Engine Bay', 'assets/images/car3.png'),
            const SizedBox(height: 12),
            _buildPhotoCard('Rear View', 'assets/images/car1.png'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[100],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('View All Photos (12)'),
              ),
            ),
          ] else if (_reportTab == 2) ...[
            // MMR Values
            const Text(
              'Market Value Analysis (MMR)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildValueCard('KBB Value', _money(kbbRetail), 'Kelly Blue Book', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildValueCard('MMR Value', _money(mmrRetail), 'Manheim Market Report', Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            _buildValueCard('Current Bid', _money(currentBid), 'Auction Price', Colors.purple),
            const SizedBox(height: 24),
            
            const Text(
              'Value Comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildComparisonRow('Current Bid vs MMR :', _money(currentBid - mmrRetail), Colors.green),
            _buildComparisonRow('Current Bid vs KBB:', _money(currentBid - kbbRetail), Colors.green),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Value Insight',
                    style: TextStyle(color: Colors.brown[800], fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This vehicle is currently bidding below market value. Consider the condition report and your maximum budget when bidding.',
                    style: TextStyle(color: Colors.brown[700], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportSubTabButton(String text, int index, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _reportTab = index;
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

  Widget _buildConditionItem(String title, String details, String status, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(color: color.shade800, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String title, String imagePath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            imagePath,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

