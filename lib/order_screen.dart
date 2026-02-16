import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shared_styles.dart';
import 'models/order_model.dart';
import 'models/inventory_model.dart'; // Required to check item types
import 'services/firestore_service.dart'; // Required to fetch types

class OrderScreen extends StatefulWidget {
  final String orderType;
  final int? tableNumber;
  final int orderNumber;
  final Map<String, bool> availableFlavors;
  final Map<String, bool> availableExtras;
  final OrderModel? existingOrder;

  const OrderScreen({
    super.key,
    required this.orderType,
    this.tableNumber,
    required this.orderNumber,
    required this.availableFlavors,
    required this.availableExtras,
    this.existingOrder,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  late Map<String, int> _tacoCounts;
  late Map<String, int> _simpleExtraCounts;
  late Map<String, Map<String, int>> _sodaCounts;
  final TextEditingController _nameController = TextEditingController();

  int _grandTotal = 0;
  bool _isLoading = true; // To wait for inventory check

  // Dynamic list populated from Firestore
  List<String> _sodaFlavors = [];

  // --- Multiple Salsas ---
  List<String> _selectedSalsas = [];
  final List<String> _salsaOptions = ['Tradicional', 'Cremosa', 'Roja', 'Habanero'];

  @override
  void initState() {
    super.initState();
    _loadInventoryAndSetup();
  }

  Future<void> _loadInventoryAndSetup() async {
    // 1. Fetch Inventory to identify what is a "soda" vs "extra"
    final items = await _firestoreService.getInventoryStream().first;

    // 2. Dynamically build the list of Sodas based on 'type' field in DB
    // CORRECTION: Exclude hot drinks that might be categorized as 'soda' or beverage but don't need temperature
    final hotDrinks = ['Té', 'Café de Olla', 'Café Soluble'];
    
    _sodaFlavors = items
        .where((item) => item.type == 'soda' && !hotDrinks.contains(item.name))
        .map((item) => item.name)
        .toList();

    // 3. Initialize Counts
    _tacoCounts = {};
    widget.availableFlavors.forEach((flavor, isAvailable) {
      if (isAvailable) _tacoCounts[flavor] = 0;
    });

    _simpleExtraCounts = {};
    widget.availableExtras.forEach((extra, isAvailable) {
      // Logic: If available AND not 'Refrescos' placeholder AND NOT in our dynamic soda list
      // This will now include the excluded hotDrinks because they are no longer in _sodaFlavors
      if (isAvailable && extra != 'Refrescos' && !_sodaFlavors.contains(extra)) {
        _simpleExtraCounts[extra] = 0;
      }
    });

    _sodaCounts = {};
    for (var flavor in _sodaFlavors) {
      // Only add if it's actually available/active in the passed extras
      if (widget.availableExtras[flavor] == true) {
        _sodaCounts[flavor] = {'Frío': 0, 'Al Tiempo': 0};
      }
    }

    // 4. Populate existing data (Edit Mode)
    if (widget.existingOrder != null) {
      _nameController.text = widget.existingOrder!.customerName ?? '';
      _selectedSalsas = List.from(widget.existingOrder!.salsas);
      
      // FIX: Do NOT load existing item counts into the UI counters.
      // User requirement: "The waiter view appears in 0 every time a new round starts".
      // We only load Salsas and Name. Item counters remain at 0 (initialized above).
    }

    _calculateTotal();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ... Increment/Decrement methods ...
  void _incrementTaco(String flavor) { setState(() { _tacoCounts[flavor] = (_tacoCounts[flavor] ?? 0) + 1; _calculateTotal(); }); }
  void _decrementTaco(String flavor) { setState(() { if ((_tacoCounts[flavor] ?? 0) > 0) { _tacoCounts[flavor] = _tacoCounts[flavor]! - 1; _calculateTotal(); } }); }
  void _incrementSoda(String flavor, String temp) { setState(() { _sodaCounts[flavor]![temp] = (_sodaCounts[flavor]![temp] ?? 0) + 1; _calculateTotal(); }); }
  void _decrementSoda(String flavor, String temp) { setState(() { if ((_sodaCounts[flavor]![temp] ?? 0) > 0) { _sodaCounts[flavor]![temp] = _sodaCounts[flavor]![temp]! - 1; _calculateTotal(); } }); }
  void _incrementSimpleExtra(String extra) { setState(() { _simpleExtraCounts[extra] = (_simpleExtraCounts[extra] ?? 0) + 1; _calculateTotal(); }); }
  void _decrementSimpleExtra(String extra) { setState(() { if ((_simpleExtraCounts[extra] ?? 0) > 0) { _simpleExtraCounts[extra] = _simpleExtraCounts[extra]! - 1; _calculateTotal(); } }); }

  void _calculateTotal() {
    int total = 0;
    _tacoCounts.forEach((_, count) => total += count);
    _sodaCounts.forEach((_, temps) => total += (temps['Frío']! + temps['Al Tiempo']!));
    _simpleExtraCounts.forEach((_, count) => total += count);
    setState(() {
      _grandTotal = total;
    });
  }

  void _saveOrder() {
    // 1. Get Current "ACTIVE" Counts (New Items only, since we started at 0)
    final currentTacos = Map<String, int>.from(_tacoCounts)..removeWhere((k, v) => v == 0);
    final currentExtras = Map<String, int>.from(_simpleExtraCounts)..removeWhere((k, v) => v == 0);
    final currentSodas = <String, Map<String, int>>{};

    _sodaCounts.forEach((key, value) {
       int total = value['Frío']! + value['Al Tiempo']!;
       if (total > 0) {
          currentSodas[key] = Map<String, int>.from(value);
       }
    });

    // --- CONSTRUCT NEW (DELTA) ITEMS ---
    List<OrderItem> newItems = [];

    // Helper to add items
    void addNewItem(String name, int qty, Map<String, dynamic> extras) {
      if (qty > 0) {
        newItems.add(OrderItem(name: name, quantity: qty, extras: extras));
      }
    }

    // Add Items from UI
    currentTacos.forEach((name, qty) => addNewItem(name, qty, {}));
    currentExtras.forEach((name, qty) => addNewItem(name, qty, {}));
    currentSodas.forEach((name, temps) {
      if (temps['Frío']! > 0) addNewItem(name, temps['Frío']!, {'temp': 'Frío'});
      if (temps['Al Tiempo']! > 0) addNewItem(name, temps['Al Tiempo']!, {'temp': 'Al Tiempo'});
    });

    // 2. MERGE WITH EXISTING ITEMS (Fix for disappearing items)
    // Goal: Final = Existing (Served + Unserved) + New
    List<Map<String, dynamic>> finalItemsMap = [];
    
    // We strictly use the 'people' list from existingOrder if available
    // But since this screen edits ONE person (conceptually), we need to know WHICH person's items to pull?
    // The OrderScreen is passed `existingOrder` which is a TEMP order containing ONLY this person's data in the root fields?
    // Wait, let's check `TableOrderManager`. 
    // It passes `tempOrder` with `customerName: person.name` and legacy maps populated from that person.
    // AND it populates `people`? No, `tempOrder` in `_openPersonOrder` does NOT populate `people` for the temp object passed to `OrderScreen`?
    // Let's check `TableOrderManager` code again.
    // Line 144: `tempOrder` created. `people` is NOT passed (defaults to empty).
    // It DOES pass `tacoCounts`, `tacoServed` etc legacy maps.
    
    // So `widget.existingOrder` in `OrderScreen` has the PREVIOUS items in the LEGACY fields (`tacoServed`, `tacoCounts` etc).
    // The previous `OrderScreen` logic (initState) was loading `tacoCounts` from `widget.existingOrder`.
    // My change removes that load (to start at 0).
    // BUT `widget.existingOrder` still holds the "History".
    
    // RE-VERIFY: `TableOrderManager` passes `initialTacos`, `initialTacoServed` etc.
    // `initialTacos` contains the TOTAL quantity of that person.
    // `initialTacoServed` contains the SERVED quantity.
    
    // Strategy:
    // Iterate `widget.existingOrder` Legacy Maps to build the "Existing Items List".
    // Then Merge `newItems` into "Existing Items List".

    List<OrderItem> existingItems = [];
    
    if (widget.existingOrder != null) {
        // Recover Tacos
        widget.existingOrder!.tacoCounts.forEach((name, qty) {
            int served = widget.existingOrder!.tacoServed[name] ?? 0;
            if (qty > 0) existingItems.add(OrderItem(name: name, quantity: qty, extras: {'served': served}));
        });
        // Recover Extras
        widget.existingOrder!.simpleExtraCounts.forEach((name, qty) {
            int served = widget.existingOrder!.simpleExtraServed[name] ?? 0;
            if (qty > 0) existingItems.add(OrderItem(name: name, quantity: qty, extras: {'served': served}));
        });
        // Recover Sodas
        widget.existingOrder!.sodaCounts.forEach((name, temps) {
            temps.forEach((temp, qty) {
                if (qty > 0) {
                    int served = widget.existingOrder!.sodaServed[name]?[temp] ?? 0;
                    existingItems.add(OrderItem(name: name, quantity: qty, extras: {'temp': temp, 'served': served}));
                }
            });
        });
    }

    // MERGE LISTS
    // We clone existing items to final list map to modify
    finalItemsMap = existingItems.map((e) => e.toMap()).toList();

    for (var newItem in newItems) {
        String newName = newItem.name;
        String? newTemp = newItem.extras['temp'];
        
        // Find match in finalItemsMap
        int index = finalItemsMap.indexWhere((m) {
             return m['name'] == newName && m['extras']['temp'] == newTemp;
        });

        if (index != -1) {
            // Update Quantity
            finalItemsMap[index]['quantity'] += newItem.quantity;
            // 'served' remains whatever it was (new item doesn't add served count)
        } else {
            // Add New Item
            finalItemsMap.add(newItem.toMap());
        }
    }

    // 3. TO GO CHARGE ($2 Desechables)
    bool isToGo = widget.tableNumber == 0 || widget.tableNumber == null;
    if (isToGo) {
        // Check if "Desechables" exists
        bool hasDesechables = finalItemsMap.any((m) => m['name'] == 'Desechables');
        if (!hasDesechables) {
             // Add it (Qty 1, Served 0)
             finalItemsMap.add(OrderItem(name: 'Desechables', quantity: 1, extras: {}).toMap());
        }
    }

    // 4. Validate Total (Must have items OR be existing order? If existing order had items, finalItemsMap will have them)
    if (finalItemsMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La orden no puede estar vacía")));
      return;
    }

    // Convert back to OrderItem
    List<OrderItem> finalPersonItems = finalItemsMap.map((m) => OrderItem.fromMap(m)).toList();

    // Recalculate Total Items
    int grandTotalItems = finalPersonItems.fold(0, (sum, item) => sum + item.quantity);

    // Create Person
    String personName = _nameController.text.isNotEmpty ? _nameController.text : "Cliente";
    PersonOrder p1 = PersonOrder(name: personName, items: finalPersonItems);
    
    Map<String, PersonOrder> peopleMap = {'P1': p1};

    final newOrder = OrderModel(
      id: widget.existingOrder?.id,
      tableNumber: widget.tableNumber ?? 0,
      orderNumber: widget.orderNumber,
      totalItems: grandTotalItems,
      timestamp: widget.existingOrder?.timestamp ?? DateTime.now(),
      customerName: _nameController.text.isEmpty ? null : _nameController.text,
      salsas: _selectedSalsas, 
      
      // Legacy fields - Populate them just in case TableOrderManager uses them for display before refetching?
      // Actually TableOrderManager reconstructs from `peopleMap`, so empty is fine.
      tacoCounts: {}, 
      sodaCounts: {}, 
      simpleExtraCounts: {},
      tacoServed: {}, sodaServed: {}, simpleExtraServed: {},
      
      people: peopleMap,
    );

    Navigator.pop(context, newOrder);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: kAccentColor)),
      );
    }

