#ifndef CONFIG_H
#define CONFIG_H

// ===== WiFi Configuration =====
// Remplacez ces valeurs par vos propres informations WiFi
#define WIFI_SSID "Redmi"
#define WIFI_PASSWORD "dawser123a"

// ===== Server Configuration =====
#define SERVER_PORT 80

// ===== Camera Configuration =====
// Résolution de la caméra
// FRAMESIZE_QVGA (320x240)
// FRAMESIZE_VGA (640x480)
// FRAMESIZE_SVGA (800x600)
// FRAMESIZE_XGA (1024x768)
// FRAMESIZE_SXGA (1280x1024)
#define CAMERA_FRAME_SIZE FRAMESIZE_VGA

// Qualité JPEG (0-63, plus bas = meilleure qualité)
#define JPEG_QUALITY 10

// Nombre de buffers de frame
#define FRAME_BUFFERS 2

// ===== LED Configuration =====
#define LED_PIN 4  // LED flash intégrée sur GPIO 4
#define LED_ON LOW
#define LED_OFF HIGH

// ===== Debug Configuration =====
#define DEBUG_SERIAL true
#define SERIAL_BAUD 115200

#endif // CONFIG_H
