import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shared_styles.dart';
import 'order_screen.dart';
import 'models/order_model.dart';
import 'models/inventory_model.dart';
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
  State<TableOrderManagerScreen> createState() => _TableOrderManagerScreenState();
}

class _TableOrderManagerScreenState extends State<TableOrderManagerScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, double> _priceMap = {};

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

  double _calculateGrandTotal(OrderModel order) {
    double total = 0.0;
    order.people.forEach((key, person) {
      for (var item in person.items) {
        double price = _priceMap[item.name] ?? 0.0;
        total += price * item.quantity;
      }
    });
    return total;
  }

  double _calculatePersonTotal(PersonOrder person) {
    double total = 0.0;
    for (var item in person.items) {
      double price = _priceMap[item.name] ?? 0.0;
      total += price * item.quantity;
    }
    return total;
  }

  // --- Streamlined Flow: Add Person & Go to Menu ---
  Future<void> _addPersonAndOrder(OrderModel? existingOrder) async {
    // 1. If no order exists, create it locally first (don't save yet, wait for person)
    OrderModel order = existingOrder ?? OrderModel(
      tableNumber: widget.tableNumber,
      orderNumber: DateTime.now().millisecondsSinceEpoch % 10000,
      totalItems: 0,
      timestamp: DateTime.now(),
      people: {},
      tacoCounts: {}, sodaCounts: {}, simpleExtraCounts: {},
      tacoServed: {}, sodaServed: {}, simpleExtraServed: {},
    );

    // 2. Generate Name Automatically (Numerical)
    int nextIndex = order.people.length + 1;
    String pId = "P$nextIndex-${DateTime.now().millisecondsSinceEpoch}";
    String name = "Persona $nextIndex"; // Auto-generated name

    // 3. Create Person Object
    PersonOrder newPerson = PersonOrder(name: name, items: []);

    // 4. Update Order Model (Add empty person)
    Map<String, PersonOrder> updatedPeople = Map.from(order.people);
    updatedPeople[pId] = newPerson;

    // 5. IF this is a NEW table, we must save the order to Firestore FIRST
    // so we have an ID to update later? No, we can just save the whole thing at end.
    // BUT to keep it simple and consistent:
    // Let's create the Person entry in the local object, then immediately navigate to OrderScreen.

    // --- DIRECT NAVIGATION TO ORDER SCREEN ---
    // We pass the (empty) person to the order screen so we can add items immediately.
    _openPersonOrder(context, order, pId, newPerson, isNewPerson: true);
  }

  void _openPersonOrder(BuildContext context, OrderModel order, String personId, PersonOrder person, {bool isNewPerson = false}) async {
    // Adapter Logic: Convert Person Items -> Legacy Maps
    Map<String, int> initialTacos = {};
    Map<String, int> initialExtras = {};
    Map<String, Map<String, int>> initialSodas = {};

    for (var item in person.items) {
      if (widget.availableFlavors.containsKey(item.name)) {
        initialTacos[item.name] = item.quantity;
      } else if (item.extras['temp'] != null) {
        if (!initialSodas.containsKey(item.name)) {
          initialSodas[item.name] = {'Frío': 0, 'Al Tiempo': 0};
        }
        String temp = item.extras['temp'];
        initialSodas[item.name]![temp] = item.quantity;
      } else {
        initialExtras[item.name] = item.quantity;
      }
    }

    OrderModel tempOrder = OrderModel(
      id: null,
      tableNumber: widget.tableNumber,
      orderNumber: 0,
      totalItems: 0,
      timestamp: DateTime.now(),
      customerName: person.name,
      tacoCounts: initialTacos,
      sodaCounts: initialSodas,
      simpleExtraCounts: initialExtras,
      tacoServed: {}, sodaServed: {}, simpleExtraServed: {},
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderScreen(
          orderType: person.name,
          tableNumber: widget.tableNumber,
          orderNumber: order.orderNumber,
          availableFlavors: widget.availableFlavors,
          availableExtras: widget.availableExtras,
          existingOrder: tempOrder,
        ),
      ),
    );

    // If user saved changes (or if it's a new person, even empty might need saving to establish them)
    if (result != null && result is OrderModel) {
      // Convert back to Person Items
      List<OrderItem> newItems = [];
      result.tacoCounts.forEach((name, qty) => newItems.add(OrderItem(name: name, quantity: qty)));
      result.simpleExtraCounts.forEach((name, qty) => newItems.add(OrderItem(name: name, quantity: qty)));
      result.sodaCounts.forEach((name, temps) {
        temps.forEach((temp, qty) {
          if (qty > 0) newItems.add(OrderItem(name: name, quantity: qty, extras: {'temp': temp}));
        });
      });

      PersonOrder updatedPerson = PersonOrder(name: person.name, items: newItems);
      Map<String, PersonOrder> updatedPeople = Map.from(order.people);
      updatedPeople[personId] = updatedPerson;

      OrderModel finalOrder = OrderModel(
        id: order.id, // Will be null if new table
        tableNumber: order.tableNumber,
        orderNumber: order.orderNumber,
        totalItems: 0, // Recalculate logic needed if using legacy field
        timestamp: order.timestamp,
        people: updatedPeople,
        tacoCounts: order.tacoCounts, sodaCounts: order.sodaCounts, simpleExtraCounts: order.simpleExtraCounts,
        tacoServed: order.tacoServed, sodaServed: order.sodaServed, simpleExtraServed: order.simpleExtraServed,
      );

      if (order.id == null) {
        await _firestoreService.addOrder(finalOrder);
      } else {
        await _firestoreService.updateOrder(finalOrder);
      }
    } else if (isNewPerson) {
      // User cancelled adding items for a NEW person.
      // Do we save the empty person? Usually yes, to show they are seated.

      // Update/Create order with empty person
      Map<String, PersonOrder> updatedPeople = Map.from(order.people);
      updatedPeople[personId] = person; // Empty items

      OrderModel finalOrder = OrderModel(
        id: order.id,
        tableNumber: order.tableNumber,
        orderNumber: order.orderNumber,
        totalItems: 0,
        timestamp: order.timestamp,
        people: updatedPeople,
        tacoCounts: order.tacoCounts, sodaCounts: order.sodaCounts, simpleExtraCounts: order.simpleExtraCounts,
        tacoServed: order.tacoServed, sodaServed: order.sodaServed, simpleExtraServed: order.simpleExtraServed,
      );

      if (order.id == null) {
        await _firestoreService.addOrder(finalOrder);
      } else {
        await _firestoreService.updateOrder(finalOrder);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new, color: kAccentColor),
        ),
        title: Text("Mesa ${widget.tableNumber}", style: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _firestoreService.getOrdersForTable(widget.tableNumber),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kAccentColor));

          final orders = snapshot.data!;
          final activeOrder = orders.isNotEmpty ? orders.first : null;
          final double grandTotal = activeOrder != null ? _calculateGrandTotal(activeOrder) : 0.0;

          return Column(
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("Total: \$${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kAccentColor)),
                  ],
                ),
              ),

              // People List
              Expanded(
                child: (activeOrder == null || activeOrder.people.isEmpty)
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.table_restaurant, size: 60, color: kShadowColor),
                      const SizedBox(height: 20),
                      const Text("Mesa Disponible", style: TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text("Agrega una persona para comenzar", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    ...activeOrder.people.entries.map((entry) {
                      return _buildPersonCard(activeOrder, entry.key, entry.value);
                    }),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Get current state from stream snapshot logic (or better, refetch single fresh)
          // For simplicity, we assume we check if we have an active order ID
          final orders = await _firestoreService.getOrdersForTable(widget.tableNumber).first;
          _addPersonAndOrder(orders.isNotEmpty ? orders.first : null);
        },
        backgroundColor: kAccentColor,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Agregar Persona", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPersonCard(OrderModel order, String pId, PersonOrder person) {
    double total = _calculatePersonTotal(person);
    int itemCount = person.items.fold(0, (sum, item) => sum + item.quantity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: () => _openPersonOrder(context, order, pId, person),
        child: NeumorphicContainer(
          borderRadius: 15,
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: kTextColor),
                      const SizedBox(width: 8),
                      Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextColor)),
                    ],
                  ),
                  Text("\$${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
                ],
              ),
              if (itemCount > 0) ...[
                const Divider(height: 15),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: person.items.map((item) {
                      return Chip(
                        label: Text("${item.quantity} ${item.name}", style: const TextStyle(fontSize: 11)),
                        backgroundColor: kBackgroundColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                )
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text("Tocá para ordenar", style: TextStyle(color: Colors.grey, fontSize: 12)),
                )
            ],
          ),
        ),
      ),
    );
  }
}