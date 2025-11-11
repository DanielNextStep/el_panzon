import 'package:flutter/material.dart';
import 'shared_styles.dart';
import 'table_order_manager.dart'; // Para usar el modelo OrderDetails

// PANTALLA DE SOLO LECTURA PARA VER LOS DETALLES DE UNA ORDEN
class OrderDetailScreen extends StatelessWidget {
  final OrderDetails orderDetails;

  const OrderDetailScreen({
    super.key,
    required this.orderDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // --- Sección de Tacos ---
                  if (orderDetails.tacoCounts.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildSectionHeader('Tacos')),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        String flavor =
                        orderDetails.tacoCounts.keys.elementAt(index);
                        int count = orderDetails.tacoCounts[flavor] ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return _buildReadOnlyItem(flavor, count);
                      },
                      childCount: orderDetails.tacoCounts.length,
                    ),
                  ),

                  // --- Sección de Refrescos ---
                  if (orderDetails.sodaCounts.isNotEmpty) ...[
                    SliverToBoxAdapter(
                        child: _buildSectionHeader('Refrescos')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String flavor =
                          orderDetails.sodaCounts.keys.elementAt(index);
                          return _buildReadOnlySodaItem(
                            flavor,
                            orderDetails.sodaCounts[flavor] ?? {},
                          );
                        },
                        childCount: orderDetails.sodaCounts.length,
                      ),
                    ),
                  ],

                  // --- Sección de Extras Simples ---
                  if (orderDetails.simpleExtraCounts.isNotEmpty) ...[
                    SliverToBoxAdapter(
                        child: _buildSectionHeader('Extras')),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String extra = orderDetails.simpleExtraCounts.keys
                              .elementAt(index);
                          int count =
                              orderDetails.simpleExtraCounts[extra] ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return _buildReadOnlyItem(extra, count);
                        },
                        childCount: orderDetails.simpleExtraCounts.length,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Encabezado de Sección ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: kAccentColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // --- App Bar ---
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón de Regresar
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const NeumorphicContainer(
              isCircle: true,
              padding: EdgeInsets.all(14),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: kAccentColor,
                size: 20,
              ),
            ),
          ),
          // Título
          Text(
            'Detalle Orden ${orderDetails.orderNumber}',
            style: const TextStyle(
              color: kTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Placeholder para centrar el título
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // --- Widget para Tacos y Extras (solo lectura) ---
  Widget _buildReadOnlyItem(String flavor, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              flavor,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: kTextColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget para Refrescos (solo lectura) ---
  Widget _buildReadOnlySodaItem(String flavor, Map<String, int> temps) {
    final int frioCount = temps['Frío'] ?? 0;
    final int tiempoCount = temps['Al Tiempo'] ?? 0;

    if (frioCount == 0 && tiempoCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              flavor,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            if (frioCount > 0)
              _buildReadOnlySubItem('Frío', frioCount),
            if (frioCount > 0 && tiempoCount > 0)
              const SizedBox(height: 10),
            if (tiempoCount > 0)
              _buildReadOnlySubItem('Al Tiempo', tiempoCount),
          ],
        ),
      ),
    );
  }

  // --- Sub-item para refrescos ---
  Widget _buildReadOnlySubItem(String label, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: kTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: kTextColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}