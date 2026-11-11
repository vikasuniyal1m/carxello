import 'package:carauction/utils/api_config.dart';
import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/models/saved_search.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/screens/product_details_screen.dart';

class ViewMatchesScreen extends StatefulWidget {
  final SavedSearch savedSearch;

  const ViewMatchesScreen({
    super.key,
    required this.savedSearch,
  });

  @override
  State<ViewMatchesScreen> createState() => _ViewMatchesScreenState();
}

class _ViewMatchesScreenState extends State<ViewMatchesScreen> {
  final CarService _carService = CarService();
  List<Car> _matchedVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> filters = {};

      if (widget.savedSearch.make != null &&
          widget.savedSearch.make!.isNotEmpty &&
          widget.savedSearch.make != 'Any Make') {
        filters['make'] = widget.savedSearch.make;
      }
      if (widget.savedSearch.model != null &&
          widget.savedSearch.model!.isNotEmpty &&
          widget.savedSearch.model != 'Any Model') {
        filters['model'] = widget.savedSearch.model;
      }
      if (widget.savedSearch.yearFrom != null) {
        filters['year_min'] = widget.savedSearch.yearFrom;
      }
      if (widget.savedSearch.yearTo != null) {
        filters['year_max'] = widget.savedSearch.yearTo;
      }
      if (widget.savedSearch.priceMin != null) {
        filters['price_min'] = widget.savedSearch.priceMin;
      }
      if (widget.savedSearch.priceMax != null) {
        filters['price_max'] = widget.savedSearch.priceMax;
      }
      if (widget.savedSearch.maxMileage != null) {
        filters['odometer_max'] = widget.savedSearch.maxMileage;
      }
      if (widget.savedSearch.condition != null &&
          widget.savedSearch.condition!.isNotEmpty) {
        filters['condition'] = widget.savedSearch.condition;
      }

      final vehicles = await _carService.fetchCars(filters: filters);

      if (mounted) {
        setState(() {
          _matchedVehicles = vehicles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load matches'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Matches: ${widget.savedSearch.searchName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: _loadMatches,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _matchedVehicles.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          _buildSearchSummary(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _matchedVehicles.length,
              itemBuilder: (context, index) {
                final car = _matchedVehicles[index];
                return _buildCompactVehicleCard(car);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Criteria',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.savedSearch.getDescription(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_matchedVehicles.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactVehicleCard(Car car) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(car: car),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Vehicle Image - FIXED VERSION
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey[200],
                  child: _buildCarImage(car.imageUrl),
                ),
              ),
              const SizedBox(width: 10),

              // Vehicle Details (same as before)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${car.year} ${car.make} ${car.model}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${_formatNumber(car.startingBid)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed, size: 12, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text(
                              '${_formatNumber(car.mileage)} mi',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.grey),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  car.location.isNotEmpty ? car.location : 'N/A',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

// ADD THIS HELPER FUNCTION in the same class
  Widget _buildCarImage(String imageUrl) {
    // Check if it's a network image
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    // Check if it's an asset image
    else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
          );
        },
      );
    }

    // Try to construct full URL (if it's a relative path)
    else {
      try {

        final fullUrl = imageUrl.startsWith('/')
            ? '${ApiConfig.baseUrl}${imageUrl}'
            : '${ApiConfig.baseUrl}/$imageUrl';

        return Image.network(
          fullUrl,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
            );
          },
        );
      } catch (e) {
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No matches found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search criteria',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMatches,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(num number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }
}