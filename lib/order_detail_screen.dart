import 'package:flutter/material.dart';
import 'shared_styles.dart';
import 'models/order_model.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel orderDetails;

  const OrderDetailScreen({super.key, required this.orderDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (orderDetails.tacoCounts.isNotEmpty) ...[
                    SliverToBoxAdapter(
                        child: _buildSectionHeader('Tacos (${_getTacoTotal()})')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final entry = orderDetails.tacoCounts.entries.elementAt(index);
                          final served = orderDetails.tacoServed[entry.key] ?? 0;
                          return _buildDetailItem(entry.key, entry.value, served);
                        },
                        childCount: orderDetails.tacoCounts.length,
                      ),
                    ),
                  ],

                  if (orderDetails.sodaCounts.isNotEmpty) ...[
                    SliverToBoxAdapter(child:
                    _buildSectionHeader('Refrescos (${_getSodaTotal()})')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final entry = orderDetails.sodaCounts.entries.elementAt(index);
                          return _buildSodaDetailItem(entry.key, entry.value);
                        },
                        childCount: orderDetails.sodaCounts.length,
                      ),
                    ),
                  ],

                  if (orderDetails.simpleExtraCounts.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _buildSectionHeader(
                        'Extras (${_getExtraTotal()})')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final entry = orderDetails.simpleExtraCounts.entries.elementAt(index);
                          final served = orderDetails.simpleExtraServed[entry.key] ?? 0;
                          return _buildDetailItem(entry.key, entry.value, served);
                        },
                        childCount: orderDetails.simpleExtraCounts.length,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildTotalSummary(),
          ],
        ),
      ),
    );
  }

  int _getTacoTotal() {
    return orderDetails.tacoCounts.values.fold(0, (sum, count) => sum + count);
  }

  int _getSodaTotal() {
    int total = 0;
    for (var temps in orderDetails.sodaCounts.values) {
      total += (temps['Frío'] ?? 0).toInt() + (temps['Al Tiempo'] ?? 0).toInt();
    }
    return total;
  }

  int _getExtraTotal() {
    return orderDetails.simpleExtraCounts.values.fold(0, (sum, count) => sum + count);
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const NeumorphicContainer(
              isCircle: true,
              padding: EdgeInsets.all(14),
              child: Icon(Icons.arrow_back_ios_new, color: kAccentColor, size: 20),
            ),
          ),
          Text(
            'Detalle Orden ${orderDetails.orderNumber}',
            style: const TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Text(
        title,
        style: const TextStyle(color: kAccentColor, fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  // --- UPDATE: Now accepts 'served' count ---
  Widget _buildDetailItem(String name, int ordered, int served) {
    bool isComplete = served >= ordered;
    int pending = ordered - served;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: NeumorphicContainer( // Wrapped in container for better visibility
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  '$ordered x ',
                  style: const TextStyle(color: kAccentColor, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  name,
                  style: const TextStyle(color: kTextColor, fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),

            // --- Status Indicator ---
            if (isComplete)
              const Row(
                children: [
                  Text("Servido", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  SizedBox(width: 5),
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: kAccentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text("Faltan $pending", style: const TextStyle(color: kAccentColor, fontWeight: FontWeight.bold)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildSodaDetailItem(String name, Map<String, int> temps) {
    final int coldOrdered = temps['Frío'] ?? 0;
    final int warmOrdered = temps['Al Tiempo'] ?? 0;

    final int coldServed = orderDetails.sodaServed[name]?['Frío'] ?? 0;
    final int warmServed = orderDetails.sodaServed[name]?['Al Tiempo'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(color: kTextColor, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            if (coldOrdered > 0) ...[
              _buildSubItemRow("Frío", coldOrdered, coldServed),
            ],
            if (warmOrdered > 0) ...[
              const SizedBox(height: 5),
              _buildSubItemRow("Al Tiempo", warmOrdered, warmServed),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSubItemRow(String label, int ordered, int served) {
    bool isComplete = served >= ordered;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$ordered x $label',
          style: TextStyle(color: kTextColor.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500),
        ),
        if (isComplete)
          const Icon(Icons.check_circle, color: Colors.green, size: 18)
        else
          Text("Faltan ${ordered - served}", style: const TextStyle(color: kAccentColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTotalSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      decoration: const BoxDecoration(
        color: kBackgroundColor,
        border: Border(top: BorderSide(color: kShadowColor, width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Items:',
            style: TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w500),
          ),
          Text(
            '${orderDetails.totalItems}',
            style: const TextStyle(color: kTextColor, fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}