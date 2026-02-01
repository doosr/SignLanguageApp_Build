# 📖 Guide utilisateur

## Interface principale

Au lancement, vous avez accès à deux modes :

- **🔤 Mode Reconnaissance** : Traduire vos gestes en texte/parole
- **💬 Mode Inverse** : Voir les gestes correspondant à votre voix/texte

## Mode Reconnaissance

### Utilisation

1. **Sélectionner le mode**
   - Appuyez sur l'icône 🔤 "Reconnaissance"

2. **Choisir la langue**
   - 🇫🇷 Français
   - 🇬🇧 English  
   - 🇹🇳 العربية (Arabe)

3. **Sélectionner le type**
   - **Lettres** : Alphabet de la langue des signes
   - **Mots** : Vocabulaire courant (15 mots)

4. **Faire des gestes**
   - Placez votre main devant la caméra
   - L'application détecte automatiquement
   - Le texte s'affiche en temps réel

5. **Écouter la synthèse vocale**
   - Appuyez sur le bouton 🔊
   - Le texte est lu à voix haute

### Conseils pour une meilleure reconnaissance

✅ **Bon éclairage** : Évitez les contre-jours  
✅ **Fond uni** : Préférez un fond simple  
✅ **Distance** : 30-50 cm de la caméra  
✅ **Gestes clairs** : Faites des mouvements nets  
✅ **Patience** : Maintenez le geste 1-2 secondes

### Mots reconnus

- Bonjour
- Merci
- S'il vous plaît
- Oui / Non
- Aidez-moi
- Famille
- Travail
- Manger / Boire
- École / Maison
- Ami
- Téléphone
- Médecin

## Mode Inverse

### Utilisation

1. **Sélectionner le mode**
   - Appuyez sur l'icône 💬 "Mode Inverse"

2. **Choisir la méthode**
   - **🎤 Voix** : Parlez dans le micro
   - **⌨️ Texte** : Saisissez du texte

3. **Voir les gestes**
   - L'application affiche les gestes lettre par lettre
   - Contrôlez la vitesse (lent/normal/rapide)

### Conseils

✅ **Parlez clairement** : Articulez bien  
✅ **Phrases courtes** : Évitez les phrases trop longues  
✅ **Observez attentivement** : Mémorisez les gestes

## ESP32-CAM

### Configuration

1. **Accéder aux paramètres**
   - Icône ⚙️ en haut à droite

2. **Configurer l'IP**
   - Entrez l'adresse IP de votre ESP32-CAM
   - Exemple : `192.168.1.100`

3. **Tester la connexion**
   - Appuyez sur "Tester"
   - ✅ Connexion réussie : le stream s'affiche

4. **Basculer la caméra**
   - Icône 📡 pour activer/désactiver ESP32-CAM
   - Icône 📱 pour revenir à la caméra du téléphone

### Avantages ESP32-CAM

- 📏 **Distance réglable** : Placez la caméra où vous voulez
- 🔄 **Angle optimal** : Ajustez l'angle de vue
- 🤝 **Mains libres** : Pas besoin de tenir le téléphone

## Paramètres

### Langue de l'interface

- Français (par défaut)
- English
- العربية

### Préférences

- **Vitesse d'affichage** (mode inverse) : Lent / Normal / Rapide
- **Caméra par défaut** : Téléphone / ESP32-CAM
- **Mode par défaut** : Reconnaissance / Inverse

## Astuces

### Améliorer la précision

1. **Entraînez-vous** : Plus vous utilisez l'app, mieux elle reconnaît
2. **Gestes standards** : Suivez les gestes officiels de la LSF
3. **Éclairage** : Lumière naturelle ou LED blanc froid

### Économiser la batterie

- Utilisez la résolution basse (déjà configuré)
- Fermez l'app quand vous ne l'utilisez pas
- Désactivez l'ESP32-CAM si non utilisé

## Raccourcis

| Action | Raccourci |
|--------|-----------|
| Changer de mode | Bouton retour → Sélection |
| Changer de langue | Icône 🌍 |
| Basculer caméra | Icône 🔄 |
| Synthèse vocale | Icône 🔊 |
| Paramètres | Icône ⚙️ |

## Support

Des questions ? Consultez la [FAQ](FAQ) ou ouvrez une [issue](https://github.com/doosr/SignLanguageApp_Build/issues).
