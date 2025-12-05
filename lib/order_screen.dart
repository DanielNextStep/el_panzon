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
    _sodaFlavors = items
        .where((item) => item.type == 'soda')
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

      widget.existingOrder!.tacoCounts.forEach((flavor, count) {
        if (_tacoCounts.containsKey(flavor)) _tacoCounts[flavor] = count;
      });

      widget.existingOrder!.simpleExtraCounts.forEach((extra, count) {
        if (_simpleExtraCounts.containsKey(extra)) _simpleExtraCounts[extra] = count;
      });

      widget.existingOrder!.sodaCounts.forEach((flavor, temps) {
        // If this legacy order has a soda that is now inactive, we still want to show it ideally,
        // or put it in _sodaCounts if it matches our dynamic list.
        if (_sodaFlavors.contains(flavor)) {
          _sodaCounts.putIfAbsent(flavor, () => {'Frío': 0, 'Al Tiempo': 0});
          _sodaCounts[flavor] = Map<String, int>.from(temps);
        }
      });
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
    final finalTacos = Map<String, int>.from(_tacoCounts)..removeWhere((_, v) => v == 0);
    final finalExtras = Map<String, int>.from(_simpleExtraCounts)..removeWhere((_, v) => v == 0);
    final finalSodas = <String, Map<String, int>>{};

    _sodaCounts.forEach((key, value) {
      int total = value['Frío']! + value['Al Tiempo']!;
      if (total > 0) {
        finalSodas[key] = Map<String, int>.from(value);
      }
    });

    int totalItems = 0;
    finalTacos.values.forEach((v) => totalItems += v);
    finalExtras.values.forEach((v) => totalItems += v);
    finalSodas.values.forEach((v) => totalItems += (v['Frío']! + v['Al Tiempo']!));

    if (totalItems == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La orden no puede estar vacía")));
      return;
    }

    final newOrder = OrderModel(
      id: widget.existingOrder?.id,
      tableNumber: widget.tableNumber ?? 0,
      orderNumber: widget.orderNumber,
      totalItems: totalItems,
      timestamp: widget.existingOrder?.timestamp ?? DateTime.now(),
      customerName: _nameController.text.isEmpty ? null : _nameController.text,
      salsas: _selectedSalsas,

      tacoCounts: finalTacos,
      sodaCounts: finalSodas,
      simpleExtraCounts: finalExtras,
      tacoServed: widget.existingOrder?.tacoServed ?? {},
      sodaServed: widget.existingOrder?.sodaServed ?? {},
      simpleExtraServed: widget.existingOrder?.simpleExtraServed ?? {},
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

    // Get list of active sodas to display (filtered dynamically)
    final activeSodas = _sodaCounts.keys.toList();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),

            if (isToGo)
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

                  // --- SODA SECTION (Active Only) ---
                  if (activeSodas.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _buildSectionHeader('Bebidas')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String flavor = activeSodas[index];
                          return _buildSodaOrderItem(flavor: flavor);
                        },
                        childCount: activeSodas.length,
                      ),
                    ),
                  ],

                  // --- EXTRAS SECTION (Filtered) ---
                  if (_simpleExtraCounts.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _buildSectionHeader('Extras')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String extra = _simpleExtraCounts.keys.elementAt(index);
                          return _buildTacoOrderItem(
                            flavor: extra,
                            count: _simpleExtraCounts[extra] ?? 0,
                            onDecrement: () => _decrementSimpleExtra(extra),
                            onIncrement: () => _incrementSimpleExtra(extra),
                          );
                        },
                        childCount: _simpleExtraCounts.length,
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
    String title = widget.orderType;
    if (widget.tableNumber != null) {
      title = 'Mesa ${widget.tableNumber} - Orden ${widget.orderNumber}';
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