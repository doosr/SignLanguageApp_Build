#ifndef ESPCAM_CONFIG_H
#define ESPCAM_CONFIG_H

// ===== WiFi Configuration (STATION MODE - Connect to Router) =====
// REPLACE WITH YOUR WIFI CREDENTIALS
#define WIFI_SSID "Redmi"      // Nom de votre Box/Routeur
#define WIFI_PASSWORD "12345678"  // Mot de passe WiFi

// ===== Server Configuration =====
#define SERVER_PORT 80

// ===== Camera Configuration =====
#define CAMERA_FRAME_SIZE FRAMESIZE_QVGA // 320x240 (Plus rapide, moins de latence)
#define JPEG_QUALITY 12                  // 10-63 (Plus bas = meilleure qualité, mais plus lent. 12 est un bon équilibre)
#define FRAME_BUFFERS 2                  // 2 buffers pour stream fluide

// ===== LED Configuration =====
#define LED_PIN 4       // LED Flash (GPIO 4)
#define LED_ON HIGH      // GPIO 4 (Flash) est Active HIGH
#define LED_OFF LOW

// ===== Debug =====
#define DEBUG_SERIAL true
#define SERIAL_BAUD 115200

#endif // ESPCAM_CONFIG_H