    final isToGo = widget.tableNumber == 0 || widget.tableNumber == null;

    // Define Hot Drinks (consistent with _loadInventoryAndSetup)
    final hotDrinks = ['Té', 'Café de Olla', 'Café Soluble'];

    // Get list of active sodas to display (filtered dynamically)
    final activeSodas = _sodaCounts.keys.toList();

    // Filter Extras: Separate Hot Drinks from "True" Extras
    final activeHotDrinks = _simpleExtraCounts.keys.where((k) => hotDrinks.contains(k)).toList();
    final activeTrueExtras = _simpleExtraCounts.keys.where((k) => !hotDrinks.contains(k)).toList();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),

            // Always allow name editing
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Nombre del Cliente (Opcional)',
                      border: InputBorder.none,
                      icon: Icon(Icons.person_outline, color: kAccentColor),
                    ),
                    style: const TextStyle(color: kTextColor, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

            if (isToGo)
              _buildSalsaSelector(),

            Expanded(
              child: CustomScrollView(
                slivers: [
                  // --- TACOS ---
                  if (_tacoCounts.isNotEmpty)
                    SliverToBoxAdapter(child: _buildSectionHeader('Tacos')),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        String flavor = _tacoCounts.keys.elementAt(index);
                        return _buildTacoOrderItem(
                          flavor: flavor,
                          count: _tacoCounts[flavor] ?? 0,
                          onDecrement: () => _decrementTaco(flavor),
                          onIncrement: () => _incrementTaco(flavor),
                        );
                      },
                      childCount: _tacoCounts.length,
                    ),
                  ),

                  // --- BEVERAGES SECTION (Sodas + Hot Drinks) ---
                  if (activeSodas.isNotEmpty || activeHotDrinks.isNotEmpty) 
                     SliverToBoxAdapter(child: _buildSectionHeader('Bebidas')),

                  // 1. Sodas
                  if (activeSodas.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String flavor = activeSodas[index];
                          return _buildSodaOrderItem(flavor: flavor);
                        },
                        childCount: activeSodas.length,
                      ),
                    ),
                  
                  // 2. Hot Drinks (Simple Counter)
                  if (activeHotDrinks.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String drink = activeHotDrinks[index];
                          return _buildTacoOrderItem( // Reusing simple counter widget
                            flavor: drink,
                            count: _simpleExtraCounts[drink] ?? 0,
                            onDecrement: () => _decrementSimpleExtra(drink),
                            onIncrement: () => _incrementSimpleExtra(drink),
                          );
                        },
                        childCount: activeHotDrinks.length,
                      ),
                    ),

                  // --- EXTRAS SECTION (Filtered) ---
                  if (activeTrueExtras.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _buildSectionHeader('Extras')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String extra = activeTrueExtras[index];
                          return _buildTacoOrderItem(
                            flavor: extra,
                            count: _simpleExtraCounts[extra] ?? 0,
                            onDecrement: () => _decrementSimpleExtra(extra),
                            onIncrement: () => _incrementSimpleExtra(extra),
                          );
                        },
                        childCount: activeTrueExtras.length,
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _grandTotal > 0 ? FloatingActionButton.extended(
        onPressed: _saveOrder,
        backgroundColor: kAccentColor,
        icon: const Icon(Icons.check, color: Colors.white),
        label: Text("Guardar ($_grandTotal items)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _buildSalsaSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Salsas (Opcional)"),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
          clipBehavior: Clip.none,
          child: Row(
            children: _salsaOptions.map((salsa) {
              final isSelected = _selectedSalsas.contains(salsa);
              return Padding(
                padding: const EdgeInsets.only(right: 15),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedSalsas.remove(salsa);
                      } else {
                        _selectedSalsas.add(salsa);
                      }
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                        color: isSelected ? kAccentColor : kBackgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(color: kAccentColor.withOpacity(0.4), offset: const Offset(2, 4), blurRadius: 6),
                        ]
                            : [
                          BoxShadow(color: kShadowColor.withOpacity(0.5), offset: const Offset(4, 4), blurRadius: 6),
                          BoxShadow(color: Colors.white, offset: const Offset(-4, -4), blurRadius: 6),
                        ]
                    ),
                    child: Text(
                      salsa,
                      style: TextStyle(
                        color: isSelected ? Colors.white : kTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Text(
        title,
        style: const TextStyle(color: kAccentColor, fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    String title = 'order_screen.dart';
    if (widget.tableNumber != null) {
      title = 'order_screen.dart'; // Override as requested, or maybe append? The user said "pongamos como titulo... el nombre del file". I will set it directly.
    }

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
          Flexible(
            child: Text(
              title,
              style: const TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTacoOrderItem({required String flavor, required int count, required VoidCallback onDecrement, required VoidCallback onIncrement}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(flavor, style: const TextStyle(color: kTextColor, fontSize: 18, fontWeight: FontWeight.w600))),
            Row(children: [
              GestureDetector(onTap: onDecrement, child: const NeumorphicContainer(isCircle: true, padding: EdgeInsets.all(12), child: Icon(Icons.remove, color: kAccentColor, size: 22))),
              Container(width: 60, alignment: Alignment.center, child: Text('$count', style: const TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w700))),
              GestureDetector(onTap: onIncrement, child: const NeumorphicContainer(isCircle: true, padding: EdgeInsets.all(12), child: Icon(Icons.add, color: kAccentColor, size: 22))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSodaOrderItem({required String flavor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(flavor, style: const TextStyle(color: kTextColor, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 15),
            _buildCounterRow(label: 'Frío', count: _sodaCounts[flavor]?['Frío'] ?? 0, onDecrement: () => _decrementSoda(flavor, 'Frío'), onIncrement: () => _incrementSoda(flavor, 'Frío')),
            const SizedBox(height: 10),
            _buildCounterRow(label: 'Al Tiempo', count: _sodaCounts[flavor]?['Al Tiempo'] ?? 0, onDecrement: () => _decrementSoda(flavor, 'Al Tiempo'), onIncrement: () => _incrementSoda(flavor, 'Al Tiempo')),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterRow({required String label, required int count, required VoidCallback onDecrement, required VoidCallback onIncrement}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: kTextColor, fontSize: 17, fontWeight: FontWeight.w500)),
      Row(children: [
        GestureDetector(onTap: onDecrement, child: const NeumorphicContainer(isCircle: true, padding: EdgeInsets.all(10), child: Icon(Icons.remove, color: kAccentColor, size: 20))),
        Container(width: 50, alignment: Alignment.center, child: Text('$count', style: const TextStyle(color: kTextColor, fontSize: 18, fontWeight: FontWeight.w700))),
        GestureDetector(onTap: onIncrement, child: const NeumorphicContainer(isCircle: true, padding: EdgeInsets.all(10), child: Icon(Icons.add, color: kAccentColor, size: 20))),
      ]),
    ]);
  }
}