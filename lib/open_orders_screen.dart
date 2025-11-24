import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'shared_styles.dart';
import 'models/order_model.dart';
import 'services/firestore_service.dart';

class OpenOrdersScreen extends StatefulWidget {
  const OpenOrdersScreen({super.key});

  @override
  State<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends State<OpenOrdersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: FirestoreService().getAllActiveOrdersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final orders = snapshot.data ?? [];

                  // --- SPLIT ORDERS: Active vs Completed ---
                  final activeOrders = orders.where((o) => !o.isFullyServed).toList();
                  final completedOrders = orders.where((o) => o.isFullyServed).toList();

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (activeOrders.isEmpty && completedOrders.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 50), child: Center(child: Text("No hay órdenes", style: TextStyle(color: kTextColor, fontSize: 18)))),

                      // --- ACTIVE ORDERS LIST ---
                      ...activeOrders.map((order) => _OrderServiceCard(order: order)),

                      // --- HISTORY SECTION ---
                      if (completedOrders.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        ExpansionTile(
                          title: Text(
                              "Historial de Hoy (${completedOrders.length})",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor)
                          ),
                          collapsedBackgroundColor: Colors.white.withOpacity(0.5),
                          backgroundColor: Colors.white.withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          children: completedOrders.map((order) => _OrderServiceCard(order: order, isHistory: true)).toList(),
                        ),
                        const SizedBox(height: 50),
                      ]
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
          const Text(
            'Cocina / Servicio',
            style: TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _OrderServiceCard extends StatelessWidget {
  final OrderModel order;
  final bool isHistory;
  final FirestoreService _service = FirestoreService();

  _OrderServiceCard({required this.order, this.isHistory = false});

  void _serveItem(String type, String name, {String? subType}) {
    if (isHistory) return; // Can't edit history

    HapticFeedback.lightImpact();
    final newTacoServed = Map<String, int>.from(order.tacoServed);
    final newExtraServed = Map<String, int>.from(order.simpleExtraServed);
    final newSodaServed = Map<String, Map<String, int>>.from(order.sodaServed);

    if (type == 'taco') {
      int current = newTacoServed[name] ?? 0;
      int ordered = order.tacoCounts[name] ?? 0;
      if (current < ordered) newTacoServed[name] = current + 1;
    } else if (type == 'extra') {
      int current = newExtraServed[name] ?? 0;
      int ordered = order.simpleExtraCounts[name] ?? 0;
      if (current < ordered) newExtraServed[name] = current + 1;
    } else if (type == 'soda' && subType != null) {
      if (!newSodaServed.containsKey(name)) newSodaServed[name] = {'Frío': 0, 'Al Tiempo': 0};
      int current = newSodaServed[name]![subType] ?? 0;
      int ordered = order.sodaCounts[name]![subType] ?? 0;
      if (current < ordered) {
        final innerMap = Map<String, int>.from(newSodaServed[name]!);
        innerMap[subType] = current + 1;
        newSodaServed[name] = innerMap;
      }
    }

    final updatedOrder = OrderModel(
      id: order.id,
      tableNumber: order.tableNumber,
      orderNumber: order.orderNumber,
      totalItems: order.totalItems,
      timestamp: order.timestamp,
      customerName: order.customerName,
      tacoCounts: order.tacoCounts,
      sodaCounts: order.sodaCounts,
      simpleExtraCounts: order.simpleExtraCounts,
      tacoServed: newTacoServed,
      simpleExtraServed: newExtraServed,
      sodaServed: newSodaServed,
    );

    _service.updateOrder(updatedOrder);
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = "${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')}";
    // To Go orders (Table 0) use Name, Tables use Table Number
    String headerTitle = order.tableNumber == 0
        ? "Para Llevar: ${order.customerName ?? 'Sin Nombre'}"
        : "Mesa ${order.tableNumber} (Ord #${order.orderNumber})";

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeumorphicContainer(
        borderRadius: 15,
        child: Opacity(
          opacity: isHistory ? 0.6 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(headerTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextColor)),
                  Text(timeStr, style: TextStyle(color: kTextColor.withOpacity(0.5))),
                ],
              ),
              const Divider(),

              ...order.tacoCounts.entries.map((e) => _buildRow('taco', e.key, e.value, order.tacoServed[e.key] ?? 0)),
              ...order.simpleExtraCounts.entries.map((e) => _buildRow('extra', e.key, e.value, order.simpleExtraServed[e.key] ?? 0)),
              ..._buildSodaRows(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSodaRows() {
    List<Widget> rows = [];
    order.sodaCounts.forEach((flavor, temps) {
      if (temps['Frío']! > 0) {
        int served = order.sodaServed[flavor]?['Frío'] ?? 0;
        rows.add(_buildRow('soda', "$flavor (Frío)", temps['Frío']!, served, realName: flavor, subType: 'Frío'));
      }
      if (temps['Al Tiempo']! > 0) {
        int served = order.sodaServed[flavor]?['Al Tiempo'] ?? 0;
        rows.add(_buildRow('soda', "$flavor (Tiempo)", temps['Al Tiempo']!, served, realName: flavor, subType: 'Al Tiempo'));
      }
    });
    return rows;
  }

  Widget _buildRow(String type, String label, int ordered, int served, {String? realName, String? subType}) {
    bool isFullyServed = served >= ordered;
    int pending = ordered - served;

    return GestureDetector(
      onTap: isFullyServed ? null : () => _serveItem(type, realName ?? label, subType: subType),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // CHANGE COLOR: Green if done, Orange/White if pending
            color: isFullyServed
                ? Colors.green.withOpacity(0.1)
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isFullyServed ? Colors.green.withOpacity(0.3) : kAccentColor.withOpacity(0.3)
            )
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isFullyServed ? Colors.green : kTextColor,
                    decoration: isFullyServed ? TextDecoration.lineThrough : null,
                  )
              ),
            ),
            Row(
              children: [
                // Show Pending Count clearly
                if (!isFullyServed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: kAccentColor, borderRadius: BorderRadius.circular(10)),
                    child: Text("Faltan $pending", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                const SizedBox(width: 10),
                Icon(
                    isFullyServed ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isFullyServed ? Colors.green : kTextColor.withOpacity(0.3)
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}