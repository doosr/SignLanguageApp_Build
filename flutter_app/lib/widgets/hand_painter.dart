import 'package:flutter/material.dart';

class HandPainter extends CustomPainter {
  final List<List<double>> hands;
  final Size absoluteImageSize;
  final int rotation;
  final bool isFrontCamera;
  
  HandPainter(this.hands, this.absoluteImageSize, this.rotation, this.isFrontCamera);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Paint configurations for better visibility
    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.greenAccent;
    
    final paintPoint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    
    final paintTips = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.cyanAccent;
    
    final paintPalm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellowAccent;

    // Show landmarks points
    final paintPalmBase = Paint()..color = Colors.white.withOpacity(0.8)..strokeWidth = 3.0..style = PaintingStyle.stroke;

    // Define Vibrant Neon Colors for fingers
    final paintThumb = Paint()..color = const Color(0xFFFF9100)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round; // Orange Neon
    final paintIndex = Paint()..color = const Color(0xFF00E676)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round; // Green Neon
    final paintMiddle = Paint()..color = const Color(0xFF2979FF)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round; // Blue Neon
    final paintRing = Paint()..color = const Color(0xFFFF1744)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round; // Red/Pink Neon
    final paintPinky = Paint()..color = const Color(0xFFD500F9)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round; // Purple Neon
    
    for (final hand in hands) {
      List<Offset> pts = [];
      
      for (int i = 0; i < hand.length; i += 2) {
        // Points are assumed to be normalized (0-1) and already rotated correctly for inference/display if processed
        // BUT HandPainter typically receives normalized points 0-1.
        // If the Main Logic rotates them 90 deg, we should be careful.
        // In main.dart, we saw: pts.add(Offset(finalX * size.width, finalY * size.height));
        // We will assume 'hands' passed here are normalized 0-1.
        
        // Wait, the HandPainter logic in main.dart had the rotation logic INSIDE it in previous versions,
        // but in the LATEST version (Step 561), the logic was moved to _processCameraImage and HandPainter received ALREADY ROTATED points.
        // However, HandPainter loop in Step 561 was:
        // pts.add(Offset(hand[i] * size.width, hand[i+1] * size.height));
        // So it expects 0-1 normalized points.

        pts.add(Offset(hand[i] * size.width, hand[i+1] * size.height));
      }
      
      // Safe drawing function
      void draw(int i, int j, Paint p) {
        if (i < pts.length && j < pts.length) {
          canvas.drawLine(pts[i], pts[j], p);
        }
      }

      // Draw Connections (Fingers)
      // Palm / Base
      draw(0, 1, paintPalmBase);
      draw(0, 5, paintPalmBase);
      draw(0, 17, paintPalmBase);
      draw(5, 9, paintPalmBase);
      draw(9, 13, paintPalmBase);
      draw(13, 17, paintPalmBase);

      // Thumb
      draw(1, 2, paintThumb);
      draw(2, 3, paintThumb);
      draw(3, 4, paintThumb);

      // Index
      draw(5, 6, paintIndex);
      draw(6, 7, paintIndex);
      draw(7, 8, paintIndex);

      // Middle
      draw(9, 10, paintMiddle);
      draw(10, 11, paintMiddle);
      draw(11, 12, paintMiddle);

      // Ring
      draw(13, 14, paintRing);
      draw(14, 15, paintRing);
      draw(15, 16, paintRing);

      // Pinky
      draw(17, 18, paintPinky);
      draw(18, 19, paintPinky);
      draw(19, 20, paintPinky);
      
      // Draw landmarks points
      for (int i = 0; i < pts.length; i++) {
        Color dotColor = Colors.cyanAccent;
        double radius = 5;
        
        // Color code points by finger
        if (i >= 1 && i <= 4) dotColor = const Color(0xFFFF9100);
        else if (i >= 5 && i <= 8) dotColor = const Color(0xFF00E676);
        else if (i >= 9 && i <= 12) dotColor = const Color(0xFF2979FF);
        else if (i >= 13 && i <= 16) dotColor = const Color(0xFFFF1744);
        else if (i >= 17 && i <= 20) dotColor = const Color(0xFFD500F9);
        else if (i == 0) dotColor = Colors.yellowAccent;

        // Tips highlighting
        if (i == 4 || i == 8 || i == 12 || i == 16 || i == 20) {
          radius = 7;
          canvas.drawCircle(pts[i], radius + 2, Paint()..color = Colors.white.withOpacity(0.5));
        }

        canvas.drawCircle(pts[i], radius, Paint()..color = dotColor);
        canvas.drawCircle(pts[i], 2, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
