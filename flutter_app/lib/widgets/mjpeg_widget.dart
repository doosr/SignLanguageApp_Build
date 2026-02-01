import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MjpegWidget extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;
  final WidgetBuilder? errorBuilder;
  final Widget? loadingWidget;
  final Map<String, String>? headers;

  const MjpegWidget({
    Key? key,
    required this.streamUrl,
    this.fit = BoxFit.contain,
    this.errorBuilder,
    this.loadingWidget,
    this.headers,
  }) : super(key: key);

  @override
  _MjpegWidgetState createState() => _MjpegWidgetState();
}

class _MjpegWidgetState extends State<MjpegWidget> {
  StreamSubscription? _subscription;
  Uint8List? _imageBytes;
  bool _hasError = false;
  
  // Boundary markers for MJPEG (JPEG starts with FF D8, ends with FF D9)
  static const int _trigger = 0xFF;
  static const int _soi = 0xD8;
  static const int _eoi = 0xD9;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MjpegWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _startStream();
    }
  }

  void _startStream() async {
    _subscription?.cancel();
    _subscription = null;
    
    setState(() {
      _hasError = false;
      _imageBytes = null;
    });

    try {
      final request = http.Request("GET", Uri.parse(widget.streamUrl));
      if (widget.headers != null) {
        request.headers.addAll(widget.headers!);
      }
      
      final response = await http.Client().send(request);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final stream = response.stream;
        List<int> buffer = [];
        
        _subscription = stream.listen((chunk) {
          if (!mounted) return;
          
          // Simple parsing logic: Accumulate bytes until we find a full JPEG
          // This is a naive implementation; for production might need robust boundary parsing
          // But effectively works for most ESP32-CAM MJPEG streams which send separate chunks or multipart/x-mixed-replace
          
          // Optimization: Most ESP32 streams send one JPEG per chunk or close to it
          // Let's refine:
          
          buffer.addAll(chunk);
          
          // Search for EOI
          int? eoiIndex;
          for (int i = 0; i < buffer.length - 1; i++) {
            if (buffer[i] == _trigger && buffer[i+1] == _eoi) {
              eoiIndex = i + 1;
              break;
            }
          }
          
          if (eoiIndex != null) {
            // Found end of image, extract it
            // Also need to find Start of Image (SOI) to be safe
            int soiIndex = 0;
            for (int i = 0; i < eoiIndex; i++) {
               if (buffer[i] == _trigger && buffer[i+1] == _soi) {
                 soiIndex = i;
                 break;
               }
            }
            
            if (soiIndex < eoiIndex) {
              final jpegData = Uint8List.fromList(buffer.sublist(soiIndex, eoiIndex + 1));
              if (mounted) {
                setState(() {
                   _imageBytes = jpegData;
                });
              }
              // Remove processed data
              buffer.removeRange(0, eoiIndex + 1);
            } else {
              // Invalid state, clear buffer up to EOI to recover
              buffer.removeRange(0, eoiIndex + 1);
            }
          }
           // Prevent buffer overflow if stream is weird
          if (buffer.length > 500000) { // 500KB safety limit
            buffer.clear(); 
          }

        }, onError: (e) {
          print("MJPEG Stream logic error: $e");
          if (mounted) setState(() => _hasError = true);
        }, onDone: () {
           // efficient reconnect?
        });
      } else {
        print("MJPEG Stream HTTP error: ${response.statusCode}");
        if (mounted) setState(() => _hasError = true);
      }
    } catch (e) {
      print("MJPEG Stream connection error: $e");
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      if (widget.errorBuilder != null) return widget.errorBuilder!(context);
      return Container(
        color: Colors.black,
        child: const Center(child: Icon(Icons.error, color: Colors.red)),
      );
    }

    if (_imageBytes == null) {
      if (widget.loadingWidget != null) return widget.loadingWidget!;
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}
