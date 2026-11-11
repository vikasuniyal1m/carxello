import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:carauction/services/bid_service.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';

/// Full bid + auction context: your participation, compact stats, top bidders, bid history.
/// Uses public vehicle bids API; styling matches app theme (accent, black, white, greys).
class BidDetailsScreen extends StatefulWidget {
  const BidDetailsScreen({super.key, required this.bid});

  final Map<String, dynamic> bid;

  @override
  State<BidDetailsScreen> createState() => _BidDetailsScreenState();
}

class _BidDetailsScreenState extends State<BidDetailsScreen> {
  final BidService _bidService = BidService();
  List<dynamic> _bids = [];
  bool _loading = true;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _currentUserId = await PreferencesHelper.getUserId();
    final vehicle = widget.bid['vehicle'] as Map<String, dynamic>?;
    final vehicleId = vehicle?['id']?.toString();
    if (vehicleId == null || vehicleId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Vehicle not linked to this bid.';
      });
      return;
    }
    try {
      final list = await _bidService.getVehicleBids(vehicleId);
      if (!mounted) return;
      setState(() {
        _bids = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double _amount(dynamic row) {
    if (row is! Map) return 0;
    final v = row['amount'] ?? row['bid_amount'];
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0;
  }

  int? _uid(dynamic row) {
    if (row is! Map) return null;
    final u = row['user_id'] ?? row['buyer_id'];
    if (u == null) return null;
    if (u is int) return u;
    return int.tryParse(u.toString());
  }

  String _name(dynamic row) {
    if (row is! Map) return 'Bidder';
    return (row['user_name'] ?? row['buyer_name'] ?? 'Bidder').toString();
  }

  int _uniqueBidderCount() {
    final ids = <int>{};
    for (final b in _bids) {
      final u = _uid(b);
      if (u != null) ids.add(u);
    }
    return ids.length;
  }

  List<Map<String, dynamic>> _topBidders() {
    final byUser = <int, Map<String, dynamic>>{};
    for (final b in _bids) {
      if (b is! Map) continue;
      final uid = _uid(b);
      if (uid == null) continue;
      final amt = _amount(b);
      final existing = byUser[uid];
      if (existing == null) {
        byUser[uid] = {
          'user_id': uid,
          'name': _name(b),
          'highest': amt,
          'count': 1,
        };
      } else {
        existing['count'] = (existing['count'] as int) + 1;
        if (amt > (existing['highest'] as double)) {
          existing['highest'] = amt;
        }
      }
    }
    final list = byUser.values.toList();
    list.sort((a, b) => (b['highest'] as double).compareTo(a['highest'] as double));
    return list.take(5).toList();
  }

  List<dynamic> _historyByTime() {
    final copy = List<dynamic>.from(_bids);
    copy.sort((a, b) {
      final ta = _time(a);
      final tb = _time(b);
      return tb.compareTo(ta);
    });
    return copy;
  }

  DateTime _time(dynamic row) {
    if (row is! Map) return DateTime.fromMillisecondsSinceEpoch(0);
    final s = row['bid_time'] ?? row['created_at'];
    if (s == null) return DateTime.fromMillisecondsSinceEpoch(0);
    try {
      return DateTime.parse(s.toString());
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bid = widget.bid;
    final vehicle = bid['vehicle'] as Map<String, dynamic>?;
    final auction = bid['auction'] as Map<String, dynamic>?;
    final bidStatus = bid['bid_status'] as String?;
    final bidStatusText = bid['bid_status_text'] as String?;
    final isBuyNow = bid['is_buy_now'] as bool? ?? false;
    final myAmount = (bid['amount'] is num)
        ? (bid['amount'] as num).toDouble()
        : double.tryParse((bid['bid_amount'] ?? bid['amount'] ?? 0).toString()) ?? 0;
    final currentAuction = auction != null
        ? ((auction['current_bid'] is num)
            ? (auction['current_bid'] as num).toDouble()
            : double.tryParse((auction['current_bid'] ?? 0).toString()) ?? 0)
        : myAmount;
    final imageUrl = vehicle?['imageUrl'] as String? ?? vehicle?['image_url'] as String? ?? 'assets/images/car1.png';
    final title = _vehicleTitle(vehicle);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    final topList = _topBidders();
    final historyList = _historyByTime();
    final uniqueBidders = _uniqueBidderCount();
    final totalBids = _bids.length;
    double avg = 0;
    double high = 0;
    if (_bids.isNotEmpty) {
      final amounts = _bids.map(_amount).toList();
      high = amounts.reduce((a, b) => a > b ? a : b);
      avg = amounts.reduce((a, b) => a + b) / amounts.length;
    }

    return SafeScaffold(
      backgroundColor: Colors.grey[50],
      // Must be false: body uses CustomScrollView — wrapping in SafeScaffold's
      // SingleChildScrollView causes unbounded height / "RenderBox was not laid out".
      enableScroll: false,
      appBar: AppBar(
        title: const Text(
          'Bid details',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        backgroundColor: kAccentColor,
        foregroundColor: kWhiteColor,
        elevation: 0,
        toolbarHeight: 52,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kAccentColor,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  10,
                  10,
                  10,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VehicleHeader(
                      imageUrl: imageUrl,
                      title: title,
                      statusLabel: bidStatusText ?? bidStatus ?? '—',
                      isBuyNow: isBuyNow,
                    ),
                    const SizedBox(height: 8),
                    _SectionCard(
                      title: 'Your participation',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kv('Your bid', currency.format(myAmount)),
                          _kv('Listing status', (vehicle?['status'] ?? '—').toString()),
                          _kv('Bid status', bidStatusText ?? bidStatus ?? '—'),
                          if (isBuyNow) _kv('Type', 'Buy now'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SectionCard(
                      title: 'Auction snapshot',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kv('Current high bid', currency.format(currentAuction)),
                          _kv('Auction state', (auction?['status'] ?? '—').toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: kAccentColor),
                          ),
                        ),
                      )
                    else if (_error != null)
                      _SectionCard(
                        title: 'Auction activity',
                        child: Text(
                          _error!,
                          style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                        ),
                      )
                    else ...[
                      _SectionCard(
                        title: 'Analytics',
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final w = c.maxWidth;
                            final isWide = w > 520;
                            final children = [
                              _miniStat('Total bids', '$totalBids', isWide),
                              _miniStat('Unique bidders', '$uniqueBidders', isWide),
                              _miniStat('Average', currency.format(avg), isWide),
                              _miniStat('Highest', currency.format(high), isWide),
                            ];
                            if (isWide) {
                              return Row(
                                children: children
                                    .map((e) => Expanded(child: e))
                                    .toList(),
                              );
                            }
                            return GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.85,
                              children: children,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SectionCard(
                        title: 'Top bidders',
                        child: topList.isEmpty
                            ? Text(
                                'No competing bids yet.',
                                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < topList.length; i++)
                                    _bidderRow(
                                      rank: i + 1,
                                      name: topList[i]['name'] as String,
                                      amount: topList[i]['highest'] as double,
                                      count: topList[i]['count'] as int,
                                      currency: currency,
                                      isYou: _currentUserId != null &&
                                          topList[i]['user_id'].toString() == _currentUserId,
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 8),
                      _SectionCard(
                        title: 'Bid history',
                        child: historyList.isEmpty
                            ? Text(
                                'No bid history loaded.',
                                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              )
                            : Column(
                                children: [
                                  for (final row in historyList.take(20))
                                    _historyTile(row, currency),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              k,
              style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontSize: 13, color: kBlackColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, bool wide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
            textAlign: wide ? TextAlign.center : TextAlign.start,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kBlackColor),
            textAlign: wide ? TextAlign.center : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _bidderRow({
    required int rank,
    required String name,
    required double amount,
    required int count,
    required NumberFormat currency,
    required bool isYou,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isYou ? kAccentColor.withOpacity(0.12) : kWhiteColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isYou ? kAccentColor.withOpacity(0.45) : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          _rankBadge(rank),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isYou ? '$name (you)' : name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlackColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$count bid${count == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              currency.format(amount),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlackColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(int rank) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kAccentColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$rank',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlackColor),
      ),
    );
  }

  Widget _historyTile(dynamic row, NumberFormat currency) {
    final uid = _uid(row);
    final you = _currentUserId != null && uid != null && uid.toString() == _currentUserId;
    final t = _time(row);
    final dateStr = DateFormat('MMM d, y · h:mm a').format(t);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  you ? '${_name(row)} (you)' : _name(row),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlackColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              currency.format(_amount(row)),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlackColor),
            ),
          ),
        ],
      ),
    );
  }

  String _vehicleTitle(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return 'Vehicle';
    final y = vehicle['year']?.toString().trim() ?? '';
    final make = vehicle['make']?.toString().trim() ?? '';
    final model = vehicle['model']?.toString().trim() ?? '';
    final t = '$y $make $model'.trim();
    return t.isNotEmpty ? t : 'Vehicle';
  }
}

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({
    required this.imageUrl,
    required this.title,
    required this.statusLabel,
    required this.isBuyNow,
  });

  final String imageUrl;
  final String title;
  final String statusLabel;
  final bool isBuyNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _thumb(imageUrl, 88, 72),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final chipMax = c.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBlackColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip(statusLabel, maxWidth: chipMax),
                        if (isBuyNow) _chip('Buy now', maxWidth: chipMax),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {required double maxWidth}) {
    final mw = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 200.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: mw),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kAccentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kAccentColor.withOpacity(0.35)),
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlackColor),
        ),
      ),
    );
  }

  Widget _thumb(String url, double w, double h) {
    final network = url.startsWith('http://') || url.startsWith('https://');
    final asset = url.startsWith('assets/');
    if (network) {
      return Image.network(
        url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: w,
            height: h,
            color: Colors.grey[200],
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey[500]),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: w,
            height: h,
            color: Colors.grey[100],
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kAccentColor,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }
    if (asset) {
      return Image.asset(
        url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: w,
          height: h,
          color: Colors.grey[200],
          child: Icon(Icons.directions_car, color: Colors.grey[400]),
        ),
      );
    }
    return Container(
      width: w,
      height: h,
      color: Colors.grey[200],
      child: Icon(Icons.directions_car, color: Colors.grey[400]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: kBlackColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
