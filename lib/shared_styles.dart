import 'package:flutter/material.dart';

// --- App Colors based STRICTLY on the "NewLook" Reference ---
// Lighter, cool grey from the "NewLook" reference image's background
const Color kBackgroundColor = Color(0xFFEFF3F6);
// Softer shadow derived from the new background
const Color kShadowColor = Color(0xFFCADBEB); // Adjusted for softer effect
// Brighter highlight derived from the new background
const Color kHighlightColor = Color(0xFFFFFFFF);
// Orange accent color from the "NewLook" image
const Color kAccentColor = Color(0xFFFF8A00); // Changed to orange
// Darker text color for readability (can be adjusted if needed)
const Color kTextColor = Color(0xFF4B4B4B);

// --- Custom Neumorphic Container Widget ---
class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final bool isCircle;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.symmetric(vertical: 24),
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kBackgroundColor,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        boxShadow: const [
          // --- Softer Darker Shadow (Bottom-Right) ---
          BoxShadow(
            color: kShadowColor,
            offset: Offset(4, 4), // Reduced offset for softer look
            blurRadius: 8, // Reduced blur for softer look
          ),
          // --- Softer Brighter Highlight (Top-Left) ---
          BoxShadow(
            color: kHighlightColor,
            offset: Offset(-4, -4), // Reduced offset
            blurRadius: 8, // Reduced blur
          ),
        ],
      ),
      child: child,
    );
  }
}