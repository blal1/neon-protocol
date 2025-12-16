# 📱 Guide d'Export Android - Neon Protocol

## Étape 1: Vérifier les Prérequis

### Android SDK
1. Télécharger [Android Studio](https://developer.android.com/studio)
2. Installer avec les composants SDK par défaut
3. Chemin typique: `C:\Users\bilal\AppData\Local\Android\Sdk`

### JDK 17+
1. Télécharger [Adoptium JDK 17](https://adoptium.net/temurin/releases/)
2. Installer (cocher "Set JAVA_HOME")
3. Chemin typique: `C:\Program Files\Eclipse Adoptium\jdk-17...`

---

## Étape 2: Configurer Godot

### Ouvrir les Préférences
```
Éditeur → Préférences de l'Éditeur → Export → Android
```

### Remplir les Champs

| Champ | Valeur |
|-------|--------|
| **Android SDK Path** | `C:\Users\bilal\AppData\Local\Android\Sdk` |
| **Java SDK Path** | `C:\Program Files\Eclipse Adoptium\jdk-17.x.x` |
| **Debug Keystore** | *(Laisser vide, sera auto-généré)* |

---

## Étape 3: Créer le Preset d'Export

1. **Projet → Exporter**
2. Cliquer **Ajouter... → Android**
3. Configurer:

```
=== Version ===
Version/Code: 1
Version/Name: 0.0.1

=== Package ===
Package/Unique Name: com.neonprotocol.game
Package/Name: Neon Protocol

=== Architectures ===
☑ arm64-v8a (recommandé)
☐ armeabi-v7a (anciens téléphones)
☐ x86/x86_64 (émulateurs)

=== Permissions ===
☑ INTERNET
☑ ACCESS_NETWORK_STATE
☑ VIBRATE
☑ WAKE_LOCK
```

---

## Étape 4: Exporter

### Debug APK (pour tester)
```
Projet → Exporter → Android → Exporter le projet
Nom: NeonProtocol_debug.apk
```

### Release APK (pour publication)
1. Créer un keystore de release:
```bash
keytool -genkey -v -keystore release.keystore -alias neonprotocol -keyalg RSA -keysize 2048 -validity 10000
```
2. Dans Godot: décocher "Export With Debug"
3. Renseigner le keystore de release

---

## Étape 5: Installer sur Téléphone

### Via ADB
```bash
adb install NeonProtocol.apk
```

### Via Transfert USB
1. Copier l'APK sur le téléphone
2. Ouvrir avec un explorateur de fichiers
3. Activer "Sources inconnues" si nécessaire

---

## 🔧 Dépannage

### "Android SDK path not configured"
→ Vérifier le chemin dans Préférences Editor

### "Java SDK path not configured"
→ Installer JDK 17+ et configurer le chemin

### "Missing debug keystore"
→ Laisser vide, Godot le génère automatiquement

### "No export template found"
→ Télécharger les templates:
```
Éditeur → Gérer les modèles d'exportation → Télécharger et installer
```

---

## 📊 Paramètres Recommandés pour Neon Protocol

```ini
# Résolution
Viewport: 960x540 (upscaling mobile)

# Rendering
Method: mobile
Driver: gl_compatibility

# Physics
Ticks: 30/sec
Thread: separate

# Shadows
Size: 1024px
Quality: Hard
```

---

*Guide généré pour Neon Protocol v0.0.1*
