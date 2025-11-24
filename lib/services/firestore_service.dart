import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_model.dart';
import '../models/order_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- COLLECTIONS ---
  CollectionReference get _configRef => _db.collection('config');
  CollectionReference get _ordersRef => _db.collection('orders');

  DocumentReference get _inventoryRef => _configRef.doc('inventory');

  // --- INVENTORY METHODS ---
  Stream<Inventory> getInventoryStream() {
    return _inventoryRef.snapshots().map((snapshot) {
      return Inventory.fromSnapshot(snapshot);
    });
  }

  Future<void> updateInventory({
    required Map<String, bool> flavors,
    required Map<String, bool> extras,
  }) async {
    final inventory = Inventory(flavors: flavors, extras: extras);
    await _inventoryRef.set(inventory.toMap(), SetOptions(merge: true));
  }

  Future<void> initializeDefaultInventoryIfEmpty() async {
    final doc = await _inventoryRef.get();
    if (!doc.exists) {
      await updateInventory(
        flavors: {
          'Papa': true, 'Frijol de Chorizo': true, 'Chicharron': true,
          'Carnitas': true, 'Huevo en Pasilla': true, 'Adobo': true, 'Tinga': true,
        },
        extras: {
          'Arroz con Leche': true, 'Agua': true, 'Té': true,
          'Cafe Soluble': true, 'Refrescos': true,
        },
      );
    }
  }

  // --- ORDER METHODS ---

  // 1. Add a new order to the cloud
  Future<void> addOrder(OrderModel order) async {
    await _ordersRef.add(order.toMap());
  }

  // 2. Update an existing order (e.g., editing tacos OR marking them as served)
  Future<void> updateOrder(OrderModel order) async {
    if (order.id != null) {
      await _ordersRef.doc(order.id).update(order.toMap());
    }
  }

  // 3. Get a Live Stream of orders for a specific TABLE (For Waiters)
  Stream<List<OrderModel>> getOrdersForTable(int tableNumber) {
    return _ordersRef
        .where('tableNumber', isEqualTo: tableNumber)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromSnapshot(doc)).toList();
    });
  }

  // 4. Get ALL active orders (For the Kitchen/Service View)
  // This is the new method needed for the "Pendientes de Servir" screen
  Stream<List<OrderModel>> getAllActiveOrdersStream() {
    return _ordersRef
        .orderBy('timestamp', descending: true) // Newest orders first
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromSnapshot(doc)).toList();
    });
  }
}