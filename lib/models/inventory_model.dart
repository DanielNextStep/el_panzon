import 'package:cloud_firestore/cloud_firestore.dart';

class Inventory {
  final Map<String, bool> flavors;
  final Map<String, bool> extras;

  Inventory({
    required this.flavors,
    required this.extras,
  });

  // Factory: Creates an empty inventory (useful for initial loading state)
  factory Inventory.empty() {
    return Inventory(flavors: {}, extras: {});
  }

  // Factory: Converts Firestore data (Map<String, dynamic>) into our clean Inventory object
  factory Inventory.fromSnapshot(DocumentSnapshot snapshot) {
    if (!snapshot.exists || snapshot.data() == null) {
      return Inventory.empty();
    }

    final data = snapshot.data() as Map<String, dynamic>;

    return Inventory(
      // We use Map.from to safely convert the dynamic types from Firebase
      flavors: Map<String, bool>.from(data['flavors'] ?? {}),
      extras: Map<String, bool>.from(data['extras'] ?? {}),
    );
  }

  // Method: Converts our object back to a Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'flavors': flavors,
      'extras': extras,
    };
  }
}