import 'package:cloud_firestore/cloud_firestore.dart';

// --- New Detailed Model for Maintenance ---
class InventoryItem {
  final String id;
  final String name;
  final String type; // 'taco', 'soda', 'extra'
  final double price;
  final int dailyProduction;
  final bool isActive;

  InventoryItem({
    required this.id,
    required this.name,
    required this.type,
    this.price = 0.0,
    this.dailyProduction = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'price': price,
      'dailyProduction': dailyProduction,
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
      dailyProduction: (data['dailyProduction'] ?? 0).toInt(),
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
      if (item.type == 'taco') {
        flavors[item.name] = item.isActive;
      } else {
        extras[item.name] = item.isActive;
      }
    }
    return Inventory(flavors: flavors, extras: extras);
  }
}