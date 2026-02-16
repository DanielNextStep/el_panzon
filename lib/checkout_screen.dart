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
    
    // Calculate total from People (SERVED ONLY)
    if (widget.order.people.isNotEmpty) {
      widget.order.people.forEach((_, person) {
        for (var item in person.items) {
          int served = item.extras['served'] ?? 0;
          total += (_priceMap[item.name] ?? 0.0) * served;
        }
      });
    } else {
      // Fallback for legacy data (Use served maps)
      widget.order.tacoServed.forEach((name, qty) {
        total += (_priceMap[name] ?? 0.0) * qty;
      });
      widget.order.simpleExtraServed.forEach((name, qty) {
        total += (_priceMap[name] ?? 0.0) * qty;
      });
      widget.order.sodaServed.forEach((name, temps) {
        int qty = (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
        total += (_priceMap[name] ?? 0.0) * qty;
      });
    }

    _totalAmount = total;
  }

  Future<void> _processPayment() async {
    if (_totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No hay nada servido para cobrar"), backgroundColor: Colors.orange)
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);

    try {
      // 1. Process Database Transaction
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
                      const Text("DETALLE DE CONSUMO (SERVIDO)", style: TextStyle(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const Divider(height: 30),

                      Expanded(
                        child: ListView(
                          children: [
                            if (widget.order.people.isNotEmpty)
                              ...widget.order.people.values.map((person) => _buildPersonSection(person))
                            else ...[
                              // Legacy Fallback (Hidden for now/assuming migration)
                              const Center(child: Text("Formato antiguo - No soportado para desglose servido completo")),
                            ]
                          ],
                        ),
                      ),

                      const Divider(height: 30),
                      if (_totalAmount == 0)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text("Nada servido aún", style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("TOTAL PACIAL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextColor)),
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
                onTap: _isLoading || _totalAmount <= 0 ? null : _processPayment,
                child: NeumorphicContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.print, color: _totalAmount > 0 ? Colors.green : Colors.grey, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        _isLoading ? "Procesando..." : "COBRAR E IMPRIMIR",
                        style: TextStyle(
                            color: _totalAmount > 0 ? Colors.green : Colors.grey,
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

  Widget _buildPersonSection(PersonOrder person) {
    // Filter only items that have SOME served amount
    final servedItems = person.items.where((i) => (i.extras['served'] ?? 0) > 0).toList();
    if (servedItems.isEmpty) return const SizedBox.shrink();

    double personTotal = 0.0;
    for (var item in servedItems) {
      int served = item.extras['served'] ?? 0;
      personTotal += (_priceMap[item.name] ?? 0.0) * served;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kAccentColor)),
              Text("\$${personTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            ],
          ),
          const Divider(height: 10, thickness: 0.5),
          ...servedItems.map((item) {
             int served = item.extras['served'] ?? 0;
             double subtotal = (_priceMap[item.name] ?? 0.0) * served;
             return Padding(
               padding: const EdgeInsets.symmetric(vertical: 2),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text("$served x ${item.name}", style: const TextStyle(fontSize: 14, color: kTextColor)),
                   Text("\$${subtotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextColor)),
                 ],
               ),
             );
          }),
        ],
      ),
    );
  }

  // --- LEGACY HELPERS ---
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