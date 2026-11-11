import 'package:flutter/material.dart';

class DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height); // Start at bottom left
    path.lineTo(size.width, size.height * 0.4); // More steep diagonal
    path.lineTo(size.width, 0); // Top right
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}