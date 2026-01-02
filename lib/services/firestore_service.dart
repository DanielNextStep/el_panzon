import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_model.dart';
import '../models/order_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- COLLECTIONS ---
  CollectionReference get _ordersRef => _db.collection('orders');
  CollectionReference get _inventoryCollection => _db.collection('inventory_items');
  CollectionReference get _salesRef => _db.collection('sales');

  // --- INVENTORY METHODS ---

  Stream<List<InventoryItem>> getInventoryStream() {
    return _inventoryCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => InventoryItem.fromSnapshot(doc)).toList();
    });
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    await _inventoryCollection.doc(item.id).update(item.toMap());
  }

  Future<void> initializeDefaultInventoryIfEmpty() async {
    final snapshot = await _inventoryCollection.limit(1).get();
    if (snapshot.docs.isEmpty) {
      await resetInventoryToDefaults();
    }
  }

  Future<void> resetInventoryToDefaults({bool forceUpdate = false}) async {
    // Note: 'currentStock' starts equal to 'initialStock'
    final defaults = [
      {'name': 'Chicharron', 'type': 'taco', 'price': 18.0, 'currentStock': 100, 'initialStock': 100, 'isActive': true},
      {'name': 'Frijol con Chorizo', 'type': 'taco', 'price': 18.0, 'currentStock': 100, 'initialStock': 100, 'isActive': true},
      {'name': 'Papa', 'type': 'taco', 'price': 18.0, 'currentStock': 100, 'initialStock': 100, 'isActive': true},
      {'name': 'Carnitas en Morita', 'type': 'taco', 'price': 22.0, 'currentStock': 80, 'initialStock': 80, 'isActive': true},
      {'name': 'Huevo en Pasilla', 'type': 'taco', 'price': 18.0, 'currentStock': 80, 'initialStock': 80, 'isActive': true},
      {'name': 'Tinga', 'type': 'taco', 'price': 20.0, 'currentStock': 80, 'initialStock': 80, 'isActive': true},
      {'name': 'Adobo', 'type': 'taco', 'price': 20.0, 'currentStock': 80, 'initialStock': 80, 'isActive': true},
      {'name': 'Arroz con leche', 'type': 'extra', 'price': 25.0, 'currentStock': 40, 'initialStock': 40, 'isActive': true},
      {'name': 'Café de Olla', 'type': 'soda', 'price': 20.0, 'currentStock': 50, 'initialStock': 50, 'isActive': true},
      {'name': 'Coca', 'type': 'soda', 'price': 25.0, 'currentStock': 0, 'initialStock': 0, 'isActive': true},
      {'name': 'Boing de Mango', 'type': 'soda', 'price': 22.0, 'currentStock': 0, 'initialStock': 0, 'isActive': true},
      {'name': 'Boing de Guayaba', 'type': 'soda', 'price': 22.0, 'currentStock': 0, 'initialStock': 0, 'isActive': true},
      {'name': 'Agua Embotellada', 'type': 'soda', 'price': 15.0, 'currentStock': 0, 'initialStock': 0, 'isActive': true},
      {'name': 'Té', 'type': 'soda', 'price': 15.0, 'currentStock': 0, 'initialStock': 0, 'isActive': true},
      {'name': 'Cafe Soluble', 'type': 'soda', 'price': 18.0, 'currentStock': 0, 'initialStock': 0, 'isActive': true},
    ];

    for (var map in defaults) {
      final query = await _inventoryCollection.where('name', isEqualTo: map['name']).get();
      if (query.docs.isEmpty) {
        await _inventoryCollection.add(map);
      } else if (forceUpdate) {
        await query.docs.first.reference.update(map);
      }
    }
  }

  // --- ORDER METHODS ---

  Future<void> addOrder(OrderModel order) async {
    await _ordersRef.add(order.toMap());
  }

  Future<void> updateOrder(OrderModel order) async {
    if (order.id != null) {
      await _ordersRef.doc(order.id).update(order.toMap());
    }
  }

  // --- TRANSACTIONAL SERVICE ---
  Future<void> serveItemAndDeductStock({
    required String orderId,
    required String itemType,
    required String itemName,
    String? sodaSubType,
  }) async {
    final invQuery = await _inventoryCollection.where('name', isEqualTo: itemName).limit(1).get();
    DocumentReference? inventoryRef;
    if (invQuery.docs.isNotEmpty) {
      inventoryRef = invQuery.docs.first.reference;
    }

    return _db.runTransaction((transaction) async {
      print("Starting transaction for $itemName...");

      // READS
      final orderRef = _ordersRef.doc(orderId);
      final orderSnapshot = await transaction.get(orderRef);

      DocumentSnapshot? invSnapshot;
      if (inventoryRef != null) {
        invSnapshot = await transaction.get(inventoryRef);
      }

      if (!orderSnapshot.exists) {
        print("Transaction Aborted: Order not found");
        return;
      }

      // LOGIC
      final order = OrderModel.fromSnapshot(orderSnapshot);
      Map<String, dynamic> updateData = {};
      bool shouldUpdateOrder = false;

      if (itemType == 'taco') {
        final currentMap = Map<String, int>.from(order.tacoServed);
        int currentCount = currentMap[itemName] ?? 0;
        int maxCount = order.tacoCounts[itemName] ?? 0;

        if (currentCount < maxCount) {
          currentMap[itemName] = currentCount + 1;
          updateData['tacoServed'] = currentMap;
          shouldUpdateOrder = true;
        }
      } else if (itemType == 'extra') {
        final currentMap = Map<String, int>.from(order.simpleExtraServed);
        int currentCount = currentMap[itemName] ?? 0;
        int maxCount = order.simpleExtraCounts[itemName] ?? 0;

        if (currentCount < maxCount) {
          currentMap[itemName] = currentCount + 1;
          updateData['simpleExtraServed'] = currentMap;
          shouldUpdateOrder = true;
        }
      } else if (itemType == 'soda' && sodaSubType != null) {
        final currentMap = Map<String, Map<String, dynamic>>.from(order.sodaServed);
        if (!currentMap.containsKey(itemName)) {
          currentMap[itemName] = {'Frío': 0, 'Al Tiempo': 0};
        }

        final innerMap = Map<String, int>.from(currentMap[itemName]!.cast<String, int>());
        int currentCount = innerMap[sodaSubType] ?? 0;
        int maxCount = order.sodaCounts[itemName]?[sodaSubType] ?? 0;

        if (currentCount < maxCount) {
          innerMap[sodaSubType] = currentCount + 1;
          currentMap[itemName] = innerMap;
          updateData['sodaServed'] = currentMap;
          shouldUpdateOrder = true;
        }
      }

      if (!shouldUpdateOrder) {
        print("Transaction Aborted: No updates needed");
        return;
      }

      // WRITES
      transaction.update(orderRef, updateData);

      if (invSnapshot != null && invSnapshot.exists) {
        final data = invSnapshot.data() as Map<String, dynamic>;

        // Use 'currentStock' logic
        int currentStock = data['currentStock'] ?? data['dailyProduction'] ?? 0;
        int initialStock = data['initialStock'] ?? 0;

        // Decrease if tracking is enabled (initialStock > 0) AND stock is available
        if (currentStock > 0 && initialStock > 0) {
          transaction.update(inventoryRef!, {'currentStock': currentStock - 1});
        }
      }
    });
  }

  // --- CHECKOUT LOGIC ---
  Future<void> processCheckout(OrderModel order) async {
    Map<String, dynamic> salesData = order.toMap();
    salesData['closedAt'] = FieldValue.serverTimestamp();
    await _salesRef.add(salesData);
    await _ordersRef.doc(order.id).delete();
  }

  Stream<List<OrderModel>> getOrdersForTable(int tableNumber) {
    return _ordersRef
        .where('tableNumber', isEqualTo: tableNumber)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromSnapshot(doc)).toList();
    });
  }

  Stream<List<OrderModel>> getAllActiveOrdersStream() {
    return _ordersRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromSnapshot(doc)).toList();
    });
  }

  Stream<List<OrderModel>> getSalesHistoryStream() {
    return _salesRef
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromSnapshot(doc)).toList();
    });
  }

  Stream<Set<int>> getBusyTablesStream() {
    return _ordersRef.snapshots().map((snapshot) {
      final busyTables = <int>{};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tableNum = data['tableNumber'] as int?;
        if (tableNum != null && tableNum > 0) {
          busyTables.add(tableNum);
        }
      }
      return busyTables;
    });
  }
}