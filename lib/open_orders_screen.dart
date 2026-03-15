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
  bool _isPendingUndo = false;

  void _toggleUndoMode() {
    setState(() {
      _isPendingUndo = !_isPendingUndo;
    });
    if (_isPendingUndo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Toca un item servido para deshacerlo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
                        ...pendingOrders.map((order) => _OrderKitchenCard(
                          order: order, 
                          isPendingUndo: _isPendingUndo, 
                          onUndoToggledOff: () => setState(() => _isPendingUndo = false),
                          key: ValueKey(order.id)
                        )),
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
                        ...completedOrders.map((order) => _OrderKitchenCard(
                          order: order, 
                          isPendingUndo: _isPendingUndo, 
                          onUndoToggledOff: () => setState(() => _isPendingUndo = false),
                          key: ValueKey(order.id), 
                          isInitiallyExpanded: false
                        )),
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
            'Cocina',
            style: TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          IconButton(
            onPressed: _toggleUndoMode,
            icon: Icon(Icons.undo, color: _isPendingUndo ? Colors.orange : Colors.grey.withOpacity(0.5)),
            tooltip: 'Deshacer último servicio',
            style: IconButton.styleFrom(
              backgroundColor: _isPendingUndo ? Colors.orange.withOpacity(0.2) : Colors.transparent,
            ),
          )
        ],
      ),
    );
  }
}

// --- NEW WIDGET: Gift Dialog ---
class _GiftItemDialog extends StatefulWidget {
  final OrderModel order;
  const _GiftItemDialog({required this.order, super.key});

  @override
  State<_GiftItemDialog> createState() => _GiftItemDialogState();
}

class _GiftItemDialogState extends State<_GiftItemDialog> {
  final FirestoreService _service = FirestoreService();
  String? _selectedPersonId;
  String? _selectedItemName;
  int _quantity = 1;
  List<String> _inventoryItemNames = [];

  @override
  void initState() {
    super.initState();
    // Default to first person if available
    if (widget.order.people.isNotEmpty) {
      _selectedPersonId = widget.order.people.keys.first;
    }
    _loadInventory();
  }

