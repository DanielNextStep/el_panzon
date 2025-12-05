import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shared_styles.dart';
import 'models/order_model.dart';
import 'models/inventory_model.dart';
import 'services/firestore_service.dart';
import 'services/printer_service.dart';

class CheckoutScreen extends StatefulWidget {
  final OrderModel order;

  const CheckoutScreen({super.key, required this.order});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FirestoreService _service = FirestoreService();
  final PrinterService _printerService = PrinterService();
  Map<String, double> _priceMap = {};
  bool _isLoading = true;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchPricesAndCalculate();
  }

  void _fetchPricesAndCalculate() {
    _service.getInventoryStream().first.then((items) {
      if (mounted) {
        setState(() {
          _priceMap = {for (var item in items) item.name: item.price};
          _calculateTotal();
          _isLoading = false;
        });
      }
    });
  }

  void _calculateTotal() {
    double total = 0.0;

    widget.order.tacoCounts.forEach((name, qty) {
      total += (_priceMap[name] ?? 0.0) * qty;
    });

    widget.order.simpleExtraCounts.forEach((name, qty) {
      total += (_priceMap[name] ?? 0.0) * qty;
    });

    widget.order.sodaCounts.forEach((name, temps) {
      int qty = (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
      total += (_priceMap[name] ?? 0.0) * qty;
    });

    _totalAmount = total;
  }

  Future<void> _processPayment() async {
    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);

    try {
      // 1. Process Database Transaction (Archive to History & Delete from Active)
      // This ALREADY saves the detailed item breakdown because it copies the entire OrderModel
      await _service.processCheckout(widget.order);

      // 2. Print Receipt
      String printResult = await _printerService.printReceipt(widget.order, _totalAmount);

      if (mounted) {
        Navigator.of(context).pop();

        if (printResult == "Success") {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("¡Cobro exitoso e impreso!"),
                backgroundColor: Colors.green,
              )
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Cobrado, pero error de impresión: $printResult"),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              )
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error al cobrar: $e"),
              backgroundColor: Colors.red,
            )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String headerTitle = widget.order.tableNumber == 0
        ? widget.order.customerName ?? "Para Llevar"
        : "Mesa ${widget.order.tableNumber}";

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const NeumorphicContainer(
                      isCircle: true,
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.close, color: kTextColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    "Cuenta: $headerTitle",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: kTextColor),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: kAccentColor))
                  : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: NeumorphicContainer(
                  borderRadius: 15,
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long, size: 40, color: kAccentColor),
                      const SizedBox(height: 10),
                      const Text("DETALLE DE CONSUMO", style: TextStyle(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const Divider(height: 30),

                      Expanded(
                        child: ListView(
                          children: [
                            ..._buildTicketItems(widget.order.tacoCounts),
                            ..._buildTicketItems(widget.order.simpleExtraCounts),
                            ..._buildSodaItems(widget.order.sodaCounts),
                          ],
                        ),
                      ),

                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("TOTAL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextColor)),
                          Text("\$${_totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kAccentColor)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(30),
              child: GestureDetector(
                onTap: _isLoading ? null : _processPayment,
                child: NeumorphicContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.print, color: Colors.green, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        _isLoading ? "Procesando..." : "COBRAR E IMPRIMIR",
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTicketItems(Map<String, int> items) {
    List<Widget> widgets = [];
    items.forEach((name, qty) {
      double price = _priceMap[name] ?? 0.0;
      double subtotal = price * qty;
      widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$qty x $name", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kTextColor)),
                Text("\$${subtotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor)),
              ],
            ),
          )
      );
    });
    return widgets;
  }

  List<Widget> _buildSodaItems(Map<String, Map<String, int>> items) {
    List<Widget> widgets = [];
    items.forEach((name, temps) {
      int totalQty = (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
      if (totalQty > 0) {
        double price = _priceMap[name] ?? 0.0;
        double subtotal = price * totalQty;
        widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("$totalQty x $name", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kTextColor)),
                  Text("\$${subtotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor)),
                ],
              ),
            )
        );
      }
    });
    return widgets;
  }
}