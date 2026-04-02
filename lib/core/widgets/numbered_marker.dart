import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NumberedMarker extends StatelessWidget {
  final int number;
  final Color color;
  final double size;

  const NumberedMarker({
    super.key,
    required this.number,
    this.color = Colors.red,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.location_on,
          color: color,
          size: size,
        ),
        Positioned(
          top: size * 0.25,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              number.toString(),
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
