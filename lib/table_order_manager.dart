import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'shared_styles.dart';
import 'order_screen.dart';
import 'order_detail_screen.dart';
import 'models/order_model.dart';
import 'models/inventory_model.dart'; // Needed for Pricing
import 'services/firestore_service.dart';

class TableOrderManagerScreen extends StatefulWidget {
  final int tableNumber;
  final Map<String, bool> availableFlavors;
  final Map<String, bool> availableExtras;

  const TableOrderManagerScreen({
    super.key,
    required this.tableNumber,
    required this.availableFlavors,
    required this.availableExtras,
  });

  @override
  State<TableOrderManagerScreen> createState() =>
      _TableOrderManagerScreenState();
}

class _TableOrderManagerScreenState extends State<TableOrderManagerScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, double> _priceMap = {}; // Local cache for prices

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  void _loadPrices() {
    _firestoreService.getInventoryStream().listen((items) {
      if (mounted) {
        setState(() {
          _priceMap = {for (var item in items) item.name: item.price};
        });
      }
    });
  }

  // --- CALCULATE TOTAL FOR ALL ORDERS AT TABLE ---
  double _calculateTableTotal(List<OrderModel> orders) {
    double total = 0.0;
    for (var order in orders) {
      order.tacoCounts.forEach((name, qty) {
        total += (_priceMap[name] ?? 0.0) * qty;
      });
      order.simpleExtraCounts.forEach((name, qty) {
        total += (_priceMap[name] ?? 0.0) * qty;
      });
      order.sodaCounts.forEach((name, temps) {
        int qty = (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
        total += (_priceMap[name] ?? 0.0) * qty;
      });
    }
    return total;
  }

  // --- CLOSE TABLE LOGIC ---
  Future<void> _processTableCheckout(List<OrderModel> orders) async {
    HapticFeedback.heavyImpact();
    try {
      // Process each order individually (Mark paid/Delete)
      for (var order in orders) {
        await _firestoreService.processCheckout(order);
      }
      if (mounted) {
        Navigator.pop(context); // Close BottomSheet
        Navigator.pop(context); // Go back to Table Selection
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Mesa ${widget.tableNumber} cerrada exitosamente"),
              backgroundColor: Colors.green,
            )
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  int _getNextOrderNumber(List<OrderModel> currentOrders) {
    if (currentOrders.isEmpty) return 1;
    int max = 0;
    for (var o in currentOrders) {
      if (o.orderNumber > max) max = o.orderNumber;
    }
    return max + 1;
  }

  int _getServedCount(OrderModel order) {
    int total = 0;
    order.tacoServed.forEach((_, count) => total += count);
    order.simpleExtraServed.forEach((_, count) => total += count);
    order.sodaServed.forEach((_, temps) {
      total += (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
    });
    return total;
  }

  void _navigateToAddOrder(BuildContext context, int nextOrderNumber) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderScreen(
          orderType: 'Mesa ${widget.tableNumber}',
          tableNumber: widget.tableNumber,
          orderNumber: nextOrderNumber,
          availableFlavors: widget.availableFlavors,
          availableExtras: widget.availableExtras,
          existingOrder: null,
        ),
      ),
    );

    if (result != null && result is OrderModel) {
      await _firestoreService.addOrder(result);
    }
  }

  void _navigateToEditOrder(BuildContext context, OrderModel order) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderScreen(
          orderType: 'Mesa ${widget.tableNumber}',
          tableNumber: widget.tableNumber,
          orderNumber: order.orderNumber,
          availableFlavors: widget.availableFlavors,
          availableExtras: widget.availableExtras,
          existingOrder: order,
        ),
      ),
    );

    if (result != null && result is OrderModel) {
      final updatedOrder = OrderModel(
        id: order.id,
        tableNumber: result.tableNumber,
        orderNumber: result.orderNumber,
        totalItems: result.totalItems,
        timestamp: order.timestamp,
        customerName: result.customerName,
        tacoCounts: result.tacoCounts,
        sodaCounts: result.sodaCounts,
        simpleExtraCounts: result.simpleExtraCounts,
        tacoServed: order.tacoServed,
        sodaServed: order.sodaServed,
        simpleExtraServed: order.simpleExtraServed,
      );

      await _firestoreService.updateOrder(updatedOrder);
    }
  }

  void _navigateToViewOrder(BuildContext context, OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(
          orderDetails: order,
        ),
      ),
    );
  }

  // --- UPDATED: Show Check Preview with Real Data ---
  void _showCheckPreview(BuildContext context, List<OrderModel> orders) {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay órdenes para cobrar")));
      return;
    }

    double total = _calculateTableTotal(orders);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: kBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 50, color: kAccentColor),
            const SizedBox(height: 15),
            Text("Cuenta Mesa ${widget.tableNumber}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor)),
            const SizedBox(height: 20),
            // REAL TOTAL DISPLAY
            Text("Total a Pagar: \$${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, color: kAccentColor, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text("${orders.length} Órdenes combinadas", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: NeumorphicContainer(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      borderRadius: 15,
                      child: const Center(child: Text("Seguir ordenando", style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _processTableCheckout(orders), // CALL CLOSURE FUNCTION
                    child: NeumorphicContainer(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      borderRadius: 15,
                      child: const Center(child: Text("Cerrar Mesa", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<List<OrderModel>>(
          // --- MOVED StreamBuilder UP: Wraps the whole UI ---
          stream: _firestoreService.getOrdersForTable(widget.tableNumber),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: kAccentColor));
            }

            final orders = snapshot.data ?? [];
            final nextId = _getNextOrderNumber(orders);

            return Column(
              children: [
                // AppBar needs context to call _navigateToAddOrder
                _buildAppBar(context, 'Mesa ${widget.tableNumber}', nextId),

                Expanded(
                  child: orders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderItem(orders[index]);
                    },
                  ),
                ),

                // --- BOTTOM BAR (Check Button) ---
                if (orders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            // Pass the current list of orders to the function
                            onTap: () => _showCheckPreview(context, orders),
                            child: NeumorphicContainer(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              borderRadius: 20,
                              child: const Center(
                                child: Text(
                                  'Pedir Cuenta',
                                  style: TextStyle(color: kAccentColor, fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, color: kShadowColor, size: 80),
          const SizedBox(height: 20),
          const Text('Aún no hay órdenes', style: TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text('Presiona el botón "+" para agregar.', textAlign: TextAlign.center, style: TextStyle(color: kTextColor.withOpacity(0.7), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderModel order) {
    int servedCount = _getServedCount(order);
    double progress = order.totalItems > 0 ? servedCount / order.totalItems : 0.0;
    bool isFullyServed = servedCount >= order.totalItems && order.totalItems > 0;

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
                    onTap: () => _navigateToViewOrder(context, order),
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Orden ${order.orderNumber}', style: const TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w700)),
                              Text(isFullyServed ? 'Completada' : 'En Progreso', style: TextStyle(color: isFullyServed ? Colors.green : kAccentColor, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$servedCount / ${order.totalItems}', style: const TextStyle(color: kTextColor, fontSize: 18, fontWeight: FontWeight.w700)),
                              const Text('Servidos', style: TextStyle(color: kTextColor, fontSize: 12)),
                            ],
                          ),
                          const Icon(Icons.arrow_forward_ios, color: kTextColor, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _navigateToEditOrder(context, order),
                  child: const NeumorphicContainer(isCircle: true, padding: EdgeInsets.all(12), child: Icon(Icons.edit_outlined, color: kAccentColor, size: 22)),
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

  Widget _buildAppBar(BuildContext context, String title, int nextOrderNumber) {
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
          Text(title, style: const TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700)),
          GestureDetector(
            onTap: () => _navigateToAddOrder(context, nextOrderNumber),
            child: const NeumorphicContainer(
              isCircle: true,
              padding: EdgeInsets.all(14),
              child: Icon(Icons.add, color: kAccentColor, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}