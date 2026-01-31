/**
 * ESP32-CAM Video Streaming Server
 * Pour l'application Flutter de reconnaissance de langage des signes
 * 
 * Fonctionnalités:
 * - Streaming vidéo MJPEG via HTTP
 * - Endpoint de test de connexion
 * - Configuration WiFi
 * - Support PSRAM pour meilleure performance
 */

#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include "esp_camera.h"
#include "esp_timer.h"
#include "img_converters.h"
#include "fb_gfx.h"
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "config.h"
#include "camera_pins.h"

// ===== Variables globales =====
WebServer server(SERVER_PORT);
bool cameraInitialized = false;

// ===== Prototypes de fonctions =====
void setupWiFi();
void setupCamera();
void setupServer();
void handleRoot();
void handleStream();
void handleCapture();
void handleNotFound();
void blinkLED(int times, int delayMs);

// ===== Setup =====
void setup() {
  // Désactiver le brownout detector
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  
  // Configuration du port série
  if (DEBUG_SERIAL) {
    Serial.begin(SERIAL_BAUD);
    Serial.setDebugOutput(true);
    Serial.println("\n\n=== ESP32-CAM Sign Language Recognition ===");
  }
  
  // Configuration de la LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LED_OFF);
  
  // Connexion WiFi
  setupWiFi();
  
  // Initialisation de la caméra
  setupCamera();
  
  // Configuration du serveur web
  setupServer();
  
  // Démarrage du serveur
  server.begin();
  
  if (DEBUG_SERIAL) {
    Serial.println("Serveur HTTP démarré");
    Serial.print("URL du stream: http://");
    Serial.print(WiFi.localIP());
    Serial.println("/stream");
  }
  
  // Indication visuelle de démarrage réussi
  blinkLED(3, 200);
}

// ===== Loop principal =====
void loop() {
  server.handleClient();
  delay(1);
}

// ===== Configuration WiFi =====
void setupWiFi() {
  if (DEBUG_SERIAL) {
    Serial.print("Connexion au WiFi: ");
    Serial.println(WIFI_SSID);
  }
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    if (DEBUG_SERIAL) Serial.print(".");
    blinkLED(1, 100);
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    if (DEBUG_SERIAL) {
      Serial.println("\nWiFi connecté!");
      Serial.print("Adresse IP: ");
      Serial.println(WiFi.localIP());
      Serial.print("Signal: ");
      Serial.print(WiFi.RSSI());
      Serial.println(" dBm");
    }
  } else {
    if (DEBUG_SERIAL) {
      Serial.println("\nÉchec de connexion WiFi!");
    }
    // Redémarrage si échec de connexion
    ESP.restart();
  }
}

// ===== Configuration de la caméra =====
void setupCamera() {
  if (DEBUG_SERIAL) {
    Serial.println("Initialisation de la caméra...");
  }
  
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  
  // Configuration selon la disponibilité de PSRAM
  if (psramFound()) {
    config.frame_size = CAMERA_FRAME_SIZE;
    config.jpeg_quality = JPEG_QUALITY;
    config.fb_count = FRAME_BUFFERS;
    if (DEBUG_SERIAL) {
      Serial.println("PSRAM détecté - Configuration haute qualité");
    }
  } else {
    config.frame_size = FRAMESIZE_QVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
    if (DEBUG_SERIAL) {
      Serial.println("PSRAM non détecté - Configuration basse qualité");
    }
  }
  
  // Initialisation de la caméra
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    if (DEBUG_SERIAL) {
      Serial.printf("Échec d'initialisation de la caméra: 0x%x\n", err);
    }
    cameraInitialized = false;
    return;
  }
  
  cameraInitialized = true;
  
  // Configuration du capteur
  sensor_t *s = esp_camera_sensor_get();
  if (s != NULL) {
    // Ajustements pour meilleure reconnaissance de gestes
    s->set_brightness(s, 0);     // -2 à 2
    s->set_contrast(s, 0);       // -2 à 2
    s->set_saturation(s, 0);     // -2 à 2
    s->set_special_effect(s, 0); // 0 = Aucun effet
    s->set_whitebal(s, 1);       // Balance des blancs auto
    s->set_awb_gain(s, 1);       // Gain auto
    s->set_wb_mode(s, 0);        // Mode balance des blancs auto
    s->set_exposure_ctrl(s, 1);  // Exposition auto
    s->set_aec2(s, 0);           // AEC DSP
    s->set_ae_level(s, 0);       // -2 à 2
    s->set_aec_value(s, 300);    // 0 à 1200
    s->set_gain_ctrl(s, 1);      // Contrôle de gain auto
    s->set_agc_gain(s, 0);       // 0 à 30
    s->set_gainceiling(s, (gainceiling_t)0); // 0 à 6
    s->set_bpc(s, 0);            // Black pixel correction
    s->set_wpc(s, 1);            // White pixel correction
    s->set_raw_gma(s, 1);        // Gamma correction
    s->set_lenc(s, 1);           // Lens correction
    s->set_hmirror(s, 0);        // Miroir horizontal
    s->set_vflip(s, 0);          // Retournement vertical
    s->set_dcw(s, 1);            // DCW (Downsize EN)
    s->set_colorbar(s, 0);       // Barre de couleur de test
  }
  
  if (DEBUG_SERIAL) {
    Serial.println("Caméra initialisée avec succès!");
  }
}

