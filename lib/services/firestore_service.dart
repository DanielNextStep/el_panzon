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
    required String personId,
    required int itemIndex,
    required String itemName,
  }) async {
    final invQuery = await _inventoryCollection.where('name', isEqualTo: itemName).limit(1).get();
    DocumentReference? inventoryRef;
    if (invQuery.docs.isNotEmpty) {
      inventoryRef = invQuery.docs.first.reference;
    }

    return _db.runTransaction((transaction) async {
      final orderRef = _ordersRef.doc(orderId);
      final orderSnapshot = await transaction.get(orderRef);

      DocumentSnapshot? invSnapshot;
      if (inventoryRef != null) {
        invSnapshot = await transaction.get(inventoryRef);
      }

      if (!orderSnapshot.exists) return;

      final order = OrderModel.fromSnapshot(orderSnapshot);
      final person = order.people[personId];
      if (person == null) return;
      if (itemIndex >= person.items.length) return;

      final item = person.items[itemIndex];
      int currentServed = item.extras['served'] ?? 0;

      // Calculate remaining quantity to serve
      int remainingToServe = item.quantity - currentServed;

      if (remainingToServe > 0) {
        // Update Order - Mark fully served
        Map<String, dynamic> newExtras = Map.from(item.extras);
        newExtras['served'] = item.quantity; // Set served = full quantity

        List<Map<String, dynamic>> updatedItems = person.items.map((i) => i.toMap()).toList();
        updatedItems[itemIndex]['extras'] = newExtras;

        transaction.update(orderRef, {
          'people.$personId.items': updatedItems
        });

        // Deduct Inventory by the *remaining* amount
        if (invSnapshot != null && invSnapshot.exists) {
          final data = invSnapshot.data() as Map<String, dynamic>;
          int currentStock = data['currentStock'] ?? 0;
          int initialStock = data['initialStock'] ?? 0;

          if (currentStock >= remainingToServe && initialStock > 0) {
            transaction.update(inventoryRef!, {'currentStock': currentStock - remainingToServe});
          }
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