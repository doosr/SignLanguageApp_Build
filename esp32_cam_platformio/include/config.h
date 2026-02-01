#ifndef ESPCAM_CONFIG_H
#define ESPCAM_CONFIG_H

// ===== WiFi Configuration (POINT D'ACCÈS / HOTSPOT) =====
#define AP_SSID "ESPCam_SignLanguage"   // Nom du WiFi créé par l'ESP32
#define AP_PASSWORD "12345678"          // Mot de passe (min 8 caractères)

// ===== Server Configuration =====
#define SERVER_PORT 80

// ===== Camera Configuration =====
#define CAMERA_FRAME_SIZE FRAMESIZE_VGA // 640x480
#define JPEG_QUALITY 10
#define FRAME_BUFFERS 2

// ===== LED Configuration =====
#define LED_PIN 4
#define LED_ON LOW
#define LED_OFF HIGH

// ===== Debug =====
#define DEBUG_SERIAL true
#define SERIAL_BAUD 115200

#endif // ESPCAM_CONFIG_H