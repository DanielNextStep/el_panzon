import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String? id;
  final int tableNumber; // 0 usually means "To Go"
  final int orderNumber;
  final int totalItems;
  final DateTime timestamp;
  final String? customerName;
  final List<String> salsas; // --- CHANGED: Now a List ---

  // What was ORDERED
  final Map<String, int> tacoCounts;
  final Map<String, Map<String, int>> sodaCounts;
  final Map<String, int> simpleExtraCounts;

  // What was SERVED
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
    this.salsas = const [], // Default empty list
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

    return OrderModel(
      id: doc.id,
      tableNumber: data['tableNumber'] ?? 0,
      orderNumber: data['orderNumber'] ?? 0,
      totalItems: data['totalItems'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      customerName: data['customerName'],
      salsas: List<String>.from(data['salsas'] ?? []), // --- LOAD LIST ---

      tacoCounts: Map<String, int>.from(data['tacoCounts'] ?? {}),
      sodaCounts: parseNestedMap(data['sodaCounts']),
      simpleExtraCounts: Map<String, int>.from(data['simpleExtraCounts'] ?? {}),

      tacoServed: Map<String, int>.from(data['tacoServed'] ?? {}),
      sodaServed: parseNestedMap(data['sodaServed']),
      simpleExtraServed: Map<String, int>.from(data['simpleExtraServed'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tableNumber': tableNumber,
      'orderNumber': orderNumber,
      'totalItems': totalItems,
      'timestamp': Timestamp.fromDate(timestamp),
      'customerName': customerName,
      'salsas': salsas, // --- SAVE LIST ---
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
    bool check(Map<String, int> ordered, Map<String, int> served) {
      for (var entry in ordered.entries) {
        if ((served[entry.key] ?? 0) < entry.value) return false;
      }
      return true;
    }

    if (!check(tacoCounts, tacoServed)) return false;
    if (!check(simpleExtraCounts, simpleExtraServed)) return false;

    // Check sodas
    for (var flavor in sodaCounts.keys) {
      int coldOrdered = sodaCounts[flavor]!['Frío'] ?? 0;
      int warmOrdered = sodaCounts[flavor]!['Al Tiempo'] ?? 0;
      int coldServed = sodaServed[flavor]?['Frío'] ?? 0;
      int warmServed = sodaServed[flavor]?['Al Tiempo'] ?? 0;

      if (coldServed < coldOrdered) return false;
      if (warmServed < warmOrdered) return false;
    }

    return true;
  }
}