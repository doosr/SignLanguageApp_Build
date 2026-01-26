# Module Bluetooth pour ESP32-CAM
# Connexion Bluetooth pour recevoir le flux caméra

try:
    from jnius import autoclass
    from android.permissions import request_permissions, Permission, check_permission
    BLUETOOTH_AVAILABLE = True
except:
    BLUETOOTH_AVAILABLE = False

import threading
import socket

class BluetoothESP32:
    """Gestionnaire de connexion Bluetooth avec ESP32-CAM"""
    
    def __init__(self):
        self.connected = False
        self.socket = None
        self.device_address = None
        self.receive_thread = None
        self.on_frame_callback = None
        
        if BLUETOOTH_AVAILABLE:
            self.BluetoothAdapter = autoclass('android.bluetooth.BluetoothAdapter')
            self.BluetoothDevice = autoclass('android.bluetooth.BluetoothDevice')
            self.UUID = autoclass('java.util.UUID')
            self.adapter = self.BluetoothAdapter.getDefaultAdapter()
    
    def request_permissions(self):
        """Demander les permissions Bluetooth"""
        if BLUETOOTH_AVAILABLE:
            request_permissions([
                Permission.BLUETOOTH,
                Permission.BLUETOOTH_ADMIN,
                Permission.BLUETOOTH_CONNECT,
                Permission.BLUETOOTH_SCAN,
                Permission.ACCESS_FINE_LOCATION
            ])
    
    def is_bluetooth_enabled(self):
        """Vérifier si le Bluetooth est activé"""
        if BLUETOOTH_AVAILABLE and self.adapter:
            return self.adapter.isEnabled()
        return False
    
    def enable_bluetooth(self):
        """Activer le Bluetooth"""
        if BLUETOOTH_AVAILABLE and self.adapter:
            if not self.adapter.isEnabled():
                self.adapter.enable()
                return True
        return False
    
    def get_paired_devices(self):
        """Obtenir la liste des appareils appairés"""
        devices = []
        if BLUETOOTH_AVAILABLE and self.adapter:
            bonded_devices = self.adapter.getBondedDevices()
            if bonded_devices:
                for device in bonded_devices.toArray():
                    name = device.getName()
                    address = device.getAddress()
                    devices.append({'name': name, 'address': address})
        return devices
    
    def connect(self, device_address, on_frame_callback=None):
        """
        Connecter à un périphérique Bluetooth ESP32
        
        Args:
            device_address: Adresse MAC du périphérique (ex: "AA:BB:CC:DD:EE:FF")
            on_frame_callback: Fonction appelée lors de la réception d'une frame
        """
        if not BLUETOOTH_AVAILABLE:
            print("[ERROR] Bluetooth non disponible sur cette plateforme")
            return False
        
        try:
            print(f"[INFO] Connexion à {device_address}...")
            
            # SPP UUID (Serial Port Profile)
            uuid = self.UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
            
            # Obtenir le périphérique
            device = self.adapter.getRemoteDevice(device_address)
            
            # Créer le socket
            self.socket = device.createRfcommSocketToServiceRecord(uuid)
            
            # Connecter
            self.socket.connect()
            
            self.connected = True
            self.device_address = device_address
            self.on_frame_callback = on_frame_callback
            
            print(f"[OK] Connecté à {device_address}")
            
            # Démarrer le thread de réception
            self.receive_thread = threading.Thread(target=self._receive_loop, daemon=True)
            self.receive_thread.start()
            
            return True
            
        except Exception as e:
            print(f"[ERROR] Connexion Bluetooth échouée: {e}")
            self.connected = False
            return False
    
    def _receive_loop(self):
        """Boucle de réception des données Bluetooth"""
        try:
            input_stream = self.socket.getInputStream()
            
            while self.connected:
                # Lire les données (à adapter selon le protocole ESP32)
                # Exemple: attendre la taille de la frame, puis lire les bytes
                available = input_stream.available()
                
                if available > 0:
                    # Lire les données
                    data = input_stream.read()
                    
                    if self.on_frame_callback:
                        self.on_frame_callback(data)
                
                import time
                time.sleep(0.01)
                
        except Exception as e:
            print(f"[ERROR] Réception Bluetooth: {e}")
            self.disconnect()
    
    def disconnect(self):
        """Déconnecter le Bluetooth"""
        self.connected = False
        
        if self.socket:
            try:
                self.socket.close()
            except:
                pass
            self.socket = None
        
        print("[INFO] Bluetooth déconnecté")
    
    def send_command(self, command):
        """Envoyer une commande à l'ESP32"""
        if self.connected and self.socket:
            try:
                output_stream = self.socket.getOutputStream()
                output_stream.write(command.encode())
                output_stream.flush()
                return True
            except Exception as e:
                print(f"[ERROR] Envoi commande: {e}")
                return False
        return False
