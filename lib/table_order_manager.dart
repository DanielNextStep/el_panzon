import 'package:flutter/material.dart';
import 'shared_styles.dart';
import 'order_screen.dart'; // Importa la pantalla de órdenes
import 'order_detail_screen.dart'; // Importa la pantalla de detalle

// --- AÑADIDO: Modelo de datos para una orden ---
// Lo ponemos aquí para que tanto OrderScreen como TableOrderManagerScreen lo vean
class OrderDetails {
  final int orderNumber;
  final int totalItems;
  final Map<String, int> tacoCounts;
  final Map<String, Map<String, int>> sodaCounts;
  final Map<String, int> simpleExtraCounts;

  OrderDetails({
    required this.orderNumber,
    required this.totalItems,
    required this.tacoCounts,
    required this.sodaCounts,
    required this.simpleExtraCounts,
  });
}
// --- FIN DEL MODELO DE DATOS ---

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
  // Lista temporal (en memoria) para guardar las órdenes de esta mesa
  final List<OrderDetails> _orders = [];

  // Navega para crear una nueva orden
  void _navigateToAddOrder(BuildContext context) async {
    // El número de orden es el siguiente en la lista
    int newOrderNumber = _orders.length + 1;

    final newOrder = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderScreen(
          orderType: 'Mesa ${widget.tableNumber}',
          tableNumber: widget.tableNumber,
          orderNumber: newOrderNumber,
          availableFlavors: widget.availableFlavors,
          availableExtras: widget.availableExtras,
          existingOrder: null, // --- AÑADIDO: Es una orden nueva
        ),
      ),
    );

    // Si la pantalla de orden devolvió una orden válida, la añadimos
    if (newOrder != null && newOrder is OrderDetails) {
      setState(() {
        _orders.add(newOrder);
      });
    }
  }

  // --- AÑADIDO: Navega para EDITAR una orden existente ---
  void _navigateToEditOrder(
      BuildContext context, OrderDetails orderToEdit, int index) async {
    final updatedOrder = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderScreen(
          orderType: 'Mesa ${widget.tableNumber}',
          tableNumber: widget.tableNumber,
          orderNumber: orderToEdit.orderNumber, // Usa el número de orden existente
          availableFlavors: widget.availableFlavors,
          availableExtras: widget.availableExtras,
          existingOrder: orderToEdit, // --- AÑADIDO: Pasa la orden a editar
        ),
      ),
    );

    if (updatedOrder != null && updatedOrder is OrderDetails) {
      setState(() {
        _orders[index] = updatedOrder; // Reemplaza la orden en el índice
      });
    }
  }

  // --- Navega para ver el detalle (solo lectura) ---
  void _navigateToViewOrder(BuildContext context, OrderDetails order) {
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
            // --- AppBar con Título y Botón de Añadir ---
            _buildAppBar(context, title),

            // --- Lista de órdenes o estado vacío ---
            Expanded(
              child: _orders.isEmpty
                  ? _buildEmptyState() // Muestra mensaje si no hay órdenes
                  : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  // --- ACTUALIZADO: Pasa el índice para la edición ---
                  return _buildOrderItem(order, index);
                },
              ),
            ),

            // --- Botón inferior para finalizar el pedido de la mesa ---
            _buildSubmitTableOrderButton(context),
          ],
        ),
      ),
    );
  }

  // --- Estado vacío cuando no hay órdenes ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            color: kShadowColor,
            size: 80,
          ),
          const SizedBox(height: 20),
          const Text(
            'Aún no hay órdenes',
            style: TextStyle(
              color: kTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Presiona el botón "+" para agregar la primera orden.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kTextColor.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget para cada ítem de orden en la lista ---
  Widget _buildOrderItem(OrderDetails order, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // --- GESTUREDETECTOR PARA VER DETALLE ---
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToViewOrder(context, order),
                // --- Contenedor transparente para asegurar que el tap funcione ---
                child: Container(
                  color: Colors.transparent, // Asegura que el tap se registre
                  padding: const EdgeInsets.symmetric(vertical: 10.0), // Padding interno
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Orden ${order.orderNumber}',
                        style: const TextStyle(
                          color: kTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${order.totalItems} Items',
                        style: const TextStyle(
                          color: kTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: kTextColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // --- BOTÓN DE EDITAR ---
            GestureDetector(
              onTap: () => _navigateToEditOrder(context, order, index),
              child: const NeumorphicContainer(
                isCircle: true,
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.edit_outlined,
                  color: kAccentColor,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Botón inferior "Enviar Pedido de Mesa" ---
  Widget _buildSubmitTableOrderButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: GestureDetector(
        onTap: () {
          // Lógica para finalizar el pedido de la mesa
          // Por ahora, solo regresa a la pantalla de inicio
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: NeumorphicContainer(
          padding: const EdgeInsets.symmetric(vertical: 20),
          borderRadius: 20,
          child: const Center(
            child: Text(
              'Enviar Pedido de Mesa',
              style: TextStyle(
                color: kAccentColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- AppBar customizada ---
  Widget _buildAppBar(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón de Regresar
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
          // Título
          Text(
            title,
            style: const TextStyle(
              color: kTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Botón de Añadir Orden (+)
          GestureDetector(
            onTap: () => _navigateToAddOrder(context),
            child: const NeumorphicContainer(
              isCircle: true,
              padding: EdgeInsets.all(14),
              child: Icon(
                Icons.add,
                color: kAccentColor,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}