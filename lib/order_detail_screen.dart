import 'package:flutter/material.dart';
import 'shared_styles.dart';
import 'models/order_model.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel orderDetails;

  const OrderDetailScreen({super.key, required this.orderDetails});

  @override
  Widget build(BuildContext context) {
    // 1. Check for modern structure (PersonOrder)
    bool useNewStructure = orderDetails.people.isNotEmpty;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: useNewStructure
                  ? _buildNewStructureList()
                  : _buildLegacyStructureList(),
            ),
            _buildTotalSummary(),
          ],
        ),
      ),
    );
  }

  // --- NEW STRUCTURE RENDERING (PersonOrder) ---
  Widget _buildNewStructureList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: orderDetails.people.length,
      itemBuilder: (context, index) {
        final person = orderDetails.people.values.elementAt(index);
        return _buildPersonSection(person);
      },
    );
  }

  Widget _buildPersonSection(PersonOrder person) {
    // Group Items by Name for cleaner display if needed, but linear is fine for detail
    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name
            Row(
              children: [
                const Icon(Icons.person, color: kAccentColor),
                const SizedBox(width: 10),
                Text(
                  person.name,
                  style: const TextStyle(
                      color: kTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            // Salsas
            if (person.salsas.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: person.salsas.map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 12, color: Colors.white)),
                        backgroundColor: _getSalsaColor(s),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                ),
            ],

            const Divider(height: 25),

            // Items
            ...person.items.map((item) {
               int served = item.extras['served'] ?? 0;
               // Auto-serve Check for Desechables display
               if (item.name == 'Desechables') served = item.quantity;
               
               return _buildDetailItem(item.name, item.quantity, served);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getSalsaColor(String salsa) {
      if (salsa.toLowerCase().contains('roja')) return Colors.red[700]!;
      if (salsa.toLowerCase().contains('verde')) return Colors.green[700]!;
      if (salsa.toLowerCase().contains('habanero')) return Colors.orange[800]!;
      return Colors.grey;
  }

  // --- LEGACY STRUCTURE RENDERING (Fallback) ---
  Widget _buildLegacyStructureList() {
    return CustomScrollView(
      slivers: [
        if (orderDetails.tacoCounts.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildSectionHeader('Tacos')),
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
          SliverToBoxAdapter(child: _buildSectionHeader('Refrescos')),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = orderDetails.sodaCounts.entries.elementAt(index);
                // Simple Display for Legacy Sodas
                int total = (entry.value['Frío'] ?? 0) + (entry.value['Al Tiempo'] ?? 0);
                int served = (orderDetails.sodaServed[entry.key]?['Frío'] ?? 0) + (orderDetails.sodaServed[entry.key]?['Al Tiempo'] ?? 0);
                return _buildDetailItem(entry.key, total, served);
              },
              childCount: orderDetails.sodaCounts.length,
            ),
          ),
        ],
        if (orderDetails.simpleExtraCounts.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildSectionHeader('Extras')),
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
    );
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
            orderDetails.customerName ?? 'Orden ${orderDetails.orderNumber}',
            style: const TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 48), // Spacer for balance
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

  Widget _buildDetailItem(String name, int ordered, int served) {
    bool isComplete = served >= ordered;
    int pending = ordered - served;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '$ordered x ',
                style: const TextStyle(color: kAccentColor, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                name,
                style: const TextStyle(color: kTextColor, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (isComplete)
            const Icon(Icons.check_circle, color: Colors.green, size: 20)
          else
            Text("Falta $pending", style: const TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
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