import 'package:flutter/material.dart';
import 'order_screen.dart';
import 'shared_styles.dart';
import 'table_selection_screen.dart';
import 'maintenance_screen.dart'; // --- AÑADIDO: Import de mantenimiento

void main() {
  runApp(const TacoShopApp());
}

class TacoShopApp extends StatelessWidget {
  const TacoShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Panzón Tacos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBackgroundColor,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: kAccentColor),
        useMaterial3: true,
      ),
      home: const HomeScreen(), // --- CAMBIADO: HomeScreen ahora es StatefulWidget
    );
  }
}

// --- ACTUALIZADO: Convertido a StatefulWidget ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- AÑADIDO: Estado para guardar los sabores disponibles ---
  Map<String, bool> _availableFlavors = {
    'Papa': true,
    'Frijol de Chorizo': true,
    'Chicharron': true,
    'Carnitas': true,
    'Huevo en Pasilla': true,
    'Adobo': true,
    'Tinga': true,
  };

  // --- AÑADIDO: Mapa para guardar las cantidades de inventario (ejemplo) ---
  // Este mapa solo guarda las cantidades, la disponibilidad se controla arriba
  final Map<String, int> _inventoryQuantities = {
    'Papa': 40,
    'Frijol de Chorizo': 30,
    'Chicharron': 25,
    'Carnitas': 15,
    'Huevo en Pasilla': 10,
    'Adobo': 20,
    'Tinga': 22,
  };

  // --- Reusable Neumorphic Button ---
  Widget _buildNeumorphicButton({
    required BuildContext context,
    required String text,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: NeumorphicContainer(
        borderRadius: 25.0,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: kTextColor,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // --- Reusable Neumorphic Icon Button ---
  Widget _buildNeumorphicIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: NeumorphicContainer(
        isCircle: true,
        padding: const EdgeInsets.all(18),
        child: Icon(
          icon,
          color: kAccentColor,
          size: 26,
        ),
      ),
    );
  }

  // --- AÑADIDO: Navegación a la pantalla de mantenimiento ---
  void _navigateToMaintenance(BuildContext context) async {
    // Navega y espera a que la pantalla de mantenimiento devuelva un resultado
    final Map<String, bool>? updatedFlavors = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceScreen(
          initialFlavors: _availableFlavors,
        ),
      ),
    );

    // Si el usuario guardó (no solo regresó), actualiza el estado
    if (updatedFlavors != null) {
      setState(() {
        _availableFlavors = updatedFlavors;
      });
    }
  }

  // --- Info Popup (Ahora solo muestra inventario estático) ---
  void _showInfoPopup(BuildContext context) {
    // --- AÑADIDO: Lógica para construir la lista dinámicamente ---
    List<Widget> inventoryRows = [];
    _availableFlavors.forEach((flavor, isAvailable) {
      if (isAvailable) {
        // Si está disponible, busca su cantidad y añádelo a la fila
        int quantity = _inventoryQuantities[flavor] ?? 0;
        inventoryRows.add(_buildTacoAvailabilityRow(flavor, quantity));
      }
    });

    // Si no hay ninguno disponible, muestra un mensaje
    if (inventoryRows.isEmpty) {
      inventoryRows.add(
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No hay sabores disponibles configurados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kTextColor,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
    // --- FIN DE LA LÓGICA AÑADIDA ---

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Inventario (Ejemplo)', // Título actualizado
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: inventoryRows, // --- ACTUALIZADO: Usa la lista dinámica
          ),
          actions: [
            TextButton(
              child: const Text(
                'Cerrar',
                style: TextStyle(
                  color: kAccentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTacoAvailabilityRow(String flavor, int quantity) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            flavor,
            style: const TextStyle(
              color: kTextColor,
              fontSize: 17,
            ),
          ),
          Text(
            '$quantity pzs',
            style: const TextStyle(
              color: kTextColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/Logo_Panzon_SF.png',
                    width: MediaQuery.of(context).size.width * 0.75,
                  ),
                  const SizedBox(height: 70),
                  _buildNeumorphicButton(
                    context: context,
                    text: 'Para llevar',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderScreen(
                            orderType: 'Para llevar',
                            // --- AÑADIDO: Pasa los sabores disponibles ---
                            availableFlavors: _availableFlavors,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 35),
                  _buildNeumorphicButton(
                    context: context,
                    text: 'Para comer aquí',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TableSelectionScreen(
                            // --- AÑADIDO: Pasa los sabores disponibles ---
                            availableFlavors: _availableFlavors,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              // --- ACTUALIZADO: Botón de Ajustes/Mantenimiento ---
              child: _buildNeumorphicIconButton(
                icon: Icons.settings_outlined, // Icono cambiado
                onPressed: () {
                  _navigateToMaintenance(context); // Llama a la nueva función
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: _buildNeumorphicIconButton(
                icon: Icons.receipt_long_outlined,
                onPressed: () {
                  print('Open orders pressed');
                },
              ),
            ),
          ),
          // --- AÑADIDO: Botón de info (inventario) ---
          // Lo he movido al centro-abajo, entre los otros dos
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: _buildNeumorphicIconButton(
                icon: Icons.info_outline, // Icono de info
                onPressed: () {
                  _showInfoPopup(context); // Muestra el inventario
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}