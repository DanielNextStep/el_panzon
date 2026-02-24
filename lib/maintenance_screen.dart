import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shared_styles.dart';
import 'services/firestore_service.dart';
import 'services/printer_service.dart';
import 'models/inventory_model.dart';
import 'daily_closure_dialog.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  void _showPrinterConfig(BuildContext context) async {
    final TextEditingController ipController = TextEditingController();
    final PrinterService printerService = PrinterService();
    try {
      ipController.text = await printerService.getStoredIp();
    } catch (e) {
      ipController.text = "192.168.1.200";
    }

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: kBackgroundColor,
            title: const Text("Configurar Impresora", style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("IP de Impresora (Compartida):", style: TextStyle(color: kTextColor)),
                const SizedBox(height: 15),
                NeumorphicContainer(
                  isInner: true,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: TextField(
                    controller: ipController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: InputBorder.none, hintText: "Ej. 192.168.1.200"),
                  ),
                ),
                const SizedBox(height: 10),
                const Text("Nota: Este cambio afectará a todos los dispositivos.", style: TextStyle(fontSize: 12, color: Colors.orange)),
              ],
            ),
            actions: [
              TextButton(child: const Text("Cancelar", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(context)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
                child: const Text("Guardar", style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  await printerService.savePrinterIp(ipController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("IP Global actualizada: ${ipController.text}")));
                  }
                },
              )
            ],
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: StreamBuilder<List<InventoryItem>>(
                stream: FirestoreService().getInventoryStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kAccentColor));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final items = snapshot.data!;

                  final tacos = items.where((i) => i.type == 'taco').toList();
                  final sodas = items.where((i) => i.type == 'soda').toList();
                  final extras = items.where((i) => i.type == 'extra').toList();

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (tacos.isNotEmpty) ...[
                        _buildSectionHeader("Tacos"),
                        ...tacos.map((i) => _InventoryItemCard(item: i)),
                        const SizedBox(height: 20),
                      ],
                      if (extras.isNotEmpty) ...[
                        _buildSectionHeader("Postres y Extras"),
                        ...extras.map((i) => _InventoryItemCard(item: i)),
                        const SizedBox(height: 20),
                      ],
                      if (sodas.isNotEmpty) ...[
                        _buildSectionHeader("Bebidas"),
                        ...sodas.map((i) => _InventoryItemCard(item: i)),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(title, style: const TextStyle(color: kTextColor, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("No hay items en el inventario"),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              FirestoreService().resetInventoryToDefaults();
            },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
            child: const Text("Cargar Menú Default", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const NeumorphicContainer(isCircle: true, padding: EdgeInsets.all(12), child: Icon(Icons.arrow_back_ios_new, color: kAccentColor, size: 20)),
          ),
          const SizedBox(width: 20),
          const Expanded(child: Text('Inventario', style: TextStyle(color: kTextColor, fontSize: 20, fontWeight: FontWeight.w700))),
          
          // --- Nuevo Día Button ---
          IconButton(
            icon: const Icon(Icons.wb_sunny, color: Colors.orange),
            tooltip: "Iniciar Nuevo Día",
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Iniciar Nuevo Día"),
                    content: const Text("¿Estás seguro de que deseas reiniciar la producción de todas las carnes y bebidas a 0?\n\nEsta acción no se puede deshacer."),
                    actions: [
                      TextButton(
                        child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("Reiniciar a 0", style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await FirestoreService().resetDailyProduction();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Producción reiniciada para un nuevo día"), backgroundColor: Colors.green),
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          
          // --- Cierre de Día Button ---
          IconButton(
             icon: const Icon(Icons.point_of_sale, color: Colors.green),
             tooltip: "Cierre de Día",
             onPressed: () {
                showDialog(
                   context: context,
                   builder: (context) => const DailyClosureDialog()
                );
             }
          ),
          // -----------------------
          
          IconButton(icon: const Icon(Icons.print, color: kAccentColor), tooltip: "Configurar Impresora", onPressed: () => _showPrinterConfig(context)),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined, color: kAccentColor),
            tooltip: "Restaurar Menú",
            onPressed: () {
              FirestoreService().resetInventoryToDefaults(forceUpdate: true);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menú restaurado a valores por defecto")));
            },
          )
        ],
      ),
    );
  }
}

