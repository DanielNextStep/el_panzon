import 'package:flutter/material.dart'; // Corrected typo here

// --- Paleta de Colores (Basada en NewLook.avif) ---

// Color de fondo principal (gris claro de "NewLook")
const Color kBackgroundColor = Color(0xFFE6EBF0);

// Color de acento (naranja de "NewLook")
const Color kAccentColor = Color(0xFFF2994A);

// Color de texto principal (un gris oscuro, no negro puro)
const Color kTextColor = Color(0xFF3D4552);

// --- Colores para la Sombra Neumórfica ---

// Sombra oscura (mezcla del fondo con un poco de negro)
const Color kShadowColor = Color(0xFFA3B1C6);

// Luz brillante (casi blanco)
const Color kHighlightColor = Color(0xFFFFFFFF);

// --- Widget Reutilizable de Contenedor Neumórfico ---

class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final bool isCircle; // Para botones circulares

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(12.0),
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    // Ajuste de sombra suave, estilo "NewLook"
    final double blurRadius = 10.0;
    final Offset offset = const Offset(5, 5);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kBackgroundColor,
        // Usa forma de círculo o rectángulo redondeado
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        boxShadow: [
          // Sombra oscura (abajo a la derecha)
          BoxShadow(
            color: kShadowColor.withOpacity(0.5),
            offset: offset,
            blurRadius: blurRadius,
            spreadRadius: 1.0,
          ),
          // Luz brillante (arriba a la izquierda)
          BoxShadow(
            color: kHighlightColor.withOpacity(0.9),
            offset: -offset,
            blurRadius: blurRadius,
            spreadRadius: 1.0,
          ),
        ],
      ),
      child: child,
    );
  }
}