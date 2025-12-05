import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Required for Timer
import 'shared_styles.dart';
import 'models/order_model.dart';
import 'services/firestore_service.dart';
import 'checkout_screen.dart';

class OpenOrdersScreen extends StatefulWidget {
  const OpenOrdersScreen({super.key});

  @override
  State<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends State<OpenOrdersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: FirestoreService().getAllActiveOrdersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kAccentColor));
                  }

                  // 1. Get all orders
                  final allOrders = List<OrderModel>.from(snapshot.data ?? []);

                  // 2. FIFO RULE: Sort strictly by timestamp (Oldest first)
                  allOrders.sort((a, b) => a.timestamp.compareTo(b.timestamp));

                  // 3. Consolidated View
                  return _OrdersListView(
                    orders: allOrders,
                    title: "Órdenes Activas",
                    emptyIcon: Icons.restaurant,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const NeumorphicContainer(
              isCircle: true,
              padding: EdgeInsets.all(12),
              child: Icon(Icons.arrow_back_ios_new, color: kAccentColor, size: 20),
            ),
          ),
          const Text(
            'Cocina / Servicio',
            style: TextStyle(color: kTextColor, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _OrdersListView extends StatelessWidget {
  final List<OrderModel> orders;
  final String title;
  final IconData emptyIcon;

  const _OrdersListView({
    required this.orders,
    required this.title,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    final active = orders.where((o) => !o.isFullyServed).toList();
    final completed = orders.where((o) => o.isFullyServed).toList();

    if (active.isEmpty && completed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 60, color: kShadowColor),
            const SizedBox(height: 15),
            Text(
              "No hay órdenes pendientes",
              style: TextStyle(color: kTextColor.withOpacity(0.7), fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        if (active.isNotEmpty)
          ...active.map((order) => _OrderServiceCard(
              key: ValueKey(order.id),
              order: order
          )),

        if (completed.isNotEmpty) ...[
          const SizedBox(height: 20),
          NeumorphicContainer(
            borderRadius: 15,
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: kTextColor,
              collapsedIconColor: kTextColor,
              title: Text(
                "Listos para Cobrar - ${completed.length}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor),
              ),
              children: completed.map((order) =>
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _OrderServiceCard(
                          key: ValueKey(order.id),
                          order: order,
                          isHistory: true
                      )
                  )
              ).toList(),
            ),
          ),
          const SizedBox(height: 40),
        ]
      ],
    );
  }
}

class _OrderServiceCard extends StatefulWidget {
  final OrderModel order;
  final bool isHistory;

  const _OrderServiceCard({
    super.key,
    required this.order,
    this.isHistory = false
  });

  @override
  State<_OrderServiceCard> createState() => _OrderServiceCardState();
}

class _OrderServiceCardState extends State<_OrderServiceCard> {
  final FirestoreService _service = FirestoreService();
  Timer? _timer;
  String _timeElapsed = '';

  @override
  void initState() {
    super.initState();
    _updateTimeElapsed();
    if (!widget.isHistory) {
      _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (mounted) {
          _updateTimeElapsed();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_OrderServiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.timestamp != widget.order.timestamp) {
      _updateTimeElapsed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimeElapsed() {
    final duration = DateTime.now().difference(widget.order.timestamp);
    setState(() {
      if (duration.inMinutes == 0) {
        _timeElapsed = 'Ahora';
      } else {
        _timeElapsed = '${duration.inMinutes} min';
      }
    });
  }

  Future<void> _serveItem(String type, String name, {String? subType}) async {
    if (widget.isHistory) return;

    HapticFeedback.lightImpact();
    await _service.serveItemAndDeductStock(
        orderId: widget.order.id!,
        itemType: type,
        itemName: name,
        sodaSubType: subType
    );
  }

  void _goToCheckout() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => CheckoutScreen(order: widget.order))
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = "${widget.order.timestamp.hour}:${widget.order.timestamp.minute.toString().padLeft(2, '0')}";

    String headerTitle;
    IconData headerIcon;
    Color iconColor;

    if (widget.order.tableNumber == 0) {
      headerTitle = widget.order.customerName ?? 'Para Llevar';
      headerIcon = Icons.shopping_bag;
      iconColor = Colors.orange;
    } else {
      headerTitle = "Mesa ${widget.order.tableNumber}";
      headerIcon = Icons.table_restaurant;
      iconColor = kAccentColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeumorphicContainer(
        borderRadius: 15,
        child: Opacity(
          opacity: widget.isHistory ? 1.0 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(headerIcon, color: iconColor, size: 22),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            headerTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.order.tableNumber > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            "(#${widget.order.orderNumber})",
                            style: TextStyle(color: kTextColor.withOpacity(0.6), fontSize: 14),
                          ),
                        ]
                      ],
                    ),
                  ),

                  // --- Time Display ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          timeStr,
                          style: TextStyle(color: kTextColor.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 12)
                      ),
                      if (!widget.isHistory)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time, size: 12, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                _timeElapsed,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // --- DISPLAY SELECTED SALSAS (Multiple) ---
              if (widget.order.salsas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_fire_department, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Salsas: ${widget.order.salsas.join(', ')}",
                        style: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold, fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                )
              ],

              const Divider(height: 20, color: kShadowColor),

              if (widget.order.tacoCounts.isEmpty && widget.order.simpleExtraCounts.isEmpty && widget.order.sodaCounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Orden Vacía", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ),

              ...widget.order.tacoCounts.entries.map((e) => _buildRow('taco', e.key, e.value, widget.order.tacoServed[e.key] ?? 0)),
              ...widget.order.simpleExtraCounts.entries.map((e) => _buildRow('extra', e.key, e.value, widget.order.simpleExtraServed[e.key] ?? 0)),
              ..._buildSodaRows(),

              // --- CHECKOUT BUTTON (Visible if history/completed) ---
              if (widget.isHistory) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _goToCheckout,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: Colors.green.withOpacity(0.3), offset: const Offset(0, 4), blurRadius: 6)
                        ]
                    ),
                    child: const Center(
                      child: Text(
                          "COBRAR",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                      ),
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSodaRows() {
    List<Widget> rows = [];
    widget.order.sodaCounts.forEach((flavor, temps) {
      if (temps['Frío']! > 0) {
        int served = widget.order.sodaServed[flavor]?['Frío'] ?? 0;
        rows.add(_buildRow('soda', "$flavor (Frío)", temps['Frío']!, served, realName: flavor, subType: 'Frío'));
      }
      if (temps['Al Tiempo']! > 0) {
        int served = widget.order.sodaServed[flavor]?['Al Tiempo'] ?? 0;
        rows.add(_buildRow('soda', "$flavor (Tiempo)", temps['Al Tiempo']!, served, realName: flavor, subType: 'Al Tiempo'));
      }
    });
    return rows;
  }

  Widget _buildRow(String type, String label, int ordered, int served, {String? realName, String? subType}) {
    bool isFullyServed = served >= ordered;
    int pending = ordered - served;

    return GestureDetector(
      onTap: isFullyServed ? null : () => _serveItem(type, realName ?? label, subType: subType),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: isFullyServed
                ? Colors.green.withOpacity(0.08)
                : kBackgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFullyServed ? Colors.transparent : kShadowColor.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: isFullyServed ? null : [
              BoxShadow(color: Colors.white, offset: const Offset(-2, -2), blurRadius: 2),
              BoxShadow(color: kShadowColor.withOpacity(0.2), offset: const Offset(2, 2), blurRadius: 2),
            ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isFullyServed ? FontWeight.normal : FontWeight.w700,
                    color: isFullyServed ? Colors.green.withOpacity(0.7) : kTextColor,
                    decoration: isFullyServed ? TextDecoration.lineThrough : null,
                  )
              ),
            ),
            Row(
              children: [
                if (!isFullyServed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                        color: kAccentColor,
                        borderRadius: BorderRadius.circular(12)
                    ),
                    child: Text(
                        "Faltan $pending",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                    ),
                  ),

                Icon(
                  isFullyServed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isFullyServed ? Colors.green : kAccentColor,
                  size: 24,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}