class _InventoryItemCard extends StatefulWidget {
  final InventoryItem item;
  const _InventoryItemCard({required this.item});
  @override
  State<_InventoryItemCard> createState() => _InventoryItemCardState();
}

class _InventoryItemCardState extends State<_InventoryItemCard> {
  late TextEditingController _priceController;
  late TextEditingController _initialStockController; // Changed name to reflect new logic
  late bool _isActive;
  final FirestoreService _service = FirestoreService();
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.item.price.toStringAsFixed(2));
    _initialStockController = TextEditingController(text: widget.item.initialStock.toString());
    _isActive = widget.item.isActive;
  }

  @override
  void didUpdateWidget(_InventoryItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item != oldWidget.item) {
      _priceController.text = widget.item.price.toStringAsFixed(2);
      if (!_isDirty) {
        _initialStockController.text = widget.item.initialStock.toString();
      }
      _isActive = widget.item.isActive;
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  void _saveChanges() {
    final newPrice = double.tryParse(_priceController.text) ?? 0.0;
    final newInitialStock = int.tryParse(_initialStockController.text) ?? 0;

    // When manually setting stock in Maintenance, we reset 'Current' to match 'Initial'
    // This allows refilling the stock for the day.
    final newCurrentStock = newInitialStock;

    final updatedItem = InventoryItem(
      id: widget.item.id,
      name: widget.item.name,
      type: widget.item.type,
      price: newPrice,
      currentStock: newCurrentStock,
      initialStock: newInitialStock,
      isActive: _isActive,
    );

    _service.updateInventoryItem(updatedItem);

    setState(() {
      _isDirty = false;
    });

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${widget.item.name} actualizado"), backgroundColor: Colors.green, duration: const Duration(milliseconds: 800)));
  }

  bool get _requiresProductionInput {
    if (widget.item.type == 'taco') return true;
    if (widget.item.name == 'Arroz con leche') return true;
    if (widget.item.name == 'Café de Olla') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.all(15),
        child: Opacity(
          opacity: _isActive ? 1.0 : 0.6,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kBackgroundColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white, offset: const Offset(-2, -2), blurRadius: 2), BoxShadow(color: kShadowColor.withOpacity(0.2), offset: const Offset(2, 2), blurRadius: 2)]),
                    child: _getIconForType(widget.item.type),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isActive ? kTextColor : Colors.grey)),
                        Text(widget.item.type.toUpperCase(), style: TextStyle(color: kTextColor.withOpacity(0.5), fontSize: 12, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _isActive,
                      activeColor: kAccentColor,
                      onChanged: (val) {
                        setState(() {
                          _isActive = val;
                          _isDirty = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.only(left: 4, bottom: 4), child: Text("PRECIO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                        NeumorphicContainer(
                          isInner: true,
                          borderRadius: 10,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Row(
                            children: [
                              const Text("\$", style: TextStyle(fontWeight: FontWeight.bold, color: kAccentColor)),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor), onChanged: (_) => _markDirty())),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  if (_requiresProductionInput) ...[
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(padding: EdgeInsets.only(left: 4, bottom: 4), child: Text("PROD. HOY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                          NeumorphicContainer(
                            isInner: true,
                            borderRadius: 10,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Row(
                              children: [
                                const Text("#", style: TextStyle(fontWeight: FontWeight.bold, color: kAccentColor)),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(controller: _initialStockController, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor), onChanged: (_) => _markDirty())),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                  ] else ...[
                    const Spacer(flex: 4),
                    const SizedBox(width: 15),
                  ],
                  GestureDetector(
                    onTap: _isDirty ? _saveChanges : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _isDirty ? Colors.green : kBackgroundColor, shape: BoxShape.circle, boxShadow: _isDirty ? [] : [BoxShadow(color: Colors.white, offset: const Offset(-2, -2), blurRadius: 2), BoxShadow(color: kShadowColor.withOpacity(0.2), offset: const Offset(2, 2), blurRadius: 2)]),
                      child: Icon(Icons.save, color: _isDirty ? Colors.white : Colors.grey.withOpacity(0.3), size: 20),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'taco': return const Icon(Icons.local_pizza, color: kAccentColor, size: 24);
      case 'soda': return const Icon(Icons.local_drink, color: kAccentColor, size: 24);
      case 'extra': return const Icon(Icons.icecream, color: kAccentColor, size: 24);
      default: return const Icon(Icons.fastfood, color: kAccentColor, size: 24);
    }
  }
}