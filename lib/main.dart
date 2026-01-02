import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'shared_styles.dart';
import 'table_order_manager.dart'; // Direct navigation to table manager
import 'maintenance_screen.dart';
import 'services/firestore_service.dart';
import 'models/inventory_model.dart';
import 'open_orders_screen.dart';
import 'to_go_orders_screen.dart';
import 'sales_history_screen.dart';

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

  // We keep this inventory state to pass it down to order screens
  Inventory _inventory = Inventory.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupInventoryListener();
  }

  void _setupInventoryListener() {
    _firestoreService.initializeDefaultInventoryIfEmpty();

    _firestoreService.getInventoryStream().listen((items) {
      if (mounted) {
        setState(() {
          _inventory = Inventory.fromItemList(items);
          _isLoading = false;
        });
      }
    });
  }

  void _navigateToMaintenance() async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MaintenanceScreen()),
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

  void _navigateToTable(int tableNumber) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TableOrderManagerScreen(
          tableNumber: tableNumber,
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
      MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
    );
  }

  // --- NEW: Inventory Progress Tooltip ---
  void _showInventoryStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kBackgroundColor,
          title: const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: kAccentColor),
              SizedBox(width: 10),
              Text("Estado del Inventario", style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<List<InventoryItem>>(
              stream: _firestoreService.getInventoryStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // Filter only items that track production (>0)
                final trackedItems = snapshot.data!.where((i) => i.initialStock > 0 || i.type == 'taco').toList();

                if (trackedItems.isEmpty) return const Text("No hay items con seguimiento de producción.");

                // Calculate Grand Totals
                int totalAvailable = 0;
                int totalConsumed = 0;
                int totalProduced = 0;

                for (var item in trackedItems) {
                  totalAvailable += item.currentStock; // UPDATED to use currentStock
                  totalProduced += item.initialStock;
                  totalConsumed += (item.initialStock - item.currentStock);
                }

                double totalProgress = totalProduced > 0 ? (totalAvailable / totalProduced).clamp(0.0, 1.0) : 0.0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // List of Individual Items
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: trackedItems.length,
                        itemBuilder: (context, index) {
                          final item = trackedItems[index];
                          // Use currentStock logic
                          int consumed = item.initialStock - item.currentStock;
                          double progress = item.initialStock > 0 ? (item.currentStock / item.initialStock).clamp(0.0, 1.0) : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, color: kTextColor)),
                                    Text(
                                        "$consumed / ${item.initialStock} Vendidos",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey)
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.grey[300],
                                    // Use currentStock for color logic
                                    color: item.currentStock < (item.initialStock * 0.2) ? Colors.redAccent : kAccentColor,
                                    minHeight: 6,
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(height: 30, color: kShadowColor),

                    // --- GRAND TOTAL SUMMARY ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: kAccentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kAccentColor.withOpacity(0.3))
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("PRODUCIDOS:", style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor, fontSize: 12)),
                              Text("$totalProduced", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("VENDIDOS:", style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor, fontSize: 12)),
                              Text("$totalConsumed", style: const TextStyle(fontWeight: FontWeight.w900, color: kTextColor, fontSize: 16)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("DISPONIBLES:", style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor, fontSize: 12)),
                              Text("$totalAvailable", style: const TextStyle(fontWeight: FontWeight.w900, color: kAccentColor, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: totalProgress,
                              backgroundColor: Colors.grey[300],
                              color: kAccentColor,
                              minHeight: 10,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar", style: TextStyle(color: kTextColor)),
            )
          ],
        );
      },
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
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Center(
                // 5. Tooltip on Click
                child: GestureDetector(
                  onTap: () => _showInventoryStatus(context),
                  // 4. Bigger Logo (Height increased to 140)
                  child: Image.asset('assets/images/Logo_Panzon_SF.png', height: 140),
                ),
              ),
            ),

            // 3. Removed "Mesas" label section

            // --- TABLE GRID ---
            Expanded(
              child: StreamBuilder<Set<int>>(
                stream: _firestoreService.getBusyTablesStream(),
                builder: (context, snapshot) {
                  final busyTables = snapshot.data ?? {};

                  final List<int> tables = [1, 2, 3, 4, 5];

                  final int itemCount = tables.length + 1;

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(40, 20, 40, 20), // Increased horizontal margin for smaller grid
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index == tables.length) {
                        return GestureDetector(
                          onTap: _navigateToToGoManager,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: kAccentColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: kAccentColor.withOpacity(0.4),
                                  offset: const Offset(4, 4),
                                  blurRadius: 6,
                                ),
                                BoxShadow(
                                  color: Colors.white,
                                  offset: const Offset(-4, -4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 30,
                                    color: Colors.white
                                ),
                                SizedBox(height: 5),
                                Text(
                                  "Llevar",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final tableNum = tables[index];
                      final isBusy = busyTables.contains(tableNum);

                      return GestureDetector(
                        onTap: () => _navigateToTable(tableNum),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: isBusy ? Colors.redAccent : kBackgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: isBusy ? Colors.red.withOpacity(0.4) : kShadowColor.withOpacity(0.5),
                                offset: const Offset(4, 4),
                                blurRadius: 6,
                              ),
                              BoxShadow(
                                color: isBusy ? Colors.redAccent.withOpacity(0.5) : Colors.white,
                                offset: const Offset(-4, -4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  Icons.table_restaurant,
                                  size: 30,
                                  color: isBusy ? Colors.white : kAccentColor
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "$tableNum",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: isBusy ? Colors.white : kAccentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // 3. Action buttons at the bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ActionIconButton(
                      label: "Historial",
                      icon: Icons.history_edu,
                      onTap: _navigateToSalesHistory),
                  ActionIconButton(
                      label: "Config",
                      icon: Icons.settings_outlined,
                      onTap: _navigateToMaintenance),
                  ActionIconButton(
                      label: "Cocina",
                      icon: Icons.restaurant_menu,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const OpenOrdersScreen()));
                      }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW WIDGET: Distinct style for bottom actions ---
class ActionIconButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const ActionIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 2. Bigger Control Buttons
          NeumorphicContainer(
            isCircle: true,
            padding: const EdgeInsets.all(22), // Increased padding for bigger button
            child: Icon(icon, color: kAccentColor, size: 32), // Increased icon size
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14, // Slightly bigger text
              fontWeight: FontWeight.bold,
              color: kTextColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}