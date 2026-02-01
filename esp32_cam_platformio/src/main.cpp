#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>  // <--- Captive Portal
#include "esp_camera.h"
#include "esp_timer.h"
#include "img_converters.h"
#include "fb_gfx.h"
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "config.h"
#include "camera_pins.h"

WebServer server(SERVER_PORT);
DNSServer dnsServer; // <--- DNS Server object
bool cameraInitialized = false;

void setupWiFi();
void setupCamera();
void setupServer();
void handleRoot();
void handleStream();
void handleCapture();
void handleNotFound();
void blinkLED(int times, int delayMs);

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); 
  
  if (DEBUG_SERIAL) {
    Serial.begin(SERIAL_BAUD);
    Serial.setDebugOutput(true);
    Serial.println("\n\n=== ESP32-CAM Sign Language Recognition ===");
  }
  
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LED_OFF);
  
  setupWiFi();
  setupCamera();
  setupServer();
  
  server.begin();
  
  if (DEBUG_SERIAL) {
    Serial.println("Serveur HTTP démarré");
    Serial.print("URL du stream: http://");
    Serial.print(WiFi.softAPIP());
    Serial.println("/stream");
  }
  
  blinkLED(3, 200);
}

void loop() {
  dnsServer.processNextRequest(); // <--- Traiter les requêtes DNS
  server.handleClient();
  delay(1);
}

void setupWiFi() {
  if (DEBUG_SERIAL) {
    Serial.println("Création du Point d'Accès WiFi (Hotspot)...");
    Serial.print("SSID: ");
    Serial.println(AP_SSID);
  }
  
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  
  delay(100);
  
  // Démarrer DNS Server pour Captive Portal (redirige tout vers l'IP)
  dnsServer.start(53, "*", WiFi.softAPIP()); // <--- START DNS
  
  if (DEBUG_SERIAL) {
    Serial.println("\nPoint d'Accès créé avec succès!");
    Serial.print("Connectez votre téléphone au WiFi: ");
    Serial.println(AP_SSID);
    Serial.print("Adresse IP: ");
    Serial.println(WiFi.softAPIP());
  }
}

void setupCamera() {
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
  
  if (psramFound()) {
    config.frame_size = CAMERA_FRAME_SIZE;
    config.jpeg_quality = JPEG_QUALITY;
    config.fb_count = FRAME_BUFFERS;
  } else {
    config.frame_size = FRAMESIZE_QVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }
  
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    if (DEBUG_SERIAL) Serial.printf("Échec init caméra: 0x%x\n", err);
    cameraInitialized = false;
    return;
  }
  
  cameraInitialized = true;
  
  sensor_t *s = esp_camera_sensor_get();
  if (s != NULL) {
    s->set_vflip(s, 0); 
    s->set_hmirror(s, 0); 
    s->set_wb_mode(s, 0); 
  }
}

void setupServer() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/stream", HTTP_GET, handleStream);
  server.on("/capture", HTTP_GET, handleCapture);
  server.onNotFound(handleRoot); // <--- Rediriger tout vers Root (Captive Portal)
}

void handleRoot() {
  String html = "<html><body><h1>ESP32-CAM Sign Language</h1>";
  html += "<p>IP: " + WiFi.softAPIP().toString() + "</p>";
  html += "<p><a href='/stream'>Voir le Stream</a></p>";
  html += "</body></html>";
  server.send(200, "text/html", html);
}

void handleStream() {
  if (!cameraInitialized) {
    server.send(503, "text/plain", "Camera not initialized");
    return;
  }
  
  WiFiClient client = server.client();
  String response = "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";
  server.sendContent(response);
  
  while (client.connected()) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) break;
    
    client.print("--frame\r\n");
    client.print("Content-Type: image/jpeg\r\n");
    client.print("Content-Length: " + String(fb->len) + "\r\n\r\n");
    client.write(fb->buf, fb->len);
    client.print("\r\n");
    
    esp_camera_fb_return(fb);
    delay(10);
  }
}

void handleCapture() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    server.send(500, "text/plain", "Capture failed");
    return;
  }
  server.sendHeader("Content-Disposition", "inline; filename=capture.jpg");
  server.send_P(200, "image/jpeg", (const char *)fb->buf, fb->len);
  esp_camera_fb_return(fb);
}

void handleNotFound() {
  server.send(404, "text/plain", "Not Found");
}

void blinkLED(int times, int delayMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(LED_PIN, LED_ON);
    delay(delayMs);
    digitalWrite(LED_PIN, LED_OFF);
    delay(delayMs);
  }
}