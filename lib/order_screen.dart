import 'package:flutter/material.dart';
import 'shared_styles.dart';
import 'table_order_manager.dart'; // Importa la clase OrderDetails

class OrderScreen extends StatefulWidget {
  final String orderType;
  final int? tableNumber;
  final int orderNumber;
  final Map<String, bool> availableFlavors;
  final Map<String, bool> availableExtras;
  // --- AÑADIDO: Orden opcional para editar ---
  final OrderDetails? existingOrder;

  const OrderScreen({
    super.key,
    required this.orderType,
    this.tableNumber,
    required this.orderNumber,
    required this.availableFlavors,
    required this.availableExtras,
    this.existingOrder, // --- AÑADIDO: al constructor
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  // Mapas para rastrear las cantidades
  late Map<String, int> _tacoCounts;
  late Map<String, int> _simpleExtraCounts;
  late Map<String, Map<String, int>> _sodaCounts;

  int _grandTotal = 0;
  final List<String> _sodaFlavors = ['Coca', 'Boing de Mango', 'Boing de Guayaba'];

  @override
  void initState() {
    super.initState();

    // --- LÓGICA DE INIT ACTUALIZADA ---

    // 1. Inicializa todos los mapas con 0 para los items DISPONIBLES
    _tacoCounts = {};
    widget.availableFlavors.forEach((flavor, isAvailable) {
      if (isAvailable) {
        _tacoCounts[flavor] = 0;
      }
    });

    _simpleExtraCounts = {};
    widget.availableExtras.forEach((extra, isAvailable) {
      if (isAvailable && extra != 'Refrescos') {
        _simpleExtraCounts[extra] = 0;
      }
    });

    _sodaCounts = {};
    for (var flavor in _sodaFlavors) {
      _sodaCounts[flavor] = {'Frío': 0, 'Al Tiempo': 0};
    }

    // 2. Si es una orden existente, PUEBLA los mapas con esos datos
    if (widget.existingOrder != null) {
      // Puebla tacos
      widget.existingOrder!.tacoCounts.forEach((flavor, count) {
        if (_tacoCounts.containsKey(flavor)) { // Solo si sigue disponible
          _tacoCounts[flavor] = count;
        }
      });

      // Puebla extras simples
      widget.existingOrder!.simpleExtraCounts.forEach((extra, count) {
        if (_simpleExtraCounts.containsKey(extra)) { // Solo si sigue disponible
          _simpleExtraCounts[extra] = count;
        }
      });

      // Puebla refrescos
      widget.existingOrder!.sodaCounts.forEach((flavor, temps) {
        if (_sodaCounts.containsKey(flavor)) { // Solo si sigue disponible
          _sodaCounts[flavor] = Map<String, int>.from(temps);
        }
      });
    }

    // 3. Calcula el total inicial (sea 0 o el de la orden existente)
    _calculateTotal();
  }

  // --- Lógica de incremento/decremento ---
  void _incrementTaco(String flavor) {
    setState(() {
      _tacoCounts[flavor] = (_tacoCounts[flavor] ?? 0) + 1;
      _calculateTotal();
    });
  }

  void _decrementTaco(String flavor) {
    setState(() {
      if ((_tacoCounts[flavor] ?? 0) > 0) {
        _tacoCounts[flavor] = _tacoCounts[flavor]! - 1;
        _calculateTotal();
      }
    });
  }

  void _incrementSoda(String flavor, String temp) {
    setState(() {
      _sodaCounts[flavor]![temp] = (_sodaCounts[flavor]![temp] ?? 0) + 1;
      _calculateTotal();
    });
  }

  void _decrementSoda(String flavor, String temp) {
    setState(() {
      if ((_sodaCounts[flavor]![temp] ?? 0) > 0) {
        _sodaCounts[flavor]![temp] = _sodaCounts[flavor]![temp]! - 1;
        _calculateTotal();
      }
    });
  }

  void _incrementSimpleExtra(String extra) {
    setState(() {
      _simpleExtraCounts[extra] = (_simpleExtraCounts[extra] ?? 0) + 1;
      _calculateTotal();
    });
  }

  void _decrementSimpleExtra(String extra) {
    setState(() {
      if ((_simpleExtraCounts[extra] ?? 0) > 0) {
        _simpleExtraCounts[extra] = _simpleExtraCounts[extra]! - 1;
        _calculateTotal();
      }
    });
  }

  void _calculateTotal() {
    int total = 0;
    _tacoCounts.forEach((_, count) => total += count);
    _sodaCounts.forEach(
            (_, temps) => total += (temps['Frío']! + temps['Al Tiempo']!));
    _simpleExtraCounts.forEach((_, count) => total += count);
    setState(() {
      _grandTotal = total;
    });
  }
  // --- Fin de la lógica de incremento/decremento ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // --- Sección de Tacos ---
                  // Solo muestra la sección si hay tacos disponibles
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

                  // --- Sección de Refrescos ---
                  // Solo muestra la sección si los refrescos están habilitados
                  if (widget.availableExtras['Refrescos'] == true) ...[
                    SliverToBoxAdapter(
                        child: _buildSectionHeader('Refrescos')),
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

                  // --- Sección de Extras Simples ---
                  // Solo muestra la sección si hay extras simples
                  if (_simpleExtraCounts.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _buildSectionHeader('Extras')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String extra =
                          _simpleExtraCounts.keys.elementAt(index);
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
            // --- Sección de Resumen y Botón ---
            _buildSummarySection(),
          ],
        ),
      ),
    );
  }

  // --- Encabezado de Sección ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: kAccentColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // --- Custom App Bar ---
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
          // Botón de Regresar
          GestureDetector(
            onTap: () => Navigator.of(context).pop(), // Solo regresa
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
          // Título
          Flexible( // Evita overflow si el título es muy largo
            child: Text(
              title,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Placeholder para centrar el título
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // --- Taco Order Item Widget (usado también para extras simples) ---
  Widget _buildTacoOrderItem({
    required String flavor,
    required int count,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Padding(
      // Padding horizontal de 20 para alinear con refrescos
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flavor
            Expanded(
              child: Text(
                flavor,
                style: const TextStyle(
                  color: kTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
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
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.remove, color: kAccentColor, size: 22),
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
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.add, color: kAccentColor, size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget específico para Refrescos ---
  Widget _buildSodaOrderItem({required String flavor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sabor del Refresco
            Text(
              flavor,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            // Contador para "Frío"
            _buildCounterRow(
              label: 'Frío',
              count: _sodaCounts[flavor]?['Frío'] ?? 0,
              onDecrement: () => _decrementSoda(flavor, 'Frío'),
              onIncrement: () => _incrementSoda(flavor, 'Frío'),
            ),
            const SizedBox(height: 10),
            // Contador para "Al Tiempo"
            _buildCounterRow(
              label: 'Al Tiempo',
              count: _sodaCounts[flavor]?['Al Tiempo'] ?? 0,
              onDecrement: () => _decrementSoda(flavor, 'Al Tiempo'),
              onIncrement: () => _incrementSoda(flavor, 'Al Tiempo'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sub-widget reutilizable para contadores ---
  Widget _buildCounterRow({
    required String label,
    required int count,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label (e.g., "Frío")
        Text(
          label,
          style: const TextStyle(
            color: kTextColor,
            fontSize: 17,
            fontWeight: FontWeight.w500,
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
                padding: EdgeInsets.all(10), // Un poco más pequeño
                child: Icon(Icons.remove, color: kAccentColor, size: 20),
              ),
            ),
            // Count
            Container(
              width: 50, // Un poco más estrecho
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(
                  color: kTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Increment Button
            GestureDetector(
              onTap: onIncrement,
              child: const NeumorphicContainer(
                isCircle: true,
                padding: EdgeInsets.all(10), // Un poco más pequeño
                child: Icon(Icons.add, color: kAccentColor, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Sección de Resumen y Botón de Crear/Añadir Orden ---
  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      decoration: const BoxDecoration(
        color: kBackgroundColor,
        border: Border(
          top: BorderSide(color: kShadowColor, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Resumen de Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Items:',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_grandTotal',
                style: const TextStyle(
                  color: kTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Botón de Crear Orden
          GestureDetector(
            onTap: () {
              // Si es "Para llevar", regresa al inicio
              if (widget.tableNumber == null) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                return; // Importante
              }

              // Si es para una mesa, devuelve un objeto OrderDetails
              // (Esta lógica funciona para crear Y actualizar)
              final orderDetails = OrderDetails(
                orderNumber: widget.orderNumber,
                totalItems: _grandTotal,
                // Filtra solo los items que tienen > 0
                tacoCounts: Map.fromEntries(
                  _tacoCounts.entries.where((e) => e.value > 0),
                ),
                sodaCounts: Map.fromEntries(
                  _sodaCounts.entries.where(
                          (e) => (e.value['Frío']! + e.value['Al Tiempo']!) > 0),
                ),
                simpleExtraCounts: Map.fromEntries(
                  _simpleExtraCounts.entries.where((e) => e.value > 0),
                ),
              );

              // Devuelve la orden (sea nueva o actualizada)
              Navigator.of(context).pop(orderDetails);
            },
            child: NeumorphicContainer(
              padding: const EdgeInsets.symmetric(vertical: 20),
              borderRadius: 20,
              child: Center(
                child: Text(
                  // --- TEXTO DEL BOTÓN ACTUALIZADO ---
                  _getButtonText(),
                  style: const TextStyle(
                    color: kAccentColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- AÑADIDO: Helper para determinar el texto del botón ---
  String _getButtonText() {
    // Si es "Para llevar" (no hay número de mesa)
    if (widget.tableNumber == null) {
      return 'Crear Orden';
    }
    // Si es para mesa Y es una orden existente
    if (widget.existingOrder != null) {
      return 'Actualizar Orden ${widget.orderNumber}';
    }
    // Si es para mesa Y es una orden nueva
    return 'Añadir Orden ${widget.orderNumber} a Mesa';
  }
}