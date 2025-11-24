import 'package:flutter/material.dart';
import 'shared_styles.dart';
import 'order_screen.dart';
import 'order_detail_screen.dart';
import 'models/order_model.dart'; // Import our new Model
import 'services/firestore_service.dart'; // Import the Service

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

  // Helper to determine the next order number based on the current list
  int _getNextOrderNumber(List<OrderModel> currentOrders) {
    if (currentOrders.isEmpty) return 1;
    int max = 0;
    for (var o in currentOrders) {
      if (o.orderNumber > max) max = o.orderNumber;
    }
    return max + 1;
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
      // UPDATE FIREBASE: Ensure we keep the same ID so it updates, not creates new
      final updatedOrder = OrderModel(
        id: order.id, // KEEP THE FIRESTORE ID
        tableNumber: result.tableNumber,
        orderNumber: result.orderNumber,
        totalItems: result.totalItems,
        timestamp: order.timestamp, // Keep original time
        tacoCounts: result.tacoCounts,
        sodaCounts: result.sodaCounts,
        simpleExtraCounts: result.simpleExtraCounts,
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

  @override
  Widget build(BuildContext context) {
    String title = 'Mesa ${widget.tableNumber}';

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, title),

            // --- STREAM BUILDER ---
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: _firestoreService.getOrdersForTable(widget.tableNumber),
                builder: (context, snapshot) {
                  // 1. Loading State
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kAccentColor));
                  }

                  // 2. Error State
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  }

                  final orders = snapshot.data ?? [];

                  // 3. Empty State
                  if (orders.isEmpty) {
                    return _buildEmptyState();
                  }

                  // 4. List Data
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

            _buildSubmitTableOrderButton(context),
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
          const Icon(Icons.menu_book_outlined, color: kShadowColor, size: 80),
          const SizedBox(height: 20),
          const Text(
            'Aún no hay órdenes',
            style: TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            'Presiona el botón "+" para agregar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextColor.withOpacity(0.7), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderModel order) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToViewOrder(context, order),
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Orden ${order.orderNumber}',
                        style: const TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${order.totalItems} Items',
                        style: const TextStyle(color: kTextColor, fontSize: 18, fontWeight: FontWeight.w500),
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
              child: const NeumorphicContainer(
                isCircle: true,
                padding: EdgeInsets.all(12),
                child: Icon(Icons.edit_outlined, color: kAccentColor, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitTableOrderButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: NeumorphicContainer(
          padding: const EdgeInsets.symmetric(vertical: 20),
          borderRadius: 20,
          child: const Center(
            child: Text(
              'Finalizar Mesa',
              style: TextStyle(color: kAccentColor, fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String title) {
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
            title,
            style: const TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700),
          ),

          // ADD BUTTON: Wrapped in StreamBuilder to calculate the next Order Number
          StreamBuilder<List<OrderModel>>(
              stream: _firestoreService.getOrdersForTable(widget.tableNumber),
              builder: (context, snapshot) {
                final orders = snapshot.data ?? [];
                final nextId = _getNextOrderNumber(orders);

                return GestureDetector(
                  onTap: () => _navigateToAddOrder(context, nextId),
                  child: const NeumorphicContainer(
                    isCircle: true,
                    padding: EdgeInsets.all(14),
                    child: Icon(Icons.add, color: kAccentColor, size: 22),
                  ),
                );
              }
          ),
        ],
      ),
    );
  }
}