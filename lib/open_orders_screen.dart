import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Required for Timer
import 'shared_styles.dart';
import 'models/order_model.dart';
import 'services/firestore_service.dart';
import 'checkout_screen.dart';

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
                    return const Center(child: CircularProgressIndicator(color: kAccentColor));
                  }

                  final allOrders = List<OrderModel>.from(snapshot.data ?? []);

                  // FIFO RULE
                  allOrders.sort((a, b) => a.timestamp.compareTo(b.timestamp));

                  if (allOrders.isEmpty) {
                    return const Center(child: Text("No hay órdenes activas"));
                  }

                  final pendingOrders = allOrders.where((o) => !o.isFullyServed).toList();
                  final completedOrders = allOrders.where((o) => o.isFullyServed).toList();

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // --- PENDING ORDERS ---
                      if (pendingOrders.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10, left: 5),
                          child: Text("PENDIENTES", style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        ...pendingOrders.map((order) => _OrderKitchenCard(order: order, key: ValueKey(order.id))),
                      ] else if (completedOrders.isNotEmpty) 
                         const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Todo al día", style: TextStyle(color: Colors.grey)))),

                      // --- COMPLETED ORDERS ---
                      if (completedOrders.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey.withOpacity(0.3)),
                        const Padding(
                          padding: EdgeInsets.only(top: 10, bottom: 10, left: 5),
                          child: Text("COMPLETADOS / SURTIDOS", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        ...completedOrders.map((order) => _OrderKitchenCard(order: order, key: ValueKey(order.id), isInitiallyExpanded: false)),
                        const SizedBox(height: 40),
                      ],
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
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const NeumorphicContainer(
              isCircle: true,
              padding: EdgeInsets.all(12),
              child: Icon(Icons.arrow_back_ios_new, color: kAccentColor, size: 20),
            ),
          ),
          const Text(
            'open_orders_screen.dart',
            style: TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _OrderKitchenCard extends StatefulWidget {
  final OrderModel order;
  final bool isInitiallyExpanded;
  
  const _OrderKitchenCard({
    required this.order, 
    this.isInitiallyExpanded = true,
    super.key
  });

  @override
  State<_OrderKitchenCard> createState() => _OrderKitchenCardState();
}

class _OrderKitchenCardState extends State<_OrderKitchenCard> {
  Timer? _timer;
  String _timeElapsed = '';
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
    _updateTimeElapsed();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateTimeElapsed());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimeElapsed() {
    if (mounted) {
      final duration = DateTime.now().difference(widget.order.timestamp);
      setState(() {
        _timeElapsed = duration.inMinutes == 0 ? 'Ahora' : '${duration.inMinutes} min';
      });
    }
  }

  // --- HELPER: Short Name Mapping ---
  String _getShortName(String fullName) {
    String name = fullName;
    String suffix = "";

    if (fullName.contains(" (Frío)")) {
      name = fullName.replaceAll(" (Frío)", "");
      suffix = "(f)";
    } else if (fullName.contains(" (Al Tiempo)")) {
      name = fullName.replaceAll(" (Al Tiempo)", "");
      suffix = "(t)";
    }

    switch (name) {
      case 'Papa': return 'Papa$suffix';
      case 'Frijol con Chorizo': return 'Frijol$suffix';
      case 'Chicharron': return 'Chi$suffix';
      case 'Carnitas en Morita': return 'Carn$suffix';
      case 'Huevo en Pasilla': return 'HP$suffix';
      case 'Tinga': return 'Tinga$suffix';
      case 'Adobo': return 'Adobo$suffix';
      case 'Coca': case 'Coca Cola': return 'Coca$suffix';
      case 'Café de Olla': return 'Café$suffix';
      case 'Arroz con leche': return 'Arroz$suffix';
      case 'Té': return 'Té$suffix';
      case 'Cafe Soluble': return 'Solu$suffix';
      case 'Agua Embotellada': case 'Agua Natural': return 'Agua$suffix';
      case 'Boing de Mango': return 'Mango$suffix';
      case 'Boing de Guayaba': return 'Guaya$suffix';
      default:
        return name.length > 8 ? "${name.substring(0, 6)}..$suffix" : name + suffix;
    }
  }

  // --- HELPER: Short Person Name ---
  String _getShortPersonName(String label) {
    if (label.startsWith("Persona ")) {
      return label.replaceFirst("Persona ", "P");
    }
    return label.length > 6 ? "${label.substring(0, 5)}." : label;
  }

  @override
  Widget build(BuildContext context) {
    String headerTitle = widget.order.tableNumber == 0
        ? (widget.order.customerName ?? "Para Llevar")
        : "MESA ${widget.order.tableNumber}";

    // --- PREPARE DATA FOR MATRIX ---
    Set<String> allItemNames = {};
    widget.order.people.forEach((_, person) {
      for (var item in person.items) {
        String key = item.name;
        if (item.extras['temp'] != null) key += " (${item.extras['temp']})";
        allItemNames.add(key);
      }
    });
    List<String> sortedItems = allItemNames.toList()..sort();
    List<String> sortedPersonIds = widget.order.people.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // --- HEADER ---
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                    color: kBackgroundColor,
                    borderRadius: BorderRadius.circular(15), // Rounded all if collapsed
                    // Only display bottom border if expanded
                    border: _isExpanded ? Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.order.tableNumber == 0 ? Icons.shopping_bag : Icons.table_restaurant,
                          color: kAccentColor,
                        ),
                        const SizedBox(width: 10),
                        Text(headerTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextColor)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(_timeElapsed, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        const SizedBox(width: 15),
                        // Collapse Icon
                        Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: kAccentColor),
                      ],
                    )
                  ],
                ),
              ),
            ),

            // --- MATRIX VIEW (Collapsible) ---
            if (_isExpanded)
              if (sortedItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Sin items", style: TextStyle(color: Colors.grey)),
                )
              else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 15,
                  headingRowHeight: 40,
                  dataRowMinHeight: 45,
                  dataRowMaxHeight: 55,
                  columns: [
                    const DataColumn(label: Text('PROD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                    ...sortedPersonIds.map((pId) {
                      String fullName = widget.order.people[pId]?.name ?? pId;
                      String label = _getShortPersonName(fullName);
                      return DataColumn(label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor)));
                    }),
                  ],
                  rows: sortedItems.map((itemKey) {
                    String displayLabel = _getShortName(itemKey);

                    return DataRow(
                      cells: [
                        DataCell(Text(displayLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),

                        ...sortedPersonIds.map((pId) {
                          final person = widget.order.people[pId];
                          if (person == null) return const DataCell(Text("-"));

                          int itemIndex = -1;
                          OrderItem? foundItem;

                          for (int i = 0; i < person.items.length; i++) {
                            String key = person.items[i].name;
                            if (person.items[i].extras['temp'] != null) key += " (${person.items[i].extras['temp']})";

                            if (key == itemKey) {
                              itemIndex = i;
                              foundItem = person.items[i];
                              break;
                            }
                          }

                          if (foundItem == null) {
                            return const DataCell(Center(child: Text("-", style: TextStyle(color: Colors.grey))));
                          }

                          // Logic: Show PENDING (Remaining)
                          int served = foundItem.extras['served'] ?? 0;
                          int pending = foundItem.quantity - served;
                          
                          // If the WHOLE order is fully served (Completed Section), show the Total Served.
                          // If the order is still Active (Pending Section), show only Pending (or '-' if this item is done).
                          bool isOrderComplete = widget.order.isFullyServed;
                          
                          String displayText;
                          if (isOrderComplete) {
                            displayText = "${foundItem.quantity}"; // Show Total
                          } else {
                            displayText = pending > 0 ? "$pending" : "-"; // Show Pending or Dash
                          }
                          
                          bool isItemDone = pending <= 0;

                          return DataCell(
                            Center(
                              child: InkWell(
                                onTap: isItemDone ? null : () => _serveItem(pId, itemIndex, foundItem!.name),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: isItemDone ? Colors.green.withOpacity(0.1) : kAccentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: isItemDone ? Colors.green.withOpacity(0.3) : kAccentColor,
                                          width: 1
                                      )
                                  ),
                                  child: Text(
                                    displayText,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isItemDone ? Colors.green : kAccentColor
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                      ],
                    );
                  }).toList(),
                ),
              ),


          ],
        ),
      ),
    );
  }

  Future<void> _serveItem(String personId, int itemIndex, String itemName) async {
    HapticFeedback.lightImpact();
    // Calls the updated service which now serves the FULL remaining quantity
    await FirestoreService().serveItemAndDeductStock(
      orderId: widget.order.id!,
      personId: personId,
      itemIndex: itemIndex,
      itemName: itemName,
    );
  }
}