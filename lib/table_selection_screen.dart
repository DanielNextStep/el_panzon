import 'package:flutter/material.dart';
import 'shared_styles.dart';
import 'order_screen.dart';

class TableSelectionScreen extends StatelessWidget {
  // --- AÑADIDO: Recibe los sabores disponibles ---
  final Map<String, bool> availableFlavors;

  const TableSelectionScreen({
    super.key,
    required this.availableFlavors, // --- AÑADIDO: al constructor
  });

  // Navega a la pantalla de orden pasando el número de mesa
  void _navigateToOrderScreen(BuildContext context, int tableNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderScreen(
          orderType: 'Para comer aquí',
          tableNumber: tableNumber,
          // --- AÑADIDO: Pasa los sabores a la pantalla de orden ---
          availableFlavors: availableFlavors,
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
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 columnas
                    crossAxisSpacing: 30, // Espacio horizontal
                    mainAxisSpacing: 30, // Espacio vertical
                    childAspectRatio: 1.2, // Ligeramente más anchos que altos
                  ),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    int tableNumber = index + 1;
                    return _buildTableButton(
                      context: context,
                      tableNumber: tableNumber,
                      onPressed: () {
                        _navigateToOrderScreen(context, tableNumber);
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
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: NeumorphicContainer(
        borderRadius: 20.0,
        padding: const EdgeInsets.all(20), // Padding uniforme
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.table_restaurant_outlined, // Icono de mesa
                color: kAccentColor,
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