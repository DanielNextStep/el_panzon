import 'package:flutter/material.dart';
import 'shared_styles.dart';

class MaintenanceScreen extends StatefulWidget {
  final Map<String, bool> initialFlavors;
  // --- AÑADIDO: Mapa de extras ---
  final Map<String, bool> initialExtras;

  const MaintenanceScreen({
    super.key,
    required this.initialFlavors,
    required this.initialExtras, // --- AÑADIDO: al constructor
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  // Mapa local para rastrear los cambios
  late Map<String, bool> _currentFlavors;
  // --- AÑADIDO: Mapa local para extras ---
  late Map<String, bool> _currentExtras;

  @override
  void initState() {
    super.initState();
    // Copia los mapas iniciales al estado local
    _currentFlavors = Map<String, bool>.from(widget.initialFlavors);
    _currentExtras = Map<String, bool>.from(widget.initialExtras);
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

            // --- ACTUALIZADO: Lista con secciones ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // --- Sección de Tacos ---
                  _buildSectionHeader('Tacos'),
                  ..._currentFlavors.keys.map((String flavor) {
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

                  const SizedBox(height: 25), // Espaciador

                  // --- Sección de Extras ---
                  _buildSectionHeader('Extras'),
                  ..._currentExtras.keys.map((String extra) {
                    return _buildFlavorToggleItem(
                      flavor: extra,
                      isAvailable: _currentExtras[extra] ?? false,
                      onChanged: (bool newValue) {
                        setState(() {
                          _currentExtras[extra] = newValue;
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
            ),

            // --- Botón de Guardar ---
            _buildSaveButton(context),
          ],
        ),
      ),
    );
  }

  // --- AÑADIDO: Widget de encabezado de sección ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
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
          // --- ACTUALIZADO: Devuelve un mapa con ambas listas ---
          Navigator.of(context).pop({
            'flavors': _currentFlavors,
            'extras': _currentExtras,
          });
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