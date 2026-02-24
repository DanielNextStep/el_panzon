import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/order_model.dart';
import 'models/inventory_model.dart';
import 'services/firestore_service.dart';
import 'services/printer_service.dart';
import 'shared_styles.dart';

class DailyClosureDialog extends StatefulWidget {
  const DailyClosureDialog({super.key});

  @override
  State<DailyClosureDialog> createState() => _DailyClosureDialogState();
}

class _DailyClosureDialogState extends State<DailyClosureDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  final PrinterService _printerService = PrinterService();

  bool _isLoading = true;
  double _totalRevenue = 0.0;
  
  // Breakdown Maps
  Map<String, int> _tacoCounts = {};
  Map<String, int> _extraCounts = {};

  @override
  void initState() {
    super.initState();
    _calculateClosure();
  }

  Future<void> _calculateClosure() async {
    try {
      final List<OrderModel> todaysOrders = await _firestoreService.getTodaysSales();
      final items = await _firestoreService.getInventoryStream().first;
      final Map<String, double> priceMap = {for (var item in items) item.name: item.price};

      double revenue = 0.0;
      Map<String, int> tacos = {};
      Map<String, int> extras = {};

      for (var order in todaysOrders) {
        if (order.people.isNotEmpty) {
           order.people.forEach((_, person) {
             for (var item in person.items) {
                int served = item.extras['served'] ?? 0;
                if (item.name == 'Desechables') served = item.quantity;

                if (served > 0) {
                   double price = item.name == 'Desechables' ? 2.0 : (priceMap[item.name] ?? 0.0);
                   revenue += price * served;
                   
                   final invItem = items.firstWhere(
                     (i) => i.name == item.name, 
                     orElse: () => InventoryItem(id: '', name: item.name, type: 'extra', price: 0.0)
                   );
                   
                   if (invItem.type == 'taco') {
                     tacos[item.name] = (tacos[item.name] ?? 0) + served;
                   } else {
                     extras[item.name] = (extras[item.name] ?? 0) + served;
                   }
                }
             }
           });
        } 
        else {
           order.tacoCounts.forEach((name, qty) {
              double price = priceMap[name] ?? 0.0;
              revenue += price * qty;
              tacos[name] = (tacos[name] ?? 0) + qty;
           });
           order.simpleExtraCounts.forEach((name, qty) {
              double price = priceMap[name] ?? 0.0;
              revenue += price * qty;
              extras[name] = (extras[name] ?? 0) + qty;
           });
           order.sodaCounts.forEach((name, temps) {
              int qty = (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
              if (qty > 0) {
                double price = priceMap[name] ?? 0.0;
                revenue += price * qty;
                extras[name] = (extras[name] ?? 0) + qty;
              }
           });
        }
      }

      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
          _tacoCounts = tacos;
          _extraCounts = extras;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Error calculating daily closure: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _printClosure() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Enviando a impresora...")),
    );
    
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    
    final result = await _printerService.printDailyClosure(
      _totalRevenue,
      _tacoCounts,
      _extraCounts,
      dateStr,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        backgroundColor: kBackgroundColor,
        content: SizedBox(
          height: 150,
          child: Center(child: CircularProgressIndicator(color: kAccentColor)),
        ),
      );
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return AlertDialog(
      backgroundColor: kBackgroundColor,
      title: Column(
        children: [
          const Icon(Icons.point_of_sale, color: kAccentColor, size: 40),
          const SizedBox(height: 10),
          const Text("Cierre de Día", style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold, fontSize: 22)),
          Text(dateStr, style: TextStyle(color: kTextColor.withOpacity(0.6), fontSize: 14)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(color: kShadowColor),
            
            // List Items (Tacos & Extras)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                   if (_tacoCounts.isNotEmpty) ...[
                     const Padding(
                       padding: EdgeInsets.symmetric(vertical: 8.0),
                       child: Text("TACOS", style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                     ),
                     ..._tacoCounts.entries.map((e) => _buildItemRow(e.key, e.value)),
                     const SizedBox(height: 10),
                   ],
                   
                   if (_extraCounts.isNotEmpty) ...[
                     const Padding(
                       padding: EdgeInsets.symmetric(vertical: 8.0),
                       child: Text("BEBIDAS / EXTRAS", style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                     ),
                     ..._extraCounts.entries.map((e) => _buildItemRow(e.key, e.value)),
                   ],
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            const Divider(color: kShadowColor),
            const SizedBox(height: 10),
            
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("INGRESOS", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("\$${_totalRevenue.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 24)),
                ],
              ),
            )
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        ElevatedButton.icon(
          onPressed: _printClosure,
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccentColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          icon: const Icon(Icons.print, color: Colors.white),
          label: const Text("Imprimir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        )
      ],
    );
  }

  Widget _buildItemRow(String name, int qty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(color: kTextColor, fontSize: 15)),
          Text(qty.toString(), style: const TextStyle(color: kTextColor, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
