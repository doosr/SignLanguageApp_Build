import 'package:flutter/material.dart';

class HandPainter extends CustomPainter {
  final List<List<double>> hands;
  final Size absoluteImageSize;
  final int rotation;
  final bool isFrontCamera;
  
  HandPainter(this.hands, this.absoluteImageSize, this.rotation, this.isFrontCamera);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final hand in hands) {
      List<Offset> pts = [];
      
      for (int i = 0; i < hand.length; i += 2) {
        pts.add(Offset(hand[i] * size.width, hand[i+1] * size.height));
      }
      
      void draw(int i, int j, Paint paint) {
        if (i < pts.length && j < pts.length) {
          canvas.drawLine(pts[i], pts[j], paint);
        }
      }

      final paintPalm = Paint()..color = Colors.white.withOpacity(0.8)..strokeWidth = 3.0..style = PaintingStyle.stroke;
      final paintThumb = Paint()..color = const Color(0xFFFF9100)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      final paintIndex = Paint()..color = const Color(0xFF00E676)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      final paintMiddle = Paint()..color = const Color(0xFF2979FF)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      final paintRing = Paint()..color = const Color(0xFFFF1744)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      final paintPinky = Paint()..color = const Color(0xFFD500F9)..strokeWidth = 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

      // Palm
      draw(0, 1, paintPalm);
      draw(0, 5, paintPalm);
      draw(0, 17, paintPalm);
      draw(5, 9, paintPalm);
      draw(9, 13, paintPalm);
      draw(13, 17, paintPalm);

      // Fingers
      draw(1, 2, paintThumb);
      draw(2, 3, paintThumb);
      draw(3, 4, paintThumb);
      
      draw(5, 6, paintIndex);
      draw(6, 7, paintIndex);
      draw(7, 8, paintIndex);
      
      draw(9, 10, paintMiddle);
      draw(10, 11, paintMiddle);
      draw(11, 12, paintMiddle);
      
      draw(13, 14, paintRing);
      draw(14, 15, paintRing);
      draw(15, 16, paintRing);
      
      draw(17, 18, paintPinky);
      draw(18, 19, paintPinky);
      draw(19, 20, paintPinky);
      
      // Draw landmarks points
      for (int i = 0; i < pts.length; i++) {
        Color dotColor = Colors.cyanAccent;
        double radius = 5;
        
        if (i >= 1 && i <= 4) dotColor = const Color(0xFFFF9100);
        else if (i >= 5 && i <= 8) dotColor = const Color(0xFF00E676);
        else if (i >= 9 && i <= 12) dotColor = const Color(0xFF2979FF);
        else if (i >= 13 && i <= 16) dotColor = const Color(0xFFFF1744);
        else if (i >= 17 && i <= 20) dotColor = const Color(0xFFD500F9);
        else if (i == 0) dotColor = Colors.yellowAccent;

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
  bool shouldRepaint(covariant CustomPainter old) => true;
}
