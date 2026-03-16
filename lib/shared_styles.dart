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
  final Color? color; // New parameter for custom background color

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(12.0),
    this.isCircle = false,
    this.isInner = false, // Default to false (outer shadow)
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isInner) {
      return CustomPaint(
        painter: InnerShadowPainter(borderRadius, isCircle, color ?? kBackgroundColor),
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
    }

    final double blurRadius = 10.0;
    final Offset offset = const Offset(5, 5);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? kBackgroundColor,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        boxShadow: [
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

class InnerShadowPainter extends CustomPainter {
  final double borderRadius;
  final bool isCircle;
  final Color backgroundColor;

  InnerShadowPainter(this.borderRadius, this.isCircle, this.backgroundColor);

  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    RRect rrect = isCircle 
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)) 
        : RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Fill background
    canvas.drawRRect(rrect, Paint()..color = backgroundColor);

    canvas.save();
    canvas.clipRRect(rrect);

    // Dark shadow (Top-Left)
    Path darkPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(30))
      ..addRRect(rrect.shift(const Offset(5, 5)));

    canvas.drawPath(
      darkPath,
      Paint()
        ..color = kShadowColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Light shadow (Bottom-Right)
    Path lightPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(30))
      ..addRRect(rrect.shift(const Offset(-5, -5)));

    canvas.drawPath(
      lightPath,
      Paint()
        ..color = kHighlightColor.withOpacity(1.0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}