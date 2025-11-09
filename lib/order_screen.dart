import 'package:flutter/material.dart';
import 'shared_styles.dart';

class OrderScreen extends StatefulWidget {
  final String orderType;
  final int? tableNumber;
  // --- AÑADIDO: Recibe el mapa de sabores ---
  final Map<String, bool> availableFlavors;

  const OrderScreen({
    super.key,
    required this.orderType,
    this.tableNumber,
    required this.availableFlavors, // --- AÑADIDO: al constructor
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  // --- ACTUALIZADO: Ya no está fijo, se inicializa en initState ---
  late Map<String, int> _tacoCounts;

  @override
  void initState() {
    super.initState();
    // --- AÑADIDO: Inicializa el mapa _tacoCounts dinámicamente ---
    _tacoCounts = {};
    // Itera sobre el mapa de sabores disponibles
    widget.availableFlavors.forEach((flavor, isAvailable) {
      // Si el sabor está disponible, lo añade al mapa de conteo
      if (isAvailable) {
        _tacoCounts[flavor] = 0; // Inicializa el conteo en 0
      }
    });
  }

  void _incrementTaco(String flavor) {
    setState(() {
      _tacoCounts[flavor] = (_tacoCounts[flavor] ?? 0) + 1;
    });
  }

  void _decrementTaco(String flavor) {
    setState(() {
      if ((_tacoCounts[flavor] ?? 0) > 0) {
        _tacoCounts[flavor] = (_tacoCounts[flavor] ?? 0) - 1;
      }
    });
  }

  int get _totalTacos {
    return _tacoCounts.values.fold(0, (sum, count) => sum + count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- Custom Neumorphic App Bar ---
            _buildAppBar(context),

            // --- Order List ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                // --- ACTUALIZADO: .keys ahora solo contiene sabores disponibles ---
                children: _tacoCounts.keys.map((String flavor) {
                  return _buildTacoOrderItem(
                    flavor: flavor,
                    count: _tacoCounts[flavor] ?? 0,
                    onDecrement: () => _decrementTaco(flavor),
                    onIncrement: () => _incrementTaco(flavor),
                  );
                }).toList(),
              ),
            ),

            // --- Order Summary & Action Button ---
            _buildSummarySection(),
          ],
        ),
      ),
    );
  }

  // --- Custom App Bar Widget ---
  Widget _buildAppBar(BuildContext context) {
    // --- Lógica de título actualizada ---
    String title = widget.orderType;
    if (widget.tableNumber != null) {
      title = 'Mesa ${widget.tableNumber}'; // Muestra "Mesa X"
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const NeumorphicContainer(
              isCircle: true,
              padding: EdgeInsets.all(14),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: kAccentColor,
                size: 20,
              ),
            ),
          ),
          // Title
          Text(
            title, // --- ACTUALIZADO: usa el título dinámico
            style: const TextStyle(
              color: kTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Placeholder for equal spacing
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // --- AÑADIDO: El método que faltaba ---
  // --- Taco Order Item Widget ---
  Widget _buildTacoOrderItem({
    required String flavor,
    required int count,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flavor Name
            Text(
              flavor,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            // --- Counter ---
            Row(
              children: [
                // Decrement Button
                GestureDetector(
                  onTap: onDecrement,
                  child: const NeumorphicContainer(
                    isCircle: true,
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.remove, color: kAccentColor, size: 20),
                  ),
                ),
                // Count
                Container(
                  width: 60,
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: kTextColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Increment Button
                GestureDetector(
                  onTap: onIncrement,
                  child: const NeumorphicContainer(
                    isCircle: true,
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.add, color: kAccentColor, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Summary Section Widget ---
  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kBackgroundColor,
        boxShadow: [
          // --- Top Shadow to separate from list ---
          BoxShadow(
            color: kShadowColor,
            offset: Offset(0, -4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: kHighlightColor,
            offset: Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Total Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Tacos:',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_totalTacos',
                style: const TextStyle(
                  color: kTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Place Order Button
          GestureDetector(
            onTap: () {
              // --- ACTUALIZADO: Imprime la info completa
              print(
                  'Placing order: $_tacoCounts, Type: ${widget.orderType}, Table: ${widget.tableNumber}');
              // Here you would add logic to submit the order
            },
            child: NeumorphicContainer(
              padding: const EdgeInsets.symmetric(vertical: 20),
              borderRadius: 20,
              child: const Center(
                child: Text(
                  'Crear Orden',
                  style: TextStyle(
                    color: kAccentColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10), // Padding for home bar
        ],
      ),
    );
  }
}