import 'package:flutter/material.dart';
import 'shared_styles.dart';
import 'models/order_model.dart';

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
  late Map<String, int> _tacoCounts;
  late Map<String, int> _simpleExtraCounts;
  late Map<String, Map<String, int>> _sodaCounts;
  final TextEditingController _nameController = TextEditingController(); // --- NEW ---

  int _grandTotal = 0;
  final List<String> _sodaFlavors = ['Coca', 'Boing de Mango', 'Boing de Guayaba'];

  @override
  void initState() {
    super.initState();

    // 1. Initialize maps
    _tacoCounts = {};
    widget.availableFlavors.forEach((flavor, isAvailable) {
      if (isAvailable) _tacoCounts[flavor] = 0;
    });

    _simpleExtraCounts = {};
    widget.availableExtras.forEach((extra, isAvailable) {
      if (isAvailable && extra != 'Refrescos') _simpleExtraCounts[extra] = 0;
    });

    _sodaCounts = {};
    for (var flavor in _sodaFlavors) {
      _sodaCounts[flavor] = {'Frío': 0, 'Al Tiempo': 0};
    }

    // 2. Populate existing data
    if (widget.existingOrder != null) {
      _nameController.text = widget.existingOrder!.customerName ?? ''; // --- NEW ---

      widget.existingOrder!.tacoCounts.forEach((flavor, count) {
        if (_tacoCounts.containsKey(flavor)) _tacoCounts[flavor] = count;
      });

      widget.existingOrder!.simpleExtraCounts.forEach((extra, count) {
        if (_simpleExtraCounts.containsKey(extra)) _simpleExtraCounts[extra] = count;
      });

      widget.existingOrder!.sodaCounts.forEach((flavor, temps) {
        if (_sodaCounts.containsKey(flavor)) {
          _sodaCounts[flavor] = Map<String, int>.from(temps);
        }
      });
    }

    _calculateTotal();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ... Increment/Decrement methods remain identical ...
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),

            // --- NEW: Customer Name Input (Only for "To Go") ---
            if (widget.tableNumber == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: NeumorphicContainer(
                  borderRadius: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Nombre del Cliente (Opcional)',
                      border: InputBorder.none,
                      icon: Icon(Icons.person_outline, color: kAccentColor),
                    ),
                    style: const TextStyle(color: kTextColor, fontSize: 18),
                  ),
                ),
              ),

            Expanded(
              child: CustomScrollView(
                slivers: [
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
                  if (widget.availableExtras['Refrescos'] == true) ...[
                    SliverToBoxAdapter(child: _buildSectionHeader('Refrescos')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String flavor = _sodaFlavors[index];
                          return _buildSodaOrderItem(flavor: flavor);
                        },
                        childCount: _sodaFlavors.length,
                      ),
                    ),
                  ],
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
                ],
              ),
            ),
            _buildSummarySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Text(
        title,
        style: const TextStyle(color: kAccentColor, fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    // ... AppBar logic remains same ...
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

  // ... _buildTacoOrderItem, _buildSodaOrderItem, _buildCounterRow remain exactly the same ...
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

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      decoration: const BoxDecoration(
        color: kBackgroundColor,
        border: Border(top: BorderSide(color: kShadowColor, width: 1.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Items:', style: TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w500)),
              Text('$_grandTotal', style: const TextStyle(color: kTextColor, fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              // Create OrderModel
              final orderModel = OrderModel(
                id: widget.existingOrder?.id,
                tableNumber: widget.tableNumber ?? 0, // Use 0 for To Go
                orderNumber: widget.orderNumber,
                totalItems: _grandTotal,
                timestamp: widget.existingOrder?.timestamp ?? DateTime.now(),
                customerName: _nameController.text.isEmpty ? null : _nameController.text, // --- SAVE NAME ---

                tacoCounts: Map.fromEntries(_tacoCounts.entries.where((e) => e.value > 0)),
                sodaCounts: Map.fromEntries(_sodaCounts.entries.where((e) => (e.value['Frío']! + e.value['Al Tiempo']!) > 0)),
                simpleExtraCounts: Map.fromEntries(_simpleExtraCounts.entries.where((e) => e.value > 0)),

                // Keep existing served counts if editing
                tacoServed: widget.existingOrder?.tacoServed ?? {},
                sodaServed: widget.existingOrder?.sodaServed ?? {},
                simpleExtraServed: widget.existingOrder?.simpleExtraServed ?? {},
              );

              Navigator.of(context).pop(orderModel);
            },
            child: NeumorphicContainer(
              padding: const EdgeInsets.symmetric(vertical: 20),
              borderRadius: 20,
              child: Center(
                child: Text(
                  _getButtonText(),
                  style: const TextStyle(color: kAccentColor, fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText() {
    if (widget.tableNumber == null) return 'Crear Orden';
    if (widget.existingOrder != null) return 'Actualizar Orden ${widget.orderNumber}';
    return 'Añadir Orden ${widget.orderNumber} a Mesa';
  }
}