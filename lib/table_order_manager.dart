import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shared_styles.dart';
import 'order_screen.dart';
import 'models/order_model.dart';
import 'models/inventory_model.dart';
import 'services/firestore_service.dart';
import 'checkout_screen.dart';

class TableOrderManagerScreen extends StatefulWidget {
  final int tableNumber;
  final String? orderId; // New: For To Go orders (specific ID)
  final Map<String, bool> availableFlavors;
  final Map<String, bool> availableExtras;

  const TableOrderManagerScreen({
    super.key,
    required this.tableNumber,
    this.orderId,
    required this.availableFlavors,
    required this.availableExtras,
  });

  @override
  State<TableOrderManagerScreen> createState() => _TableOrderManagerScreenState();
}

class _TableOrderManagerScreenState extends State<TableOrderManagerScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, double> _priceMap = {};
  final TextEditingController _customerNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
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

  Stream<List<OrderModel>> _getOrdersStream() {
    if (widget.orderId != null) {
      return _firestoreService.getOrderStream(widget.orderId!).map((order) => [order]);
    }
    return _firestoreService.getOrdersForTable(widget.tableNumber);
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
    // 1. If no order exists, create it locally first
    // Note: For To Go (with ID), existingOrder should NOT be null if the ID is valid.
    OrderModel order = existingOrder ?? OrderModel(
      id: widget.orderId, // Use passed ID if available
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
    // We don't save yet, we go to OrderScreen.
    
    // --- DIRECT NAVIGATION TO ORDER SCREEN ---
    _openPersonOrder(context, order, pId, newPerson, isNewPerson: true);
  }

  void _openPersonOrder(BuildContext context, OrderModel order, String personId, PersonOrder person, {bool isNewPerson = false}) async {
    // Adapter Logic: Convert Person Items -> Legacy Maps
    Map<String, int> initialTacos = {};
    Map<String, int> initialExtras = {};
    Map<String, Map<String, int>> initialSodas = {};

    Map<String, int> initialTacoServed = {};
    Map<String, int> initialExtraServed = {};
    Map<String, Map<String, int>> initialSodaServed = {};

    for (var item in person.items) {
      int servedCount = item.extras['served'] ?? 0;

      if (widget.availableFlavors.containsKey(item.name)) {
        initialTacos[item.name] = item.quantity;
        initialTacoServed[item.name] = servedCount;
      } else if (item.extras['temp'] != null) {
        if (!initialSodas.containsKey(item.name)) {
          initialSodas[item.name] = {'Frío': 0, 'Al Tiempo': 0};
          initialSodaServed[item.name] = {'Frío': 0, 'Al Tiempo': 0};
        }
        String temp = item.extras['temp'];
        initialSodas[item.name]![temp] = item.quantity;
        // Served count for sodas needs to be mapped to temp
        // Assuming 'served' in extras is total for this specific item line (which is specific to temp)
        initialSodaServed[item.name]![temp] = servedCount;
      } else {
        initialExtras[item.name] = item.quantity;
        initialExtraServed[item.name] = servedCount;
      }
    }

    OrderModel tempOrder = OrderModel(
      id: null,
      tableNumber: widget.tableNumber,
      orderNumber: 0,
      totalItems: 0,
      timestamp: DateTime.now(),
      customerName: person.name,
      salsas: order.salsas,
      tacoCounts: initialTacos,
      sodaCounts: initialSodas,
      simpleExtraCounts: initialExtras,
      tacoServed: initialTacoServed,
      sodaServed: initialSodaServed,
      simpleExtraServed: initialExtraServed,
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

      // FIX: Read from the new 'people' structure returned by OrderScreen
      if (result.people.isNotEmpty) {
        newItems = List.from(result.people.values.first.items);
      } else {
        // Fallback
        result.tacoCounts.forEach((name, qty) {
          int served = result.tacoServed[name] ?? 0;
          newItems.add(OrderItem(name: name, quantity: qty, extras: {'served': served}));
        });
        
        result.simpleExtraCounts.forEach((name, qty) {
          int served = result.simpleExtraServed[name] ?? 0;
          newItems.add(OrderItem(name: name, quantity: qty, extras: {'served': served}));
        });

        result.sodaCounts.forEach((name, temps) {
          temps.forEach((temp, qty) {
            if (qty > 0) {
              int served = result.sodaServed[name]?[temp] ?? 0;
              newItems.add(OrderItem(name: name, quantity: qty, extras: {'temp': temp, 'served': served}));
            }
          });
        });
      }

      PersonOrder updatedPerson = PersonOrder(name: person.name, items: newItems); // Use original name if not edited in OrderScreen? OrderScreen returns customerName as name.
      // Actually OrderScreen returns 'customerName' as the person name text field value.
      if (result.customerName != null && result.customerName!.isNotEmpty) {
          updatedPerson = PersonOrder(name: result.customerName!, items: newItems);
      }

      Map<String, PersonOrder> updatedPeople = Map.from(order.people);
      updatedPeople[personId] = updatedPerson;
      
      // Calculate total items for top level field (useful for summaries)
      int totalItems = 0;
      updatedPeople.forEach((_, p) {
          for(var i in p.items) totalItems += i.quantity;
      });

      OrderModel finalOrder = OrderModel(
        id: order.id, 
        tableNumber: order.tableNumber,
        orderNumber: order.orderNumber,
        totalItems: totalItems, 
        timestamp: order.timestamp,
        customerName: order.customerName, // Keep main order customer Name (for To Go)
        salsas: result.salsas,
        people: updatedPeople,
        tacoCounts: {}, sodaCounts: {}, simpleExtraCounts: {}, // Consolidated into people
        tacoServed: {}, sodaServed: {}, simpleExtraServed: {},
      );
      
      // For To Go, we might want to update the main Customer Name if it's the first person? 
      // Or provide a separate edit for the main order name. 
      // Let's stick to the current plan: TableOrderManager handles "People".

      if (order.id == null) {
        await _firestoreService.addOrder(finalOrder);
      } else {
        await _firestoreService.updateOrder(finalOrder);
      }
    } else if (isNewPerson) {
      // User cancelled adding items for a NEW person.
      // Update/Create order with empty person (to show them seated/added)
      Map<String, PersonOrder> updatedPeople = Map.from(order.people);
      updatedPeople[personId] = person; // Empty items

      OrderModel finalOrder = OrderModel(
        id: order.id,
        tableNumber: order.tableNumber,
        orderNumber: order.orderNumber,
        totalItems: order.totalItems,
        timestamp: order.timestamp,
        customerName: order.customerName,
        people: updatedPeople,
        tacoCounts: {}, sodaCounts: {}, simpleExtraCounts: {},
        tacoServed: {}, sodaServed: {}, simpleExtraServed: {},
      );

      if (order.id == null) {
        await _firestoreService.addOrder(finalOrder);
      } else {
        await _firestoreService.updateOrder(finalOrder);
      }
    }
  }

  bool _hasDesechables = true; // Default

  Future<void> _toggleDesechables(OrderModel order, bool value) async {
      HapticFeedback.mediumImpact();
      Map<String, PersonOrder> updatedPeople = Map.from(order.people);
      
      updatedPeople.forEach((pId, person) {
          List<OrderItem> items = List.from(person.items);
          if (value) {
              // Add if missing
              if (!items.any((i) => i.name == 'Desechables')) {
                  items.add(OrderItem(name: 'Desechables', quantity: 1, extras: {}));
              }
          } else {
              // Remove
              items.removeWhere((i) => i.name == 'Desechables');
          }
          updatedPeople[pId] = PersonOrder(name: person.name, items: items);
      });

      // Recalculate Total
      int totalItems = 0;
      updatedPeople.forEach((_, p) {
          for(var i in p.items) totalItems += i.quantity;
      });

      OrderModel finalOrder = OrderModel(
        id: order.id, 
        tableNumber: order.tableNumber,
        orderNumber: order.orderNumber,
        totalItems: totalItems, 
        timestamp: order.timestamp,
        customerName: order.customerName,
        salsas: order.salsas,
        people: updatedPeople,
        tacoCounts: {}, sodaCounts: {}, simpleExtraCounts: {},
        tacoServed: {}, sodaServed: {}, simpleExtraServed: {},
      );

      if (order.id != null) {
        await _firestoreService.updateOrder(finalOrder);
      }
      
      setState(() {
          _hasDesechables = value;
      });
  }

  void _editMainOrderName(OrderModel order) {
      _customerNameController.text = order.customerName ?? "";
      showDialog(
        context: context, 
        builder: (context) => AlertDialog(
            title: const Text("Nombre del Cliente"),
            content: TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(hintText: "Ej. Juan Perez"),
                textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text("Cancelar")
                ),
                TextButton(
                    onPressed: () {
                         final newName = _customerNameController.text.trim();
                         if (newName.isNotEmpty) {
                             final updatedOrder = OrderModel(
                                 id: order.id,
                                 tableNumber: order.tableNumber,
                                 orderNumber: order.orderNumber,
                                 totalItems: order.totalItems,
                                 timestamp: order.timestamp,
                                 customerName: newName,
                                 people: order.people,
                                 tacoCounts: order.tacoCounts, sodaCounts: order.sodaCounts, simpleExtraCounts: order.simpleExtraCounts,
                                 tacoServed: order.tacoServed, sodaServed: order.sodaServed, simpleExtraServed: order.simpleExtraServed,
                             );
                             _firestoreService.updateOrder(updatedOrder);
                         }
                         Navigator.pop(context);
                    }, 
                    child: const Text("Guardar")
                ),
            ],
        )
      );
  }

  @override
  Widget build(BuildContext context) {
    bool isToGo = widget.tableNumber == 0;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new, color: kAccentColor),
        ),
        // Title logic handled in StreamBuilder to get name
        title: null, 
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _getOrdersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kAccentColor));

          final orders = snapshot.data!;
          final activeOrder = orders.isNotEmpty ? orders.first : null;
          final double grandTotal = activeOrder != null ? _calculateGrandTotal(activeOrder) : 0.0;
          
          if (activeOrder != null) {
               bool dbHasDesechables = false;
               if (activeOrder.people.isNotEmpty) {
                   dbHasDesechables = activeOrder.people.values.any((p) => p.items.any((i) => i.name == 'Desechables'));
               } else {
                   dbHasDesechables = true; 
               }
               // Sync local state if it differs (simple approach for this widget lifecycle)
               if (_hasDesechables != dbHasDesechables) {
                   // Avoid setState during build, but we need to reflect the DB state.
                   // Since this is a stateless recalc for display, assign directly.
                   _hasDesechables = dbHasDesechables;
               }
          }

          // AppBar Title Logic
          String title = "Mesa ${widget.tableNumber}";
          if (isToGo) {
              title = activeOrder?.customerName ?? "Para Llevar";
              if (title.isEmpty) title = "Orden #${activeOrder?.orderNumber ?? '?'}";
          }

          // We need to set the title in the AppBar, but we are inside body. 
          // We can use a Column with a custom header or just rely on the Scaffold AppBar.
          // Since Scaffold is parent, we can't easily update it from here without state lifting or hacks.
          // Better approach: Hide AppBar title and render it in the body top, OR just use a static title "Pedido" and put details below.
          // Let's use a Custom Header column instead of AppBar title for dynamic updates.
          
          return Column(
            children: [
                // Custom Header Area (replaces AppBar title visual)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    child: Column(
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Text(title, style: const TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
                                if (isToGo && activeOrder != null) 
                                    IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                                        onPressed: () => _editMainOrderName(activeOrder),
                                    )
                            ],
                        ),
                        if (isToGo && activeOrder != null)
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    const Text("Cobrar Desechables", style: TextStyle(fontSize: 14, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                    Switch(
                                        value: _hasDesechables, 
                                        activeColor: kAccentColor,
                                        onChanged: (val) => _toggleDesechables(activeOrder, val)
                                    )
                                ],
                            )
                      ],
                    ),
                ),
                
              // Summary & Checkout
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: activeOrder != null && activeOrder.people.isNotEmpty 
                          ? () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => CheckoutScreen(order: activeOrder))
                              );
                            }
                          : null,
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text("COBRAR"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
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
                      Icon(isToGo ? Icons.shopping_bag_outlined : Icons.table_restaurant, size: 60, color: kShadowColor),
                      const SizedBox(height: 20),
                      Text(isToGo ? "Orden Vacía" : "Mesa Disponible", style: const TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
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
            // Logic to get the current order to add person to
            final stream = _getOrdersStream();
            final orders = await stream.first;
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