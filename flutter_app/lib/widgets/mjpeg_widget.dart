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
  final bool isLive; // If true, tries to reconnect automatically

  const MjpegWidget({
    Key? key,
    required this.streamUrl,
    this.fit = BoxFit.contain,
    this.errorBuilder,
    this.loadingWidget,
    this.headers,
    this.isLive = true,
  }) : super(key: key);

  @override
  _MjpegWidgetState createState() => _MjpegWidgetState();
}

class _MjpegWidgetState extends State<MjpegWidget> {
  StreamSubscription? _subscription;
  http.Client? _httpClient;
  Uint8List? _imageBytes;
  bool _hasError = false;
  bool _mounted = true;
  Timer? _reconnectTimer;

  // Boundary markers for MJPEG (JPEG starts with FF D8, ends with FF D9)
  static const int _trigger = 0xFF;
  static const int _soi = 0xD8;
  static const int _eoi = 0xD9;

  @override
  void initState() {
    super.initState();
    _mounted = true;
    _startStream();
  }

  @override
  void dispose() {
    _mounted = false;
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    _httpClient?.close();
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
    _reconnectTimer?.cancel();
    _httpClient?.close();
    _subscription = null;
    
    // Don't reset image immediately to avoid flicker if just reconnecting
    if (_mounted) {
      setState(() {
        _hasError = false; 
      });
    }

    try {
      _httpClient = http.Client();
      final request = http.Request("GET", Uri.parse(widget.streamUrl));
      if (widget.headers != null) {
        request.headers.addAll(widget.headers!);
      }
      
      // Add timeout
      Future<http.StreamedResponse> responseFuture = _httpClient!.send(request);
      final response = await responseFuture.timeout(const Duration(seconds: 5));
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final stream = response.stream;
        List<int> buffer = [];
        
        _subscription = stream.listen((chunk) {
          if (!_mounted) return;
          
          buffer.addAll(chunk);
          
          // Efficient parsing: Find EOI (FF D9)
          // We only need to search from the end of the previous buffer to save time
          // But since we just appended chunk, we search the end of buffer
          // Optimization: Only search properly when buffer has enough data
          
          if (buffer.length < 100) return; // Wait for reasonable data

          int eoiIndex = -1;
          
          // Reverse search is faster if we assume the image ends near the end of the chunk
          for (int i = buffer.length - 2; i >= 0; i--) {
            if (buffer[i] == _trigger && buffer[i+1] == _eoi) {
              eoiIndex = i + 1;
              break;
            }
            // Safety break to stop searching too far back if buffer is huge
            // However, we need to find the specific EOI
          }
          
          if (eoiIndex != -1) {
            // Found end of image, now find Start of Image (SOI) FF D8
            int soiIndex = -1;
             // Search backwards from EOI
            for (int i = eoiIndex - 2; i >= 0; i--) {
              if (buffer[i] == _trigger && buffer[i+1] == _soi) {
                soiIndex = i;
                break;
              }
            }
            
            if (soiIndex != -1) {
              // We have a full image [soiIndex, eoiIndex + 1]
              try {
                final jpegData = Uint8List.fromList(buffer.sublist(soiIndex, eoiIndex + 1));
                if (_mounted) {
                  setState(() {
                     _imageBytes = jpegData;
                     _hasError = false;
                  });
                }
              } catch (e) {
                // Ignore corruption
              }
              // Clean buffer: remove everything up to EOI
              // Keep anything after EOI (next frame start)
              buffer.removeRange(0, eoiIndex + 1);
            } else {
              // Found EOI but no SOI? Corrupt or start was in discarded buffer.
              // clear buffer up to EOI to resync
              buffer.removeRange(0, eoiIndex + 1);
            }
          }
          
           // Overflow protection
          if (buffer.length > 500000) { 
            buffer.clear(); 
          }

        }, onError: (e) {
          print("MJPEG Stream logic error: $e");
          _handleError();
        }, onDone: () {
           print("MJPEG Stream closed");
           _handleError();
        });
      } else {
        print("MJPEG Stream HTTP error: ${response.statusCode}");
        _handleError();
      }
    } catch (e) {
      print("MJPEG Stream connection error: $e");
      _handleError();
    }
  }
  
  void _handleError() {
    if (!_mounted) return;
    if (widget.isLive) {
      // Retry after delay
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (_mounted) _startStream();
      });
    } else {
       setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _imageBytes == null) {
      if (widget.errorBuilder != null) return widget.errorBuilder!(context);
      return Container(
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 40),
            const SizedBox(height: 8),
            const Text("Connexion...", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30))
          ],
        ),
      );
    }

    if (_imageBytes == null) {
      if (widget.loadingWidget != null) return widget.loadingWidget!;
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
      gaplessPlayback: true, // Prevents flickering
    );
  }
}
