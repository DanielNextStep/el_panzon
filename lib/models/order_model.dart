import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String name;
  final int quantity;
  final Map<String, dynamic> extras; // e.g., {'salsa': 'Roja', 'temp': 'Frío'}

  OrderItem({required this.name, required this.quantity, this.extras = const {}});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'extras': extras,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      extras: Map<String, dynamic>.from(map['extras'] ?? {}),
    );
  }
}

class PersonOrder {
  final String name; // e.g., "Juan", "P1"
  final List<OrderItem> items;

  PersonOrder({required this.name, required this.items});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory PersonOrder.fromMap(Map<String, dynamic> map) {
    return PersonOrder(
      name: map['name'] ?? 'Guest',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrderModel {
  final String? id;
  final int tableNumber; // 0 indicates "To Go"
  final int orderNumber;
  final int totalItems;
  final DateTime timestamp;
  final String? customerName; // Mainly for To Go (legacy support)

  // NEW: Nested Map Structure for People
  // Key: Person ID (e.g., "P1"), Value: PersonOrder object
  final Map<String, PersonOrder> people;

  // LEGACY FIELDS (Kept for backward compatibility during migration)
  // Eventually these should be derived from 'people'
  final List<String> salsas;
  final Map<String, int> tacoCounts;
  final Map<String, Map<String, int>> sodaCounts;
  final Map<String, int> simpleExtraCounts;
  final Map<String, int> tacoServed;
  final Map<String, Map<String, int>> sodaServed;
  final Map<String, int> simpleExtraServed;

  OrderModel({
    this.id,
    required this.tableNumber,
    required this.orderNumber,
    required this.totalItems,
    required this.timestamp,
    this.customerName,
    this.people = const {}, // New field default
    this.salsas = const [],
    required this.tacoCounts,
    required this.sodaCounts,
    required this.simpleExtraCounts,
    this.tacoServed = const {},
    this.sodaServed = const {},
    this.simpleExtraServed = const {},
  });

  factory OrderModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<String, Map<String, int>> parseNestedMap(Map<String, dynamic>? raw) {
      if (raw == null) return {};
      final result = <String, Map<String, int>>{};
      raw.forEach((key, value) {
        if (value is Map) {
          result[key] = Map<String, int>.from(value.map((k, v) => MapEntry(k, v as int)));
        }
      });
      return result;
    }

    // Parse People Map
    Map<String, PersonOrder> parsedPeople = {};
    if (data['people'] != null) {
      final peopleMap = data['people'] as Map<String, dynamic>;
      peopleMap.forEach((key, value) {
        parsedPeople[key] = PersonOrder.fromMap(value as Map<String, dynamic>);
      });
    }

    return OrderModel(
      id: doc.id,
      tableNumber: data['tableNumber'] ?? 0,
      orderNumber: data['orderNumber'] ?? 0,
      totalItems: data['totalItems'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      customerName: data['customerName'],

      people: parsedPeople, // Load new structure

      // Legacy loading
      salsas: List<String>.from(data['salsas'] ?? []),
      tacoCounts: Map<String, int>.from(data['tacoCounts'] ?? {}),
      sodaCounts: parseNestedMap(data['sodaCounts']),
      simpleExtraCounts: Map<String, int>.from(data['simpleExtraCounts'] ?? {}),
      tacoServed: Map<String, int>.from(data['tacoServed'] ?? {}),
      sodaServed: parseNestedMap(data['sodaServed']),
      simpleExtraServed: Map<String, int>.from(data['simpleExtraServed'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    // Convert People Map to JSON
    Map<String, dynamic> peopleMap = {};
    people.forEach((key, value) {
      peopleMap[key] = value.toMap();
    });

    return {
      'tableNumber': tableNumber,
      'orderNumber': orderNumber,
      'totalItems': totalItems,
      'timestamp': Timestamp.fromDate(timestamp),
      'customerName': customerName,
      'people': peopleMap, // Save new structure

      // Legacy saving
      'salsas': salsas,
      'tacoCounts': tacoCounts,
      'sodaCounts': sodaCounts,
      'simpleExtraCounts': simpleExtraCounts,
      'tacoServed': tacoServed,
      'sodaServed': sodaServed,
      'simpleExtraServed': simpleExtraServed,
    };
  }

  // Helper to check if order is fully served
  bool get isFullyServed {
    // 1. Check People (New Structure)
    if (people.isNotEmpty) {
      for (var personKey in people.keys) {
        final person = people[personKey];
        if (person == null) continue;

        for (var item in person.items) {
          int served = item.extras['served'] ?? 0;
          if (served < item.quantity) {
            return false;
          }
        }
      }
      return true;
    }

    // 2. Check Legacy Fields (Fallback for To Go / Old Orders)
    if (tacoCounts.isNotEmpty) {
      for (var entry in tacoCounts.entries) {
        int served = tacoServed[entry.key] ?? 0;
        if (served < entry.value) return false;
      }
    }

    if (simpleExtraCounts.isNotEmpty) {
      for (var entry in simpleExtraCounts.entries) {
        int served = simpleExtraServed[entry.key] ?? 0;
        if (served < entry.value) return false;
      }
    }

    if (sodaCounts.isNotEmpty) {
      for (var entry in sodaCounts.entries) {
        String flavor = entry.key;
        Map<String, int> temps = entry.value;
        Map<String, int> servedTemps = sodaServed[flavor] ?? {};
        
        int totalQty = (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
        int totalServed = (servedTemps['Frío'] ?? 0) + (servedTemps['Al Tiempo'] ?? 0);
        
        if (totalServed < totalQty) return false;
      }
    }

    return true;
  }
}