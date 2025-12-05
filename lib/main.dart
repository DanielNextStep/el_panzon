import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'shared_styles.dart';
import 'table_selection_screen.dart';
import 'maintenance_screen.dart';
import 'services/firestore_service.dart';
import 'models/inventory_model.dart';
import 'open_orders_screen.dart';
import 'to_go_orders_screen.dart';
import 'sales_history_screen.dart'; // Import the new screen

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

  // We still hold this for compatibility with child screens
  Inventory _inventory = Inventory.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupInventoryListener();
  }

  void _setupInventoryListener() {
    _firestoreService.initializeDefaultInventoryIfEmpty();

    // Listen to the NEW stream (List<InventoryItem>)
    _firestoreService.getInventoryStream().listen((items) {
      if (mounted) {
        setState(() {
          // Convert new list format to old map format for compatibility
          _inventory = Inventory.fromItemList(items);
          _isLoading = false;
        });
      }
    });
  }

  void _navigateToMaintenance() async {
    HapticFeedback.mediumImpact();
    // No arguments needed anymore, MaintenanceScreen handles its own stream
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MaintenanceScreen(),
      ),
    );
  }

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

  void _navigateToSalesHistory() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SalesHistoryScreen(),
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
              Expanded(
                  flex: 2,
                  child: Center(
                      child: Image.asset('assets/images/Logo_Panzon_SF.png',
                          height: 150))),
              Expanded(
                  flex: 3,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NeumorphicButton(
                            text: 'Para llevar', onTap: _navigateToToGoManager),
                        const SizedBox(height: 30),
                        NeumorphicButton(
                            text: 'Para comer aquí',
                            onTap: () => _navigateToTableSelection()),
                      ])),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                NeumorphicIconButton(
                    icon: Icons.settings_outlined,
                    onTap: _navigateToMaintenance),
                // NEW Button for Sales History
                NeumorphicIconButton(
                    icon: Icons.history_edu, // Icon for history
                    onTap: _navigateToSalesHistory),
                NeumorphicIconButton(
                    icon: Icons.restaurant_menu,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const OpenOrdersScreen()));
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
  final String text;
  final VoidCallback onTap;
  const NeumorphicButton({super.key, required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: NeumorphicContainer(
            borderRadius: 25,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Center(
                child: Text(text,
                    style: const TextStyle(
                        color: kAccentColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)))));
  }
}

class NeumorphicIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NeumorphicIconButton(
      {super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: NeumorphicContainer(
            isCircle: true,
            padding: const EdgeInsets.all(20),
            child: Icon(icon, color: kAccentColor, size: 28)));
  }
}