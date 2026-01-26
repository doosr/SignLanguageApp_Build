/*
 * ESP32-CAM Bluetooth Camera Server
 * Pour application Sign Language Recognition
 * 
 * Matériel: ESP32-CAM (AI-Thinker)
 * Connexion: Bluetooth Classic (SPP)
 * 
 * Installation:
 * 1. Ouvrir Arduino IDE
 * 2. Fichier → Préférences → URLs de gestionnaire de cartes supplémentaires:
 *    https://dl.espressif.com/dl/package_esp32_index.json
 * 3. Outils → Type de carte → Gestionnaire de cartes → ESP32 → Installer
 * 4. Outils → Type de carte → ESP32 Arduino → AI Thinker ESP32-CAM
 * 5. Outils → Port → Sélectionner le port COM
 * 6. Téléverser
 */

#include "esp_camera.h"
#include "BluetoothSerial.h"

// Vérifier que Bluetooth est disponible
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to enable it
#endif

BluetoothSerial SerialBT;

// Configuration pins AI-Thinker ESP32-CAM
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

// LED Flash (GPIO 4)
#define LED_FLASH         4

// Variables globales
bool cameraReady = false;
String deviceName = "ESP32-CAM";  // Nom Bluetooth visible

void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=================================");
  Serial.println("ESP32-CAM Bluetooth Camera Server");
  Serial.println("=================================\n");
  
  // Configuration LED
  pinMode(LED_FLASH, OUTPUT);
  digitalWrite(LED_FLASH, LOW);
  
  // Initialiser la caméra
  if (initCamera()) {
    Serial.println("[OK] Camera initialized");
    cameraReady = true;
  } else {
    Serial.println("[ERROR] Camera initialization failed!");
    Serial.println("Redemarrez l'ESP32-CAM");
    return;
  }
  
  // Initialiser Bluetooth
  if (!SerialBT.begin(deviceName)) {
    Serial.println("[ERROR] Bluetooth initialization failed!");
    return;
  }
  
  Serial.println("\n[OK] Bluetooth started!");
  Serial.print("[INFO] Device name: ");
  Serial.println(deviceName);
  Serial.println("\nPret a appairer avec Android:");
  Serial.println("1. Ouvrir Bluetooth sur Android");
  Serial.println("2. Chercher 'ESP32-CAM'");
  Serial.println("3. Appairer (code PIN: 1234 si demande)");
  Serial.println("\nEn attente de connexion...\n");
  
  // Blink LED pour indiquer prêt
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_FLASH, HIGH);
    delay(200);
    digitalWrite(LED_FLASH, LOW);
    delay(200);
  }
}

void loop() {
  // Vérifier si des données sont reçues via Bluetooth
  if (SerialBT.available()) {
    String command = SerialBT.readStringUntil('\n');
    command.trim();
    
    Serial.print("[CMD] Received: ");
    Serial.println(command);
    
    if (command == "GET_FRAME") {
      sendFrame();
    }
    else if (command == "FLASH_ON") {
      digitalWrite(LED_FLASH, HIGH);
      SerialBT.println("OK:FLASH_ON");
    }
    else if (command == "FLASH_OFF") {
      digitalWrite(LED_FLASH, LOW);
      SerialBT.println("OK:FLASH_OFF");
    }
    else if (command == "SET_RES_QVGA") {
      setResolution(FRAMESIZE_QVGA);  // 320x240
      SerialBT.println("OK:RES_QVGA");
    }
    else if (command == "SET_RES_VGA") {
      setResolution(FRAMESIZE_VGA);   // 640x480
      SerialBT.println("OK:RES_VGA");
    }
    else if (command == "PING") {
      SerialBT.println("PONG");
    }
    else {
      SerialBT.println("ERROR:UNKNOWN_COMMAND");
    }
  }
  
  delay(10);  // Petite pause pour ne pas surcharger
}

bool initCamera() {
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
  
  // Résolution selon la PSRAM disponible
  if (psramFound()) {
    config.frame_size = FRAMESIZE_VGA;      // 640x480
    config.jpeg_quality = 10;               // 0-63, plus bas = meilleure qualité
    config.fb_count = 2;
    Serial.println("[INFO] PSRAM found, using VGA");
  } else {
    config.frame_size = FRAMESIZE_QVGA;     // 320x240
    config.jpeg_quality = 12;
    config.fb_count = 1;
    Serial.println("[INFO] No PSRAM, using QVGA");
  }
  
  // Initialiser la caméra
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("[ERROR] Camera init failed: 0x%x\n", err);
    return false;
  }
  
  // Ajuster les paramètres
  sensor_t * s = esp_camera_sensor_get();
  s->set_brightness(s, 0);     // -2 to 2
  s->set_contrast(s, 0);       // -2 to 2
  s->set_saturation(s, 0);     // -2 to 2
  s->set_whitebal(s, 1);       // 0 = disable, 1 = enable
  s->set_awb_gain(s, 1);       // 0 = disable, 1 = enable
  s->set_wb_mode(s, 0);        // 0 to 4 - if awb_gain enabled
  s->set_exposure_ctrl(s, 1);  // 0 = disable, 1 = enable
  s->set_aec2(s, 0);           // 0 = disable, 1 = enable
  s->set_ae_level(s, 0);       // -2 to 2
  s->set_gain_ctrl(s, 1);      // 0 = disable, 1 = enable
  s->set_agc_gain(s, 0);       // 0 to 30
  s->set_gainceiling(s, (gainceiling_t)0);  // 0 to 6
  s->set_bpc(s, 0);            // 0 = disable, 1 = enable
  s->set_wpc(s, 1);            // 0 = disable, 1 = enable
  s->set_raw_gma(s, 1);        // 0 = disable, 1 = enable
  s->set_lenc(s, 1);           // 0 = disable, 1 = enable
  s->set_hmirror(s, 0);        // 0 = disable, 1 = enable
  s->set_vflip(s, 0);          // 0 = disable, 1 = enable
  s->set_dcw(s, 1);            // 0 = disable, 1 = enable
  
  return true;
}

void sendFrame() {
  if (!cameraReady) {
    SerialBT.println("ERROR:CAMERA_NOT_READY");
    return;
  }
  
  // Capturer une image
  camera_fb_t * fb = esp_camera_fb_get();
  
  if (!fb) {
    Serial.println("[ERROR] Camera capture failed");
    SerialBT.println("ERROR:CAPTURE_FAILED");
    return;
  }
  
  Serial.printf("[INFO] Frame captured: %d bytes\n", fb->len);
  
  // Envoyer le marqueur de début
  SerialBT.println("START_FRAME");
  
  // Envoyer la taille de l'image (4 bytes)
  uint32_t size = fb->len;
  SerialBT.write((uint8_t*)&size, 4);
  
  // Envoyer l'image par blocs de 1024 bytes
  const size_t chunkSize = 1024;
  size_t sent = 0;
  
  while (sent < fb->len) {
    size_t toSend = min(chunkSize, fb->len - sent);
    size_t written = SerialBT.write(fb->buf + sent, toSend);
    sent += written;
    
    // Petit délai pour éviter de saturer le buffer Bluetooth
    delay(5);
  }
  
  // Envoyer le marqueur de fin
  SerialBT.println("END_FRAME");
  
  Serial.printf("[OK] Frame sent: %d bytes\n", sent);
  
  // Libérer le buffer
  esp_camera_fb_return(fb);
}

void setResolution(framesize_t size) {
  sensor_t * s = esp_camera_sensor_get();
  s->set_framesize(s, size);
  Serial.printf("[INFO] Resolution changed to %d\n", size);
}
