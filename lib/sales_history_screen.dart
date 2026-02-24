import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add intl package to pubspec.yaml if needed, or use manual formatting
import 'shared_styles.dart';
import 'models/order_model.dart';
import 'services/firestore_service.dart';
import 'services/printer_service.dart'; // Added Printer Service

class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const NeumorphicContainer(
                      isCircle: true,
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_back_ios_new, color: kAccentColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text(
                    "Historial de Ventas",
                    style: TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: FirestoreService().getSalesHistoryStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kAccentColor));
                  }

                  final sales = snapshot.data ?? [];

                  if (sales.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history, size: 60, color: kShadowColor),
                          const SizedBox(height: 15),
                          Text(
                            "No hay ventas registradas",
                            style: TextStyle(color: kTextColor.withOpacity(0.7), fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      return _SaleCard(order: sales[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final OrderModel order;

  const _SaleCard({required this.order});

  void _showOrderDetailsDialog(BuildContext context) {
    final dateStr = "${order.timestamp.day}/${order.timestamp.month}/${order.timestamp.year}";
    final timeStr = "${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')}";
    String title = order.tableNumber == 0
        ? (order.customerName ?? "Para Llevar")
        : "Mesa ${order.tableNumber}";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Ensures rounded corners show
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: kBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.75, // Cover 75% of screen
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Handle
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: kTextColor)),
                      Text("Orden #${order.orderNumber}", style: TextStyle(color: kTextColor.withOpacity(0.6), fontSize: 14)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextColor)),
                      Text(timeStr, style: TextStyle(color: kTextColor.withOpacity(0.6), fontSize: 12)),
                    ],
                  )
                ],
              ),
              const Divider(height: 30),

              // Order Items Details List
              Expanded(
                child: ListView(
                  children: [
                    if (order.people.isEmpty)
                      const Center(child: Text("Sin detalles específicos.", style: TextStyle(color: Colors.grey)))
                    else
                      ...order.people.entries.map((entry) {
                        final person = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 5),
                              ...person.items.map((item) {
                                // Provide historical items display (note: prices might be out of date if changed globally, 
                                // but we display quantities here accurately).
                                return Padding(
                                  padding: const EdgeInsets.only(left: 10, bottom: 4),
                                  child: Row(
                                    children: [
                                      Text("${item.quantity}x ", style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Expanded(child: Text(item.name)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const Divider(height: 20),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),

              // Action Buttons
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  // Fetch live inventory for prices
                  final items = await FirestoreService().getInventoryStream().first;
                  final priceMap = {for (var item in items) item.name: item.price};
                  
                  // Calculate total dynamically based on historical quantities and current prices
                  double total = 0.0;
                  order.people.forEach((key, person) {
                    for (var item in person.items) {
                      double price = priceMap[item.name] ?? 0.0;
                      if (item.name == 'Desechables') price = 2.0; 
                      total += price * item.quantity;
                    }
                  });
                  
                  // Fallback for legacy items in history
                  order.tacoCounts.forEach((n, q) => total += (priceMap[n] ?? 0) * q);
                  order.simpleExtraCounts.forEach((n, q) => total += (priceMap[n] ?? 0) * q);
                  order.sodaCounts.forEach((n, temps) => temps.forEach((temp, q) => total += (priceMap[n] ?? 0) * q));

                  await PrinterService().printReceipt(order, total, priceMap);
                  if (context.mounted) {
                    Navigator.pop(context); // Close sheet
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Re-impresión enviada")),
                    );
                  }
                },
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text("Re-imprimir Ticket", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = "${order.timestamp.day}/${order.timestamp.month}/${order.timestamp.year}";
    final timeStr = "${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')}";

    String title = order.tableNumber == 0
        ? (order.customerName ?? "Para Llevar")
        : "Mesa ${order.tableNumber}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: () => _showOrderDetailsDialog(context),
        child: NeumorphicContainer(
          borderRadius: 15,
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextColor)),
                      Text("Orden #${order.orderNumber}", style: TextStyle(color: kTextColor.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextColor)),
                      Text(timeStr, style: TextStyle(color: kTextColor.withOpacity(0.6), fontSize: 12)),
                    ],
                  )
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 16, color: kAccentColor),
                      const SizedBox(width: 5),
                      Text("${order.totalItems} Artículos", style: const TextStyle(fontWeight: FontWeight.w600, color: kTextColor)),
                    ],
                  ),
                  const Text("Ver detalles ➜", style: TextStyle(color: kAccentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}