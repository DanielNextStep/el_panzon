import 'package:flutter/material.dart';

void main() {
  runApp(const TacosApp());
}

class TacosApp extends StatelessWidget {
  const TacosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Panzón Tacos',
      theme: ThemeData(
        primarySwatch: Colors.red,
        textTheme: TextTheme(
          displayLarge: TextStyle(
            fontSize: 48.0,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFE53935),
          ),
          titleLarge: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFE53935),
          ),
          bodyLarge: TextStyle(fontSize: 18.0, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 16.0, color: Colors.black54),
          labelLarge: TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          labelMedium: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFE53935),
          ),
          labelSmall: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.normal,
            color: const Color(0xFFE53935).withOpacity(0.7),
          ),
        ),
      ),
      home: const OrderTypeScreen(),
    );
  }
}

enum OrderType { carryOut, table }

class OrderTypeScreen extends StatefulWidget {
  const OrderTypeScreen({super.key});

  @override
  State<OrderTypeScreen> createState() => _OrderTypeScreenState();
}

class _OrderTypeScreenState extends State<OrderTypeScreen> {
  int? _selectedTable;
  OrderType? _selectedOrderType;

  static const double _tableButtonContentHeight = 62.0;
  static const double _tableButtonContentWidth = 62.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC), // Light beige
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5DC),
        elevation: 0,
        toolbarHeight: 120,
        title: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/Logo_Panzon_SF.png',
                height: 90,
                fit: BoxFit.fitHeight,
              ),
              const SizedBox(height: 8),
              Text(
                'Aplicación de Pedidos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 1),

            Text(
              '¿Cómo será tu pedido?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 40),

            // "Para Llevar" Button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedOrderType = OrderType.carryOut;
                  _selectedTable = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pedido para llevar seleccionado!')),
                );
                // After selecting, navigate to taco order screen for carry out
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TacoOrderScreen(
                      orderType: OrderType.carryOut,
                      tableNumber: null,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedOrderType == OrderType.carryOut
                    ? const Color(0xFFE53935)
                    : const Color(0xFFFFCC00),
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Para Llevar',
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: _selectedOrderType == OrderType.carryOut
                      ? Colors.white
                      : const Color(0xFFE53935),
                ),
              ),
            ),
            const SizedBox(height: 30),

            Text(
              'O elige tu mesa',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            // Table Selection Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                final tableNumber = index + 1;
                final isBarra = (tableNumber == 2 || tableNumber == 4);
                final bool isSelected = _selectedTable == tableNumber;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: _tableButtonContentWidth,
                        height: _tableButtonContentHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tableNumber.toString(),
                              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                                color: isSelected ? Colors.white : const Color(0xFFE53935),
                              ),
                            ),
                            if (isBarra)
                              Text(
                                'barra',
                                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                                  color: isSelected
                                      ? Colors.white70
                                      : const Color(0xFFE53935).withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFE53935),
                      backgroundColor: const Color(0xFFFFCC00),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedTable = tableNumber;
                            _selectedOrderType = OrderType.table;
                          } else {
                            if (_selectedTable == tableNumber) {
                              _selectedTable = null;
                              _selectedOrderType = null;
                            }
                          }
                        });
                        if (selected) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Mesa $tableNumber seleccionada!')),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TacoOrderScreen(
                                orderType: OrderType.table,
                                tableNumber: tableNumber,
                              ),
                            ),
                          );
                        }
                      },
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const Spacer(flex: 2),

            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Text(
                'Selecciona tu mesa para ordenar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Model for Taco Flavors
class TacoFlavor {
  final String name;
  int quantity;

  TacoFlavor({required this.name, this.quantity = 0});
}

class TacoOrderScreen extends StatefulWidget {
  final OrderType orderType;
  final int? tableNumber;

  const TacoOrderScreen({
    super.key,
    required this.orderType,
    this.tableNumber,
  });

  @override
  State<TacoOrderScreen> createState() => _TacoOrderScreenState();
}

class _TacoOrderScreenState extends State<TacoOrderScreen> {
  late List<TacoFlavor> _tacoFlavors;

  @override
  void initState() {
    super.initState();
    _tacoFlavors = [
      TacoFlavor(name: 'Chicharrón'),
      TacoFlavor(name: 'Papa'),
      TacoFlavor(name: 'Frijol'),
      TacoFlavor(name: 'Carnitas'),
      TacoFlavor(name: 'Huevo y Pasilla'),
      TacoFlavor(name: 'Adobo'),
      TacoFlavor(name: 'Tinga'),
    ];
  }

  void _updateQuantity(TacoFlavor flavor, int change) {
    setState(() {
      flavor.quantity = (flavor.quantity + change).clamp(0, 99);
    });
  }

  @override
  Widget build(BuildContext context) {
    String headerText = widget.orderType == OrderType.carryOut
        ? 'Pedido para Llevar'
        : 'Pedido Mesa #${widget.tableNumber}';

    String subHeaderText = '';
    if (widget.orderType == OrderType.table && (widget.tableNumber == 2 || widget.tableNumber == 4)) {
      subHeaderText = 'barra';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5DC),
        elevation: 0,
        toolbarHeight: 120,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFE53935)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/Logo_Panzon_SF.png',
                height: 60,
                fit: BoxFit.fitHeight,
              ),
              const SizedBox(height: 4),
              Text(
                headerText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: const Color(0xFFE53935),
                  fontSize: 22,
                ),
              ),
              if (subHeaderText.isNotEmpty)
                Text(
                  subHeaderText,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: const Color(0xFFE53935).withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          const SizedBox(width: 48),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Selecciona tus tacos:',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _tacoFlavors.length,
                itemBuilder: (context, index) {
                  final flavor = _tacoFlavors[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            flavor.name,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        Expanded(
                          flex: 7,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _QuantityButton(
                                text: '-',
                                onPressed: () => _updateQuantity(flavor, -1),
                                isNegative: true,
                              ),
                              Container(
                                width: 60,
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE53935), width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  flavor.quantity.toString(),
                                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                    color: const Color(0xFFE53935),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _QuantityButton(
                                text: '+',
                                onPressed: () => _updateQuantity(flavor, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pedido en progreso...'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 40.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Agregar al Pedido',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isNegative;

  const _QuantityButton({
    required this.text,
    required this.onPressed,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: const Color(0xFFE53935),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.zero,
          backgroundColor: isNegative ? Colors.white : const Color(0xFFFFCC00),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: const Color(0xFFE53935),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
