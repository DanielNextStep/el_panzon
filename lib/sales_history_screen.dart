import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add intl package to pubspec.yaml if needed, or use manual formatting
import 'shared_styles.dart';
import 'models/order_model.dart';
import 'services/firestore_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final dateStr = "${order.timestamp.day}/${order.timestamp.month}/${order.timestamp.year}";
    final timeStr = "${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')}";

    String title = order.tableNumber == 0
        ? (order.customerName ?? "Para Llevar")
        : "Mesa ${order.tableNumber}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
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
            // We can add a summary here, e.g. "5 Tacos, 2 Sodas"
            // For now, let's show total items count
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 16, color: kAccentColor),
                const SizedBox(width: 5),
                Text("${order.totalItems} Artículos", style: const TextStyle(fontWeight: FontWeight.w600, color: kTextColor)),
              ],
            )
          ],
        ),
      ),
    );
  }
}