// ===== Configuration du serveur web =====
void setupServer() {
  // Page d'accueil
  server.on("/", HTTP_GET, handleRoot);
  
  // Stream vidéo
  server.on("/stream", HTTP_GET, handleStream);
  
  // Capture d'une image
  server.on("/capture", HTTP_GET, handleCapture);
  
  // Route non trouvée
  server.onNotFound(handleNotFound);
}

// ===== Handler: Page d'accueil =====
void handleRoot() {
  String html = "<!DOCTYPE html><html><head>";
  html += "<meta charset='UTF-8'>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<title>ESP32-CAM - Sign Language Recognition</title>";
  html += "<style>";
  html += "body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }";
  html += ".container { max-width: 800px; margin: 0 auto; background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; backdrop-filter: blur(10px); }";
  html += "h1 { text-align: center; margin-bottom: 30px; }";
  html += ".info { background: rgba(255,255,255,0.2); padding: 15px; border-radius: 10px; margin: 15px 0; }";
  html += ".info p { margin: 8px 0; }";
  html += ".btn { display: inline-block; padding: 12px 24px; background: #4CAF50; color: white; text-decoration: none; border-radius: 8px; margin: 10px 5px; transition: 0.3s; }";
  html += ".btn:hover { background: #45a049; transform: translateY(-2px); }";
  html += ".status { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 8px; }";
  html += ".status.ok { background: #4CAF50; box-shadow: 0 0 10px #4CAF50; }";
  html += "</style></head><body>";
  html += "<div class='container'>";
  html += "<h1>🎥 ESP32-CAM</h1>";
  html += "<h2>Sign Language Recognition System</h2>";
  
  html += "<div class='info'>";
  html += "<p><span class='status ok'></span><strong>État:</strong> Connecté</p>";
  html += "<p><strong>Adresse IP:</strong> " + WiFi.localIP().toString() + "</p>";
  html += "<p><strong>Signal WiFi:</strong> " + String(WiFi.RSSI()) + " dBm</p>";
  html += "<p><strong>Caméra:</strong> " + String(cameraInitialized ? "✓ Initialisée" : "✗ Erreur") + "</p>";
  html += "<p><strong>PSRAM:</strong> " + String(psramFound() ? "✓ Disponible" : "✗ Non disponible") + "</p>";
  html += "</div>";
  
  html += "<div style='text-align: center; margin-top: 30px;'>";
  html += "<a href='/stream' class='btn'>📹 Voir le Stream</a>";
  html += "<a href='/capture' class='btn'>📸 Capturer une Image</a>";
  html += "</div>";
  
  html += "<div class='info' style='margin-top: 30px;'>";
  html += "<h3>Endpoints disponibles:</h3>";
  html += "<p><code>GET /</code> - Cette page</p>";
  html += "<p><code>GET /stream</code> - Stream vidéo MJPEG</p>";
  html += "<p><code>GET /capture</code> - Capture une image JPEG</p>";
  html += "</div>";
  
  html += "</div></body></html>";
  
  server.send(200, "text/html", html);
}

// ===== Handler: Stream vidéo =====
void handleStream() {
  if (!cameraInitialized) {
    server.send(503, "text/plain", "Camera not initialized");
    return;
  }
  
  WiFiClient client = server.client();
  
  // Headers pour MJPEG stream
  String response = "HTTP/1.1 200 OK\r\n";
  response += "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";
  server.sendContent(response);
  
  if (DEBUG_SERIAL) {
    Serial.println("Client connecté au stream");
  }
  
  // Allumer la LED pendant le streaming
  digitalWrite(LED_PIN, LED_ON);
  
  while (client.connected()) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
      if (DEBUG_SERIAL) {
        Serial.println("Échec de capture de frame");
      }
      break;
    }
    
    // Envoi de la frame
    client.print("--frame\r\n");
    client.print("Content-Type: image/jpeg\r\n");
    client.print("Content-Length: " + String(fb->len) + "\r\n\r\n");
    client.write(fb->buf, fb->len);
    client.print("\r\n");
    
    esp_camera_fb_return(fb);
    
    // Petit délai pour éviter la surcharge
    delay(10);
  }
  
  // Éteindre la LED
  digitalWrite(LED_PIN, LED_OFF);
  
  if (DEBUG_SERIAL) {
    Serial.println("Client déconnecté du stream");
  }
}

// ===== Handler: Capture d'image =====
void handleCapture() {
  if (!cameraInitialized) {
    server.send(503, "text/plain", "Camera not initialized");
    return;
  }
  
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    server.send(500, "text/plain", "Camera capture failed");
    return;
  }
  
  // Flash LED
  blinkLED(1, 100);
  
  // Envoi de l'image
  server.sendHeader("Content-Disposition", "inline; filename=capture.jpg");
  server.send_P(200, "image/jpeg", (const char *)fb->buf, fb->len);
  
  esp_camera_fb_return(fb);
  
  if (DEBUG_SERIAL) {
    Serial.println("Image capturée et envoyée");
  }
}

// ===== Handler: Route non trouvée =====
void handleNotFound() {
  String message = "404 - Route non trouvée\n\n";
  message += "URI: " + server.uri() + "\n";
  message += "Méthode: " + String((server.method() == HTTP_GET) ? "GET" : "POST") + "\n";
  server.send(404, "text/plain", message);
}

// ===== Fonction utilitaire: Clignotement LED =====
void blinkLED(int times, int delayMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(LED_PIN, LED_ON);
    delay(delayMs);
    digitalWrite(LED_PIN, LED_OFF);
    delay(delayMs);
  }
}
