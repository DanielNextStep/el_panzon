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
    final defaults = [
      {'name': 'Chicharron', 'type': 'taco', 'price': 18.0, 'dailyProduction': 100, 'isActive': true},
      {'name': 'Frijol con Chorizo', 'type': 'taco', 'price': 18.0, 'dailyProduction': 100, 'isActive': true},
      {'name': 'Papa', 'type': 'taco', 'price': 18.0, 'dailyProduction': 100, 'isActive': true},
      {'name': 'Carnitas en Morita', 'type': 'taco', 'price': 22.0, 'dailyProduction': 80, 'isActive': true},
      {'name': 'Huevo en Pasilla', 'type': 'taco', 'price': 18.0, 'dailyProduction': 80, 'isActive': true},
      {'name': 'Tinga', 'type': 'taco', 'price': 20.0, 'dailyProduction': 80, 'isActive': true},
      {'name': 'Adobo', 'type': 'taco', 'price': 20.0, 'dailyProduction': 80, 'isActive': true},
      {'name': 'Arroz con leche', 'type': 'extra', 'price': 25.0, 'dailyProduction': 40, 'isActive': true},
      {'name': 'Café de Olla', 'type': 'soda', 'price': 20.0, 'dailyProduction': 50, 'isActive': true},
      {'name': 'Coca', 'type': 'soda', 'price': 25.0, 'dailyProduction': 0, 'isActive': true},
      {'name': 'Boing de Mango', 'type': 'soda', 'price': 22.0, 'dailyProduction': 0, 'isActive': true},
      {'name': 'Boing de Guayaba', 'type': 'soda', 'price': 22.0, 'dailyProduction': 0, 'isActive': true},
      {'name': 'Agua Embotellada', 'type': 'soda', 'price': 15.0, 'dailyProduction': 0, 'isActive': true},
      {'name': 'Té', 'type': 'soda', 'price': 15.0, 'dailyProduction': 0, 'isActive': true},
      {'name': 'Cafe Soluble', 'type': 'soda', 'price': 18.0, 'dailyProduction': 0, 'isActive': true},
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
    // 1. Find Inventory Doc Ref (Query outside transaction is allowed/efficient)
    final invQuery = await _inventoryCollection.where('name', isEqualTo: itemName).limit(1).get();
    DocumentReference? inventoryRef;
    if (invQuery.docs.isNotEmpty) {
      inventoryRef = invQuery.docs.first.reference;
    }

    return _db.runTransaction((transaction) async {
      final orderRef = _ordersRef.doc(orderId);

      // --- STEP 1: ALL READS MUST HAPPEN FIRST ---
      final orderSnapshot = await transaction.get(orderRef);

      // We must read the inventory NOW, before writing to orderRef
      DocumentSnapshot? invSnapshot;
      if (inventoryRef != null) {
        invSnapshot = await transaction.get(inventoryRef);
      }

      if (!orderSnapshot.exists) return;

      // --- STEP 2: CALCULATE LOGIC ---
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

      if (!shouldUpdateOrder) return;

      // --- STEP 3: ALL WRITES LAST ---

      // Write 1: Update Order
      transaction.update(orderRef, updateData);

      // Write 2: Deduct Inventory (if applicable)
      if (invSnapshot != null && invSnapshot.exists) {
        final data = invSnapshot.data() as Map<String, dynamic>;
        int currentProd = data['dailyProduction'] ?? 0;
        if (currentProd > 0) {
          transaction.update(inventoryRef!, {'dailyProduction': currentProd - 1});
        }
      }
    });
  }

  // --- CHECKOUT LOGIC (Archive & Delete) ---
  Future<void> processCheckout(OrderModel order) async {
    // 1. Save to Sales History
    Map<String, dynamic> salesData = order.toMap();
    salesData['closedAt'] = FieldValue.serverTimestamp();
    await _salesRef.add(salesData);

    // 2. Delete from Active Orders
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

  // --- SALES HISTORY STREAM ---
  Stream<List<OrderModel>> getSalesHistoryStream() {
    return _salesRef
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromSnapshot(doc)).toList();
    });
  }
}