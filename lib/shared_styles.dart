import 'package:flutter/material.dart';

// --- Paleta de Colores (Basada en NewLook.avif) ---
const Color kBackgroundColor = Color(0xFFE6EBF0);
const Color kAccentColor = Color(0xFFF2994A);
const Color kTextColor = Color(0xFF3D4552);

// --- Colores para la Sombra Neumórfica ---
const Color kShadowColor = Color(0xFFA3B1C6);
const Color kHighlightColor = Color(0xFFFFFFFF);

// --- Widget Reutilizable de Contenedor Neumórfico ---
class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final bool isCircle;
  final bool isInner; // New parameter for "pressed" or "input" look

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(12.0),
    this.isCircle = false,
    this.isInner = false, // Default to false (outer shadow)
  });

  @override
  Widget build(BuildContext context) {
    final double blurRadius = 10.0;
    final Offset offset = const Offset(5, 5);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        // If isInner, we use a gradient to simulate depth. If not, plain background.
        color: isInner ? null : kBackgroundColor,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        gradient: isInner
            ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kShadowColor.withOpacity(0.5), // Darker inner shadow top-left
            kHighlightColor.withOpacity(0.5), // Lighter highlight bottom-right
          ],
        )
            : null,
        boxShadow: isInner
            ? null // No outer shadows when "pressed" (inner state)
            : [
          // Outer Shadow (Regular)
          BoxShadow(
            color: kShadowColor.withOpacity(0.5),
            offset: offset,
            blurRadius: blurRadius,
          ),
          BoxShadow(
            color: kHighlightColor.withOpacity(0.9),
            offset: -offset,
            blurRadius: blurRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}