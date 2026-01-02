import 'package:cloud_firestore/cloud_firestore.dart';

// --- New Detailed Model for Maintenance ---
class InventoryItem {
  final String id;
  final String name;
  final String type; // 'taco', 'soda', 'extra'
  final double price;
  final int currentStock; // Was dailyProduction - Now represents remaining stock
  final int initialStock; // Total produced today
  final bool isActive;

  InventoryItem({
    required this.id,
    required this.name,
    required this.type,
    this.price = 0.0,
    this.currentStock = 0,
    this.initialStock = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'price': price,
      'currentStock': currentStock,
      'initialStock': initialStock,
      'isActive': isActive,
    };
  }

  factory InventoryItem.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryItem(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? 'taco',
      price: (data['price'] ?? 0.0).toDouble(),
      // Handle migration: if currentStock doesn't exist, use old dailyProduction
      currentStock: (data['currentStock'] ?? data['dailyProduction'] ?? 0).toInt(),
      initialStock: (data['initialStock'] ?? 0).toInt(),
      isActive: data['isActive'] ?? true,
    );
  }
}

// --- Old Model (Kept for backward compatibility with existing screens) ---
class Inventory {
  final Map<String, bool> flavors;
  final Map<String, bool> extras;

  Inventory({required this.flavors, required this.extras});

  factory Inventory.empty() {
    return Inventory(flavors: {}, extras: {});
  }

  // Helper to create the old "Inventory" object from the new List<InventoryItem>
  factory Inventory.fromItemList(List<InventoryItem> items) {
    final flavors = <String, bool>{};
    final extras = <String, bool>{};

    for (var item in items) {
      // Only include if active AND has stock (if tracking stock)
      bool isAvailable = item.isActive;

      // Optional: Auto-disable if out of stock for tracked items
      if (item.initialStock > 0 && item.currentStock <= 0) {
        isAvailable = false;
      }

      if (item.type == 'taco') {
        flavors[item.name] = isAvailable;
      } else {
        extras[item.name] = isAvailable;
      }
    }
    return Inventory(flavors: flavors, extras: extras);
  }
}