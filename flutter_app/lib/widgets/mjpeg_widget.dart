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
  final bool isLive; 

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
  
  // Stats for debug
  int _dataReceived = 0;

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
      
      Future<http.StreamedResponse> responseFuture = _httpClient!.send(request);
      final response = await responseFuture.timeout(const Duration(seconds: 5));
      
      // CRITICAL: Check Content-Type to avoid reading HTML as MJPEG
      // ESP32 usually returns "multipart/x-mixed-replace; boundary=frame"
      // or "image/jpeg" if single frame
      final cType = response.headers['content-type'];
      print("MJPEG Stream Content-Type: $cType");
      
      // RELAXED VALIDATION: Log warning but don't abort. 
      // Some ESP32 servers send text/plain or nothing.
      if (cType != null && !cType.contains('multipart') && !cType.contains('image')) {
         print("⚠️ Warning: Unusual Content-Type: $cType. Attempting to parse anyway.");
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final stream = response.stream;
        List<int> buffer = [];
        
        _subscription = stream.listen((chunk) {
          if (!_mounted) return;
          
          // SAFETY: Don't read infinite data if parsing fails
          if (buffer.length > 500000) { // 500KB limit
             print("⚠️ Buffer overflow, clearing. Missing JPEG markers?");
             buffer.clear();
          }

          buffer.addAll(chunk);
          _dataReceived += chunk.length;
          
          if (buffer.length < 100) return; 

          int eoiIndex = -1;
          
          // Reverse search is efficient
          for (int i = buffer.length - 2; i >= 0; i--) {
            if (buffer[i] == _trigger && buffer[i+1] == _eoi) {
              eoiIndex = i + 1;
              break;
            }
          }
          
          if (eoiIndex != -1) {
            int soiIndex = -1;
            for (int i = eoiIndex - 2; i >= 0; i--) {
              if (buffer[i] == _trigger && buffer[i+1] == _soi) {
                soiIndex = i;
                break;
              }
            }
            
            if (soiIndex != -1) {
              try {
                // Copy data to avoid buffer mutation issues during setState
                final jpegData = Uint8List.fromList(buffer.sublist(soiIndex, eoiIndex + 1));
                if (_mounted) {
                  setState(() {
                     _imageBytes = jpegData;
                     _hasError = false;
                  });
                }
              } catch (e) { }
              
              // Keep residual bytes
              buffer.removeRange(0, eoiIndex + 1);
            } else {
              buffer.removeRange(0, eoiIndex + 1);
            }
          }
        }, onError: (e) {
          print("MJPEG Stream logic error: $e");
          _handleError();
        }, onDone: () {
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
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (_mounted) _startStream();
      });
    } else {
       setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      if (widget.errorBuilder != null) return widget.errorBuilder!(context);
      return Container(
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.white54, size: 40),
            const SizedBox(height: 8),
            const Text("Connexion échouée", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 4),
            const Text("Vérifiez le WiFi", style: TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      );
    }

    if (_imageBytes == null) {
      if (widget.loadingWidget != null) return widget.loadingWidget!;
      return Container(
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.blueAccent),
            const SizedBox(height: 12),
            Text("Connexion ESP32...", style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }

    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
      gaplessPlayback: true, 
    );
  }
}
