import 'models/order_model.dart';
import 'services/firestore_service.dart';

class TableSelectionScreen extends StatelessWidget {
  final Map<String, bool> availableFlavors;
  final Map<String, bool> availableExtras;

  const TableSelectionScreen({
    super.key,
    required this.availableFlavors,
    required this.availableExtras,
  });

  void _navigateToTableManager(BuildContext context, int tableNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TableOrderManagerScreen(
          tableNumber: tableNumber,
          availableFlavors: availableFlavors,
          availableExtras: availableExtras,
        ),
      ),
    );
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

            // --- Cuadrícula de Mesas ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: StreamBuilder<List<OrderModel>>(
                  stream: FirestoreService().getAllActiveOrdersStream(),
                  builder: (context, snapshot) {
                    // Map active orders by table number
                    final Map<int, OrderModel> activeOrders = {};
                    if (snapshot.hasData) {
                      for (var order in snapshot.data!) {
                        activeOrders[order.tableNumber] = order;
                      }
                    }

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // 2 columnas
                        crossAxisSpacing: 30, // Espacio horizontal
                        mainAxisSpacing: 30, // Espacio vertical
                        childAspectRatio: 1.2, // Ligeramente más anchos que altos
                      ),
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        int tableNumber = index + 1;
                        final order = activeOrders[tableNumber];
                        
                        // Status Logic
                        Color? statusColor;
                        if (order != null) {
                          if (order.tableNumber == 3 && !order.isFullyServed) {
                             print("DEBUG: Table 3 is PENDING. Items:");
                             for(var p in order.people.values) {
                               for(var i in p.items) {
                                 print(" - ${i.name}: Qty=${i.quantity}, Served=${i.extras['served']}");
                               }
                             }
                          }

                          if (order.isFullyServed) {
                             statusColor = Colors.green.withOpacity(0.2); // Served
                          } else {
                             statusColor = Colors.redAccent.withOpacity(0.2); // Pending
                          }
                        }

                        return _buildTableButton(
                          context: context,
                          tableNumber: tableNumber,
                          color: statusColor,
                          onPressed: () {
                            _navigateToTableManager(context, tableNumber);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Custom App Bar Widget ---
  Widget _buildAppBar(BuildContext context) {
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
          const Text(
            'Seleccionar Mesa',
            style: TextStyle(
              color: kTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Placeholder para centrar el título
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // --- Botón Neumorphic para Mesa ---
  Widget _buildTableButton({
    required BuildContext context,
    required int tableNumber,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: NeumorphicContainer(
        borderRadius: 20.0,
        padding: const EdgeInsets.all(20), // Padding uniforme
        color: color,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.table_restaurant_outlined, // Icono de mesa
                color: color != null ? kTextColor : kAccentColor, // Change icon color slightly on colored bg
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                'Mesa $tableNumber',
                style: const TextStyle(
                  color: kTextColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}