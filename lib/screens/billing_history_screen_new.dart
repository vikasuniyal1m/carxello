// import 'package:flutter/material.dart';
// import 'package:carauction/utils/app_constants.dart';
// import 'package:carauction/utils/responsive_helper.dart';
// import 'package:carauction/widgets/safe_scaffold.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:carauction/services/invoice_service.dart';
// import 'package:intl/intl.dart';
//
// class BillingHistoryScreen extends StatefulWidget {
//   const BillingHistoryScreen({super.key});
//
//   @override
//   State<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
// }
//
// class _BillingHistoryScreenState extends State<BillingHistoryScreen> {
//   final InvoiceService _invoiceService = InvoiceService();
//   List<Map<String, dynamic>> _billingHistory = [];
//   Map<String, dynamic> _statistics = {};
//   bool _isLoading = true;
//   Map<String, bool> _expandedInvoices = {};
//   Map<String, bool> _loadingInvoices = {};
//
//   @override
//   void initState() {
//     super.initState();
//     _loadBillingHistory();
//   }
//
//   Future<void> _loadBillingHistory() async {
//     try {
//       setState(() => _isLoading = true);
//
//       final data = await _invoiceService.getBillingHistory();
//
//       if (mounted) {
//         setState(() {
//           _statistics = data['statistics'] ?? {};
//           _billingHistory = List<Map<String, dynamic>>.from(data['billing_history'] ?? []);
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _isLoading = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to load billing history: ${e.toString()}'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 4),
//           ),
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeScaffold(
//       isLoading: _isLoading,
//       appBar: AppBar(
//         backgroundColor: kAccentColor,
//         foregroundColor: Colors.white,
//         title: Text(
//           'Billing History',
//           style: TextStyle(
//             fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         actions: [
//           if (_billingHistory.isNotEmpty)
//             IconButton(
//               icon: const Icon(Icons.refresh, color: Colors.white),
//               onPressed: _loadBillingHistory,
//             ),
//         ],
//       ),
//       body: _billingHistory.isEmpty
//           ? _buildEmptyState()
//           : RefreshIndicator(
//               onRefresh: _loadBillingHistory,
//               child: ListView.builder(
//                 padding: ResponsiveHelper.safePadding(context, all: 16),
//                 itemCount: _billingHistory.length,
//                 itemBuilder: (context, index) {
//                   final invoice = _billingHistory[index];
//                   final invoiceId = invoice['id']?.toString() ?? '';
//                   final isExpanded = _expandedInvoices[invoiceId] ?? false;
//                   final isLoading = _loadingInvoices[invoiceId] ?? false;
//
//                   return Container(
//                     margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.05),
//                           blurRadius: 8,
//                           offset: const Offset(0, 2),
//                         ),
//                       ],
//                       border: Border.all(
//                         color: isExpanded ? kAccentColor.withOpacity(0.2) : Colors.grey[300]!,
//                         width: isExpanded ? 2 : 1,
//                       ),
//                     ),
//                     child: Column(
//                       children: [
//                         // Invoice Header - Always Visible
//                         _buildInvoiceHeader(invoice),
//
//                         // Expandable Content
//                         GestureDetector(
//                           onTap: () => _toggleInvoiceExpansion(invoiceId),
//                           child: Container(
//                             padding: ResponsiveHelper.safePadding(context, all: 16),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         'Invoice Details',
//                                         style: TextStyle(
//                                           fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
//                                           fontWeight: FontWeight.bold,
//                                           color: kBlackColor,
//                                         ),
//                                       ),
//                                       SizedBox(height: ResponsiveHelper.spacing(context, 8)),
//                                       _buildInfoRow('Amount', _formatCurrency(invoice['total_amount'])),
//                                       _buildInfoRow('Status', _buildStatusBadge(invoice['payment_status'] ?? 'pending')),
//                                       _buildInfoRow('Date', _formatDate(invoice['created_at'])),
//                                     ],
//                                   ),
//                                 ),
//                                 Row(
//                                   children: [
//                                     Icon(
//                                       isExpanded ? Icons.expand_less : Icons.expand_more,
//                                       color: kAccentColor,
//                                       size: ResponsiveHelper.widthMultiplier(context) * 5,
//                                     ),
//                                     SizedBox(width: ResponsiveHelper.spacing(context, 8)),
//                                     if (isLoading)
//                                       SizedBox(
//                                         width: ResponsiveHelper.widthMultiplier(context) * 4,
//                                         height: ResponsiveHelper.widthMultiplier(context) * 4,
//                                         child: const CircularProgressIndicator(
//                                           strokeWidth: 2,
//                                           valueColor: kAccentColor,
//                                         ),
//                                       )
//                                     else
//                                       Text(
//                                         isExpanded ? 'Tap to collapse' : 'Tap to expand',
//                                         style: TextStyle(
//                                           fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
//                                           color: kAccentColor,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                   ],
//                                 ],
//                               ],
//                             ),
//                           ),
//                         ),
//
//                         // Expanded Content - Conditionally Visible
//                         if (isExpanded) _buildExpandedContent(invoice),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//     );
//   }
//
//   Widget _buildInvoiceHeader(Map<String, dynamic> invoice) {
//     return Container(
//       padding: ResponsiveHelper.safePadding(context, all: 16),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Invoice #${invoice['invoice_number'] ?? 'N/A'}',
//                   style: TextStyle(
//                     fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
//                     fontWeight: FontWeight.bold,
//                     color: kAccentColor,
//                   ),
//                 ),
//                 SizedBox(height: ResponsiveHelper.spacing(context, 4)),
//                 Text(
//                   invoice['description'] ?? 'Vehicle Purchase',
//                   style: TextStyle(
//                     fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
//                     color: Colors.grey[600],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Row(
//             children: [
//               _buildActionButton(
//                 'View',
//                 Icons.visibility,
//                 () => _viewInvoice(invoice),
//                 Colors.blue,
//               ),
//               SizedBox(width: ResponsiveHelper.spacing(context, 8)),
//               _buildActionButton(
//                 'Download',
//                 Icons.download,
//                 () => _downloadInvoice(invoice),
//                 Colors.green,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildExpandedContent(Map<String, dynamic> invoice) {
//     return Container(
//       padding: ResponsiveHelper.safePadding(context, horizontal: 16, vertical: 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Bill To Section
//           _buildSectionCard('Bill To:', [
//             _buildDetailText('Name', invoice['full_name']),
//             _buildDetailText('Email', invoice['email']),
//             _buildDetailText('Phone', invoice['phone']),
//             _buildDetailText('Address', invoice['address']),
//           ]),
//
//           SizedBox(height: ResponsiveHelper.spacing(context, 16)),
//
//           // Vehicle Information
//           if (invoice['vehicle_id'] != null)
//             _buildSectionCard('Vehicle Information:', [
//               _buildDetailText('Vehicle', '${invoice['year']} ${invoice['make']} ${invoice['model']}'),
//               _buildDetailText('VIN', invoice['vin']),
//               _buildDetailText('Mileage', '${NumberFormat.decimalPattern().format(invoice['mileage'] ?? 0)} miles'),
//               _buildDetailText('Description', invoice['description'] ?? 'Vehicle Purchase'),
//             ]),
//
//           SizedBox(height: ResponsiveHelper.spacing(context, 16)),
//
//           // Seller Information
//           if (invoice['seller_name'] != null)
//             _buildSectionCard('Seller Information:', [
//               _buildDetailText('Name', invoice['seller_name']),
//               _buildDetailText('Email', invoice['seller_email']),
//               _buildDetailText('Phone', invoice['seller_phone']),
//               _buildDetailText('Address', invoice['seller_address']),
//             ]),
//
//           SizedBox(height: ResponsiveHelper.spacing(context, 16)),
//
//           // Amount Breakdown
//           _buildSectionCard('Amount Breakdown:', [
//             _buildAmountBreakdownRow('Purchase Amount', invoice['amount']),
//             _buildAmountBreakdownRow('Tax Amount', invoice['tax_amount']),
//             _buildAmountBreakdownRow('Total Amount', invoice['total_amount'], isTotal: true),
//           ]),
//
//           SizedBox(height: Responsive.spacing(context, 16)),
//
//           // Payment Information
//           if (invoice['transaction_id'] != null)
//             _buildSectionCard('Payment Information:', [
//               _buildDetailText('Transaction ID', invoice['transaction_id']),
//               _buildDetailText('Payment Method', invoice['payment_method'] ?? 'Stripe'),
//               _buildDetailText('Paid Date', _formatDate(invoice['paid_at'])),
//             ]),
//
//           SizedBox(height: ResponsiveHelper.spacing(context, 16)),
//
//           // Action Buttons
//           Row(
//             children: [
//               Expanded(
//                 child: _buildActionButton(
//                   'View Full Invoice',
//                   Icons.receipt_long,
//                   () => _viewFullInvoice(invoice),
//                   kAccentColor,
//                 ),
//               ),
//               SizedBox(width: ResponsiveHelper.spacing(context, 8)),
//               Expanded(
//                 child: _buildActionButton(
//                   'Share',
//                   Icons.share,
//                   () => _shareInvoice(invoice),
//                   Colors.blue,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSectionCard(String title, List<Widget> children) {
//     return Container(
//       padding: ResponsiveHelper.safePadding(context, all: 16),
//       decoration: BoxDecoration(
//         color: Colors.grey[50],
//         borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
//         border: Border.all(color: Colors.grey[200]!),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
//               fontWeight: FontWeight.bold,
//               color: const Color(0xFF2c3e50),
//             ),
//           ),
//           SizedBox(height: ResponsiveHelper.spacing(context, 12)),
//           ...children,
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDetailText(String label, String? value) {
//     if (value == null || value.isEmpty) return const SizedBox.shrink();
//
//     return Padding(
//       padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 8)),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: ResponsiveHelper.widthMultiplier(context) * 25,
//             child: Text(
//               label,
//               style: TextStyle(
//                 fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
//                 color: Colors.grey[600],
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: TextStyle(
//                 fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
//                 color: Colors.black87,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAmountBreakdownRow(String label, dynamic amount, {bool isTotal = false}) {
//     return Padding(
//       padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 8)),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
//               color: Colors.grey[600],
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           Text(
//             _formatCurrency(amount),
//             style: TextStyle(
//               fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
//               fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
//               color: isTotal ? kAccentColor : Colors.black87,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildActionButton(String text, IconData icon, VoidCallback onPressed, Color color) {
//     return ElevatedButton(
//       onPressed: onPressed,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         foregroundColor: Colors.white,
//         padding: ResponsiveHelper.safePadding(context, horizontal: 16, vertical: 12),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: ResponsiveHelper.widthMultiplier(context) * 4),
//           SizedBox(width: ResponsiveHelper.spacing(context, 8)),
//           Text(
//             text,
//             style: TextStyle(
//               fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
//               fontWeight: FontWeight.w500,
//               color: Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatusBadge(String status) {
//     Color badgeColor;
//     switch (status.toLowerCase()) {
//       case 'paid':
//         badgeColor = Colors.green;
//         break;
//       case 'pending':
//         badgeColor = Colors.orange;
//         break;
//       case 'cancelled':
//         badgeColor = Colors.red;
//         break;
//       default:
//         badgeColor = Colors.grey;
//         break;
//     }
//
//     return Container(
//       padding: EdgeInsets.symmetric(
//         horizontal: ResponsiveHelper.spacing(context, 8),
//         vertical: ResponsiveHelper.spacing(context, 4),
//       ),
//       decoration: BoxDecoration(
//         color: badgeColor.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Text(
//         status.toUpperCase(),
//         style: TextStyle(
//           fontSize: ResponsiveHelper.fontSize(context, mobile: 10),
//           fontWeight: FontWeight.bold,
//           color: badgeColor,
//         ),
//       ),
//     );
//   }
//
//   String _formatCurrency(dynamic amount) {
//     if (amount == null) return '\$0.00';
//     final double amountDouble = amount is String
//         ? double.tryParse(amount) ?? 0.0
//         : amount.toDouble();
//     return '\$${amountDouble.toStringAsFixed(2)}';
//   }
//
//   String _formatDate(String? dateString) {
//     if (dateString == null || dateString.isEmpty) return 'N/A';
//     try {
//       final date = DateTime.parse(dateString);
//       return DateFormat('MMM d, yyyy').format(date);
//     } catch (e) {
//       return dateString;
//     }
//   }
//
//   void _toggleInvoiceExpansion(String invoiceId) {
//     setState(() {
//       _expandedInvoices[invoiceId] = !(_expandedInvoices[invoiceId] ?? false);
//     });
//   }
//
//   void _viewInvoice(Map<String, dynamic> invoice) {
//     // Navigate to invoice view screen
//     print('Viewing invoice: ${invoice['invoice_number']}');
//   }
//
//   void _viewFullInvoice(Map<String, dynamic> invoice) {
//     // Navigate to full invoice screen
//     print('Viewing full invoice: ${invoice['invoice_number']}');
//   }
//
//   void _downloadInvoice(Map<String, dynamic> invoice) async {
//     final invoiceId = invoice['id']?.toString() ?? '';
//     final invoiceNumber = invoice['invoice_number'] as String? ?? 'N/A';
//
//     setState(() {
//       _loadingInvoices[invoiceId] = true;
//     });
//
//     try {
//       // Simulate download - in real app, this would call the download service
//       await Future.delayed(const Duration(seconds: 2));
//
//       if (mounted) {
//         setState(() {
//           _loadingInvoices[invoiceId] = false;
//         });
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invoice $invoiceNumber downloaded successfully!'),
//             backgroundColor: Colors.green,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _loadingInvoices[invoiceId] = false;
//         });
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to download invoice: ${e.toString()}'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }
//
//   void _shareInvoice(Map<String, dynamic> invoice) {
//     final invoiceNumber = invoice['invoice_number'] as String? ?? 'N/A';
//
//     // Simulate share - in real app, this would use share plugin
//     print('Sharing invoice: $invoiceNumber');
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Invoice $invoiceNumber shared successfully!'),
//         backgroundColor: Colors.blue,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.receipt_long,
//             size: ResponsiveHelper.widthMultiplier(context) * 15,
//             color: Colors.grey[400],
//           ),
//           SizedBox(height: ResponsiveHelper.spacing(context, 16)),
//           Text(
//             'No billing history available',
//             style: TextStyle(
//               fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
//               color: Colors.grey[600],
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           SizedBox(height: ResponsiveHelper.spacing(context, 8)),
//           ElevatedButton(
//             onPressed: _loadBillingHistory,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: kAccentColor,
//               foregroundColor: Colors.white,
//               padding: ResponsiveHelper.safePadding(context, horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
//               ),
//             ),
//             child: const Text('Refresh'),
//           ),
//         ],
//       ),
//     );
//   }
// }