  void _loadInventory() async {
    final items = await _service.getInventoryStream().first;
    if (mounted) {
      setState(() {
        // filter active items
        _inventoryItemNames = items.where((i) => i.isActive).map((i) => i.name).toList();
        _inventoryItemNames.sort();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.order.people.isEmpty) {
      return const AlertDialog(
        backgroundColor: kBackgroundColor,
        content: Text("No se pueden agregar regalos a este formato de orden.", style: TextStyle(color: kTextColor)),
      );
    }

    return AlertDialog(
      backgroundColor: kBackgroundColor,
      title: Row(
        children: const [
          Icon(Icons.card_giftcard, color: Colors.purple),
          SizedBox(width: 10),
          Text("Agregar Regalo", style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Selecciona a quién se le regalará:", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          NeumorphicContainer(
            isInner: true,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPersonId,
                isExpanded: true,
                dropdownColor: kBackgroundColor,
                items: widget.order.people.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value.name, style: const TextStyle(color: kTextColor)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedPersonId = val),
              ),
            ),
          ),
          
          const SizedBox(height: 15),
          
          const Text("Artículo a regalar:", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          NeumorphicContainer(
            isInner: true,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedItemName,
                hint: const Text("Selecciona un artículo", style: TextStyle(color: Colors.grey)),
                isExpanded: true,
                dropdownColor: kBackgroundColor,
                items: _inventoryItemNames.map((name) {
                  return DropdownMenuItem(
                    value: name,
                    child: Text(name, style: const TextStyle(color: kTextColor)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedItemName = val),
              ),
            ),
          ),

          const SizedBox(height: 15),

          const Text("Cantidad:", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove_circle_outline, color: kAccentColor),
              ),
              Text("$_quantity", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextColor)),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline, color: kAccentColor),
              ),
            ],
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          onPressed: (_selectedPersonId == null || _selectedItemName == null) ? null : () async {
            final orderItem = OrderItem(
              name: _selectedItemName!,
              quantity: _quantity,
            );
            
            await _service.addGiftItemToOrder(
              orderId: widget.order.id!,
              personId: _selectedPersonId!,
              giftItem: orderItem,
            );
            
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Regalo agregado a ${widget.order.people[_selectedPersonId!]?.name}"),
                  backgroundColor: Colors.purple,
                )
              );
            }
          },
          child: const Text("Dar Regalo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}

class _OrderKitchenCard extends StatefulWidget {
  final OrderModel order;
  final bool isInitiallyExpanded;
  final bool isPendingUndo;
  final VoidCallback onUndoToggledOff;
  
  const _OrderKitchenCard({
    required this.order, 
    this.isInitiallyExpanded = true,
    this.isPendingUndo = false,
    required this.onUndoToggledOff,
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

    // Custom Sort Logic: Tacos > Extras > Drinks
    int _getItemPriority(String name) {
      // 1. Tacos (Explicit list or default check)
      const tacos = ['Chicharron', 'Frijol con Chorizo', 'Papa', 'Carnitas en Morita', 'Huevo en Pasilla', 'Tinga', 'Adobo'];
      if (tacos.any((t) => name.startsWith(t))) return 1;

      // 3. Drinks (Explicit list)
      const drinks = ['Coca', 'Café', 'Té', 'Agua', 'Boing', 'Cafe'];
      if (drinks.any((d) => name.startsWith(d))) return 3;

      // 2. Extras/Others (Arroz, etc)
      return 2;
    }

    Color _getItemColor(String name) {
        int priority = _getItemPriority(name);
        if (priority == 1) return kTextColor; // Tacos -> Black/Dark
        return Colors.purple[800]!; // Others -> Purple (Contrast)
    }

    List<String> sortedItems = allItemNames.toList()
      ..sort((a, b) {
        int priorityA = _getItemPriority(a);
        int priorityB = _getItemPriority(b);
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);
        return a.compareTo(b); // Alphabetical within same priority
      });
    
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
                child: Column(
                  children: [
                    Row(
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
                            // Collarse Icon
                            Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: kAccentColor),
                            const SizedBox(width: 15),
                            // Gift Icon
                            if (widget.order.people.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => _GiftItemDialog(order: widget.order),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.card_giftcard, color: Colors.purple, size: 20),
                                ),
                              ),
                          ],
                        )
                      ],
                    ),
                    // --- SALSAS DISPLAY ---
                    if (widget.order.salsas.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.hot_tub, size: 14, color: Colors.orange), // Salsa Icon
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                "Salsas: ${widget.order.salsas.join(', ')}",
                                style: const TextStyle(color: kTextColor, fontSize: 14, fontStyle: FontStyle.italic),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        DataCell(Text(displayLabel, style: TextStyle(
                            fontWeight: FontWeight.w600, 
                            fontSize: 13,
                            color: _getItemColor(itemKey) // APPLY COLOR
                        ))),

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

                          // EXCEPTION: Desechables are auto-served / ignored in UI
                          bool isDesechable = foundItem.name == 'Desechables';
                          
                          if (isDesechable) {
                              return const DataCell(Center(child: Text("1", style: TextStyle(color: Colors.grey, fontSize: 12))));
                          }

                          // Render cell based on state
                          bool isUndoMode = widget.isPendingUndo && served > 0; // Only highlight items that CAN be undone
                          
                          Color borderColor;
                          Color bgColor;
                          Color textColor;
                          VoidCallback? onTapAction;

                          if (isUndoMode) {
                              // UNDO MODE
                              borderColor = Colors.orange;
                              bgColor = Colors.orange.withOpacity(0.1);
                              textColor = Colors.orange;
                              onTapAction = () async {
                                  await _undoItem(context, pId, itemIndex, foundItem!.name);
                              };
                          } else {
                              // NORMAL MODE
                              borderColor = isItemDone ? Colors.green.withOpacity(0.3) : kAccentColor;
                              bgColor = isItemDone ? Colors.green.withOpacity(0.1) : kAccentColor.withOpacity(0.1);
                              textColor = isItemDone ? Colors.green : kAccentColor;
                              onTapAction = isItemDone ? null : () => _serveItem(pId, itemIndex, foundItem!.name);
                          }

                          return DataCell(
                            Center(
                              child: InkWell(
                                onTap: onTapAction,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor, width: 1)
                                  ),
                                  child: Text(
                                    displayText,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
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
    await FirestoreService().serveItemAndDeductStock(
      orderId: widget.order.id!,
      personId: personId,
      itemIndex: itemIndex,
      itemName: itemName,
    );
  }

  Future<void> _undoItem(BuildContext context, String personId, int itemIndex, String itemName) async {
    // Show confirmation dialog before undoing
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: const [
            Icon(Icons.undo, color: Colors.orange),
            SizedBox(width: 10),
            Text("¿Deshacer acción?", style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("¿Deseas descontar 1 unidad servida de:\n$itemName?", style: const TextStyle(color: kTextColor, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Deshacer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.heavyImpact();
      await FirestoreService().undoServeItemAndReturnStock(
        orderId: widget.order.id!,
        personId: personId,
        itemIndex: itemIndex,
        itemName: itemName,
      );
      // Automatically turn off undo mode after one successful undo
      widget.onUndoToggledOff();
    }
  }
}