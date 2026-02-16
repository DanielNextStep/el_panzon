import 'package:flutter/material.dart';
import 'shared_styles.dart';
import 'table_order_manager.dart'; // Import TableOrderManager
import 'order_screen.dart';
import 'order_detail_screen.dart';
import 'models/order_model.dart';
import 'models/inventory_model.dart'; // Needed for pricing
import 'services/firestore_service.dart';
import 'checkout_screen.dart';

class ToGoOrdersScreen extends StatefulWidget {
  final Map<String, bool> availableFlavors;
  final Map<String, bool> availableExtras;

  const ToGoOrdersScreen({
    super.key,
    required this.availableFlavors,
    required this.availableExtras,
  });

  @override
  State<ToGoOrdersScreen> createState() => _ToGoOrdersScreenState();
}

class _ToGoOrdersScreenState extends State<ToGoOrdersScreen> {
  final FirestoreService _firestoreService = FirestoreService();


  // Helper to calculate served count
  int _getServedCount(OrderModel order) {
    int total = 0;

    // 1. Check New Structure (People)
    if (order.people.isNotEmpty) {
      order.people.forEach((_, person) {
        for (var item in person.items) {
          total += (item.extras['served'] as int? ?? 0);
        }
      });
    }

    // 2. Check Legacy Structure (Fallback / Backward Compatibility)
    // We add this because some old orders might only have legacy data.
    // However, if we migrated to only use People for new orders, we should be careful not to double count
    // if we ever decide to sync them. But for now, they are either/or in my implementation.
    // If 'people' is empty, we check legacy.
    if (order.people.isEmpty) {
      order.tacoServed.forEach((_, count) => total += count);
      order.simpleExtraServed.forEach((_, count) => total += count);
      order.sodaServed.forEach((_, temps) {
        total += (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
      });
    }

    return total;
  }

  int _getNextOrderNumber(List<OrderModel> currentOrders) {
    if (currentOrders.isEmpty) return 1;
    int max = 0;
    for (var o in currentOrders) {
      if (o.orderNumber > max) max = o.orderNumber;
    }
    return max + 1;
  }

  void _navigateToAddOrder(BuildContext context, int nextOrderNumber) async {
    // 1. Create Initial Empty Order
    final newOrder = OrderModel(
      tableNumber: 0, // 0 = To Go
      orderNumber: nextOrderNumber,
      totalItems: 0,
      timestamp: DateTime.now(),
      people: {},
      tacoCounts: {}, sodaCounts: {}, simpleExtraCounts: {},
      tacoServed: {}, sodaServed: {}, simpleExtraServed: {},
    );

    // 2. Add to Firestore to get ID
    // We assume addOrder returns DocumentReference
    final ref = await _firestoreService.addOrder(newOrder);

    // 3. Navigate to Manager with ID
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TableOrderManagerScreen(
            tableNumber: 0,
            orderId: ref.id,
            availableFlavors: widget.availableFlavors,
            availableExtras: widget.availableExtras,
          ),
        ),
      );
    }
  }

  void _navigateToEditOrder(BuildContext context, OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TableOrderManagerScreen(
          tableNumber: 0,
          orderId: order.id,
          availableFlavors: widget.availableFlavors,
          availableExtras: widget.availableExtras,
        ),
      ),
    );
  }

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
                // We use Table 0 for "To Go" orders
                stream: _firestoreService.getOrdersForTable(0),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kAccentColor));
                  }
                  final orders = snapshot.data ?? [];

                  if (orders.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderItem(order);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_bag_outlined, color: kShadowColor, size: 80),
          const SizedBox(height: 20),
          const Text('No hay pedidos para llevar', style: TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderModel order) {
    int servedCount = _getServedCount(order);
    double progress = order.totalItems > 0 ? servedCount / order.totalItems : 0.0;
    bool isFullyServed = servedCount >= order.totalItems && order.totalItems > 0;

    // Use Name if available, otherwise Order ID
    String displayName = order.customerName != null && order.customerName!.isNotEmpty
        ? order.customerName!
        : "Orden #${order.orderNumber}";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(orderDetails: order))),
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: const TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w700)),
                              Text(isFullyServed ? 'Listo para entregar' : 'Preparando...', style: TextStyle(color: isFullyServed ? Colors.green : kAccentColor, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),

                          // --- CLOSURE BUTTON (Pay & Close) ---
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckoutScreen(order: order),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: kBackgroundColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: kShadowColor.withOpacity(0.5), offset: const Offset(3, 3), blurRadius: 5),
                                  BoxShadow(color: Colors.white, offset: const Offset(-3, -3), blurRadius: 5),
                                ],
                              ),
                              child: const Icon(Icons.attach_money, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                GestureDetector(
                  onTap: () => _navigateToEditOrder(context, order),
                  child: const Icon(Icons.edit_outlined, color: kAccentColor, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: kShadowColor.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(isFullyServed ? Colors.green : kAccentColor),
                minHeight: 6,
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
          GestureDetector(onTap: () => Navigator.of(context).pop(), child: const NeumorphicContainer(isCircle: true, padding: EdgeInsets.all(14), child: Icon(Icons.arrow_back_ios_new, color: kAccentColor, size: 20))),
          const Text("Para Llevar", style: TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700)),
          StreamBuilder<List<OrderModel>>(
              stream: _firestoreService.getOrdersForTable(0),
              builder: (context, snapshot) {
                final orders = snapshot.data ?? [];
                final nextId = _getNextOrderNumber(orders);
                return GestureDetector(onTap: () => _navigateToAddOrder(context, nextId), child: const NeumorphicContainer(isCircle: true, padding: EdgeInsets.all(14), child: Icon(Icons.add, color: kAccentColor, size: 22)));
              }
          ),
        ],
      ),
    );
  }
}

class NeumorphicButton extends StatelessWidget {
  final String text; final VoidCallback onTap;
  const NeumorphicButton({super.key, required this.text, required this.onTap});
  @override Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: NeumorphicContainer(borderRadius: 25, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: Center(child: Text(text, style: const TextStyle(color: kAccentColor, fontSize: 18, fontWeight: FontWeight.w700)))));
  }
}