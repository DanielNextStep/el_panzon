import 'package:flutter/material.dart';
import 'shared_styles.dart';

class MaintenanceScreen extends StatefulWidget {
  final Map<String, bool> initialFlavors;

  const MaintenanceScreen({
    super.key,
    required this.initialFlavors,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  // Mapa local para rastrear los cambios
  late Map<String, bool> _currentFlavors;

  @override
  void initState() {
    super.initState();
    // Copia el mapa inicial al estado local
    _currentFlavors = Map<String, bool>.from(widget.initialFlavors);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- Custom Neumorphic App Bar ---
            _buildAppBar(context),

            // --- Lista de Sabores con Toggles ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: _currentFlavors.keys.map((String flavor) {
                  return _buildFlavorToggleItem(
                    flavor: flavor,
                    isAvailable: _currentFlavors[flavor] ?? false,
                    onChanged: (bool newValue) {
                      setState(() {
                        _currentFlavors[flavor] = newValue;
                      });
                    },
                  );
                }).toList(),
              ),
            ),

            // --- Botón de Guardar ---
            _buildSaveButton(context),
          ],
        ),
      ),
    );
  }

  // --- Custom App Bar Widget ---
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón de Regresar (sin guardar)
          GestureDetector(
            onTap: () => Navigator.of(context).pop(), // No devuelve nada
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
          const Text(
            'Mantenimiento',
            style: TextStyle(
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

  // --- Widget para cada sabor en la lista ---
  Widget _buildFlavorToggleItem({
    required String flavor,
    required bool isAvailable,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: NeumorphicContainer(
        borderRadius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              flavor,
              style: TextStyle(
                color: kTextColor,
                fontSize: 18,
                fontWeight: isAvailable ? FontWeight.w600 : FontWeight.w400,
                decoration: isAvailable
                    ? TextDecoration.none
                    : TextDecoration.lineThrough,
              ),
            ),
            Switch(
              value: isAvailable,
              onChanged: onChanged,
              activeColor: kAccentColor,
              inactiveTrackColor: kShadowColor.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  // --- Botón de Guardar en la parte inferior ---
  Widget _buildSaveButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: GestureDetector(
        onTap: () {
          // Devuelve el mapa actualizado a la pantalla anterior
          Navigator.of(context).pop(_currentFlavors);
        },
        child: NeumorphicContainer(
          padding: const EdgeInsets.symmetric(vertical: 20),
          borderRadius: 20,
          child: const Center(
            child: Text(
              'Guardar Cambios',
              style: TextStyle(
                color: kAccentColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}