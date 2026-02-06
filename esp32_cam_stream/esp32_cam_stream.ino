#include "esp_camera.h"
#include <WiFi.h>
#include "esp_http_server.h"

// ===========================
// Wi-Fi Credentials
// ===========================
const char* ssid = "Redmi 13";
const char* password = "dawser123a";

// ===========================
// ESP32-CAM Pin Definitions (AI-Thinker)
// ===========================
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27

#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// ===========================
// MJPEG Stream Configuration
// ===========================
#define PART_BOUNDARY "123456789000000000000987654321"
static const char* _STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char* _STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char* _STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

httpd_handle_t stream_httpd = NULL;

static esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t * fb = NULL;
  esp_err_t res = ESP_OK;
  size_t _jpg_buf_len = 0;
  uint8_t * _jpg_buf = NULL;
  char * part_buf[64];

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if (res != ESP_OK) {
    return res;
  }

  while (true) {
    fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Camera capture failed");
      res = ESP_FAIL;
    } else {
      _jpg_buf_len = fb->len;
      _jpg_buf = fb->buf;
    }
    
    if (res == ESP_OK) {
      size_t hlen = snprintf((char *)part_buf, 64, _STREAM_PART, _jpg_buf_len);
      res = httpd_resp_send_chunk(req, (const char *)part_buf, hlen);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, (const char *)_jpg_buf, _jpg_buf_len);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
    }
    if (fb) {
      esp_camera_fb_return(fb);
      fb = NULL;
      _jpg_buf = NULL;
    }
    if (res != ESP_OK) {
      break;
    }
    
    // Contrôle du frame rate : ~50ms entre frames = ~20 FPS
    // Ajuster ce délai pour trouver le bon compromis fluidité/lag
    // 50ms = 20 FPS (recommandé)
    // 67ms = 15 FPS (si encore du lag)
    // 33ms = 30 FPS (si connexion très rapide)
    delay(50);
  }
  return res;
}

void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 81;
  config.stack_size = 4096 * 2; // Augmenter la stack pour meilleur débit
  config.task_priority = 5;     // Priorité moyenne

  httpd_uri_t stream_uri = {
    .uri       = "/stream",
    .method    = HTTP_GET,
    .handler   = stream_handler,
    .user_ctx  = NULL
  };
  
  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &stream_uri);
  }
}

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();

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
  
  // Optimisations pour réduire le lag
  if (psramFound()) {
    config.frame_size = FRAMESIZE_QVGA;  // Résolution plus basse = moins de latence
    config.jpeg_quality = 15;            // 10-15 = meilleure qualité mais plus fluide que 12
    config.fb_count = 2;                 // Double buffering pour streaming fluide
    config.grab_mode = CAMERA_GRAB_LATEST; // Toujours prendre la frame la plus récente
  } else {
    config.frame_size = FRAMESIZE_QVGA;
    config.jpeg_quality = 18;            // Sans PSRAM, qualité légèrement réduite
    config.fb_count = 1;
    config.grab_mode = CAMERA_GRAB_LATEST;
  }

  // Camera init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

  // Optimisations capteur pour réduire le lag
  sensor_t * s = esp_camera_sensor_get();
  s->set_framesize(s, FRAMESIZE_QVGA);   // 320x240 = bon compromis vitesse/qualité
  s->set_quality(s, 15);                 // Qualité JPEG optimisée
  
  // Optimisations d'image pour meilleure reconnaissance
  s->set_brightness(s, 0);     // -2 à 2
  s->set_contrast(s, 0);       // -2 à 2
  s->set_saturation(s, 0);     // -2 à 2
  s->set_special_effect(s, 0); // 0 = Pas d'effet
  s->set_whitebal(s, 1);       // White balance auto
  s->set_awb_gain(s, 1);       // Auto white balance gain
  s->set_wb_mode(s, 0);        // 0 = Auto
  s->set_exposure_ctrl(s, 1);  // Auto exposure
  s->set_aec2(s, 0);           // AEC DSP
  s->set_ae_level(s, 0);       // -2 à 2
  s->set_aec_value(s, 300);    // 0 à 1200
  s->set_gain_ctrl(s, 1);      // Auto gain
  s->set_agc_gain(s, 0);       // 0 à 30
  s->set_gainceiling(s, (gainceiling_t)0); // Gain ceiling
  s->set_bpc(s, 0);            // Black pixel correction
  s->set_wpc(s, 1);            // White pixel correction
  s->set_raw_gma(s, 1);        // Gamma correction
  s->set_lenc(s, 1);           // Lens correction
  s->set_hmirror(s, 0);        // Miroir horizontal (0 = désactivé)
  s->set_vflip(s, 0);          // Flip vertical (0 = désactivé)
  s->set_dcw(s, 1);            // Downsize enable
  s->set_colorbar(s, 0);       // Test pattern désactivé

  // Optimisations Wi-Fi pour réduire la latence
  WiFi.mode(WIFI_STA);  // Mode Station uniquement (pas d'AP)
  WiFi.setSleep(false); // Désactiver le mode économie d'énergie WiFi
  WiFi.setTxPower(WIFI_POWER_19_5dBm); // Puissance max pour meilleure portée
  
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.printf("Signal Strength (RSSI): %d dBm\n", WiFi.RSSI());

  startCameraServer();

  Serial.print("Camera Ready! IP: http://");
  Serial.print(WiFi.localIP());
  Serial.println(":81/stream");
}

void loop() {
  delay(10000);
}
