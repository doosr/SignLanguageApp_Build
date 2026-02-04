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

      // Cyan/Turquoise theme matching mockup
      final paintLines = Paint()
        ..color = Color(0xFF06b6d4) // Cyan color
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Palm connections
      draw(0, 1, paintLines);
      draw(0, 5, paintLines);
      draw(0, 17, paintLines);
      draw(5, 9, paintLines);
      draw(9, 13, paintLines);
      draw(13, 17, paintLines);

      // Thumb
      draw(1, 2, paintLines);
      draw(2, 3, paintLines);
      draw(3, 4, paintLines);
      
      // Index
      draw(5, 6, paintLines);
      draw(6, 7, paintLines);
      draw(7, 8, paintLines);
      
      // Middle
      draw(9, 10, paintLines);
      draw(10, 11, paintLines);
      draw(11, 12, paintLines);
      
      // Ring
      draw(13, 14, paintLines);
      draw(14, 15, paintLines);
      draw(15, 16, paintLines);
      
      // Pinky
      draw(17, 18, paintLines);
      draw(18, 19, paintLines);
      draw(19, 20, paintLines);
      
      // Draw landmarks points with cyan glow
      for (int i = 0; i < pts.length; i++) {
        // Glow effect
        canvas.drawCircle(
          pts[i], 
          8, 
          Paint()
            ..color = Color(0xFF06b6d4).withOpacity(0.3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4),
        );
        
        // Outer cyan circle
        canvas.drawCircle(
          pts[i], 
          5, 
          Paint()..color = Color(0xFF06b6d4),
        );
        
        // Inner white dot
        canvas.drawCircle(
          pts[i], 
          2, 
          Paint()..color = Colors.white,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
