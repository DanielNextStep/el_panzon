import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'shared_styles.dart';
import 'order_screen.dart';
import 'table_selection_screen.dart';
import 'maintenance_screen.dart';
import 'services/firestore_service.dart';
import 'models/inventory_model.dart';
import 'models/order_model.dart';
import 'open_orders_screen.dart';
import 'to_go_orders_screen.dart'; // --- NEW IMPORT ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taco Shop',
      theme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  Inventory _inventory = Inventory.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupInventoryListener();
  }

  void _setupInventoryListener() {
    _firestoreService.initializeDefaultInventoryIfEmpty();

    _firestoreService.getInventoryStream().listen((inventoryData) {
      if (mounted) {
        setState(() {
          _inventory = inventoryData;
          _isLoading = false;
        });
      }
    });
  }

  // --- Navigation Methods ---

  void _navigateToMaintenance() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceScreen(
          initialFlavors: _inventory.flavors,
          initialExtras: _inventory.extras,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      await _firestoreService.updateInventory(
        flavors: result['flavors'],
        extras: result['extras'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventario actualizado en la nube')),
        );
      }
    }
  }

  // --- UPDATED: Now opens the Manager Screen ---
  void _navigateToToGoManager() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ToGoOrdersScreen(
          availableFlavors: _inventory.flavors,
          availableExtras: _inventory.extras,
        ),
      ),
    );
  }

  void _navigateToTableSelection() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TableSelectionScreen(
          availableFlavors: _inventory.flavors,
          availableExtras: _inventory.extras,
        ),
      ),
    );
  }

  void _showInventoryPopup() {
    HapticFeedback.mediumImpact();
    final available = _inventory.flavors.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Inventario (En vivo)', style: TextStyle(color: kAccentColor, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (available.isEmpty)
                const Text('No hay sabores disponibles.', style: TextStyle(color: kTextColor))
              else
                ...available.map((flavor) => Text('• $flavor', style: const TextStyle(color: kTextColor, fontSize: 16))),
            ],
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('Cerrar', style: TextStyle(color: kAccentColor, fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: kAccentColor)),
      );
    }
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            children: [
              Expanded(flex: 2, child: Center(child: Image.asset('assets/images/Logo_Panzon_SF.png', height: 150))),
              Expanded(flex: 3, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                // UPDATED: Calls the manager, not the creation screen
                NeumorphicButton(text: 'Para llevar', onTap: _navigateToToGoManager),
                const SizedBox(height: 30),
                NeumorphicButton(text: 'Para comer aquí', onTap: () => _navigateToTableSelection()),
              ])),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                NeumorphicIconButton(icon: Icons.settings_outlined, onTap: _navigateToMaintenance),
                NeumorphicIconButton(icon: Icons.restaurant_menu, onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const OpenOrdersScreen()));
                }),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class NeumorphicButton extends StatelessWidget {
  final String text; final VoidCallback onTap;
  const NeumorphicButton({super.key, required this.text, required this.onTap});
  @override Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: NeumorphicContainer(borderRadius: 25, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25), child: Center(child: Text(text, style: const TextStyle(color: kAccentColor, fontSize: 20, fontWeight: FontWeight.w700)))));
  }
}
class NeumorphicIconButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const NeumorphicIconButton({super.key, required this.icon, required this.onTap});
  @override Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: NeumorphicContainer(isCircle: true, padding: const EdgeInsets.all(20), child: Icon(icon, color: kAccentColor, size: 28)));
  }
}