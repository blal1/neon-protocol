# 🎮 Neon Protocol - Guide de Configuration Godot Engine

## 📋 Table des Matières

1. [Prérequis](#prérequis)
2. [Installation de Godot](#installation-de-godot)
3. [Import du Projet](#import-du-projet)
4. [Structure du Projet](#structure-du-projet)
5. [Configuration des Autoloads](#configuration-des-autoloads)
6. [Configuration des Inputs](#configuration-des-inputs)
7. [Configuration Audio](#configuration-audio)
8. [Configuration Physique](#configuration-physique)
9. [Configuration Rendering](#configuration-rendering)
10. [Première Compilation](#première-compilation)
11. [Export Android](#export-android)
12. [Dépannage](#dépannage)

---

## 🔧 Prérequis

| Composant | Version Minimum | Recommandée |
|-----------|-----------------|-------------|
| **Godot Engine** | 4.2 | 4.2.2+ |
| **RAM** | 4 GB | 8 GB+ |
| **GPU** | OpenGL 3.3 | Vulkan compatible |
| **Android SDK** | 33 (pour export) | 34 |
| **JDK** | 11 | 17 |

---

## 📥 Installation de Godot

### Windows

1. Téléchargez Godot 4.6+ depuis [godotengine.org](https://godotengine.org/download)
2. Choisissez la version **Standard** (pas .NET)
3. Extrayez l'archive dans un dossier (ex: `C:\Godot\`)
4. Lancez `Godot_v4.x-stable_win64.exe`

### Configuration Initiale

```
Éditeur → Préférences de l'Éditeur → Interface → Thème
  └── Préréglage: Sombre (recommandé pour cyberpunk)
```

---

## 📂 Import du Projet

### Méthode 1: Import Direct

1. Dans Godot, cliquez sur **Importer**
2. Naviguez vers le dossier `neon-protocol/`
3. Sélectionnez `project.godot`
4. Cliquez **Importer et Éditer**

### Méthode 2: Scan de Dossier

1. Cliquez sur **Scanner** dans le gestionnaire de projets
2. Sélectionnez le dossier parent de `neon-protocol/`
3. Le projet apparaîtra dans la liste

### Première Ouverture

> ⚠️ **Important**: Lors de la première ouverture, Godot réimportera tous les assets. Cela peut prendre 2-5 minutes selon votre machine.

---

## 📁 Structure du Projet

```
neon-protocol/
├── assets/                    # Ressources graphiques
│   ├── fonts/                 # Polices TTF
│   │   ├── Orbitron-VariableFont_wght.ttf
│   │   ├── Rajdhani-*.ttf
│   │   └── Kenney Future*.ttf
│   ├── models/                # Modèles 3D
│   │   └── buildings/         # 41 GLB buildings
│   └── textures/              # Textures
│
├── audio/                     # Fichiers audio
│   ├── music/                 # 27 MP3 tracks
│   ├── sfx/                   # Effets sonores
│   │   ├── ui/                # 100 sons UI
│   │   ├── combat/            # 73 sons combat
│   │   ├── ambient/           # Sons ambiants
│   │   └── environment/       # Sons environnement
│   └── navigation/            # 4 sons sonar
│
├── scenes/                    # Scènes .tscn
│   ├── main/                  # Main.tscn (point d'entrée)
│   ├── player/                # Player.tscn
│   ├── enemies/               # SecurityRobot.tscn, etc.
│   ├── ui/                    # Menus, HUD, Joystick
│   └── world/                 # CityBlock.tscn, TutorialLevel.tscn
│
├── scripts/                   # Scripts GDScript
│   ├── accessibility/         # Systèmes accessibilité
│   ├── audio/                 # Managers audio
│   ├── components/            # Composants réutilisables
│   ├── enemies/               # IA ennemis
│   ├── gameplay/              # Systèmes de jeu
│   ├── input/                 # Gestion inputs
│   ├── missions/              # Système missions
│   ├── network/               # Multijoueur
│   ├── player/                # Scripts joueur
│   ├── systems/               # Managers globaux
│   ├── ui/                    # Scripts UI
│   └── world/                 # Environnement
│
└── project.godot              # Configuration projet
```

---

## ⚡ Configuration des Autoloads

Les autoloads sont des singletons chargés au démarrage. Ils sont déjà configurés dans `project.godot`.

### Vérification

`Projet → Paramètres du projet → Autoload`

| Nom | Script | Activé |
|-----|--------|--------|
| AccessibilityManager | `res://scripts/accessibility/AccessibilityManager.gd` | ✅ |
| BlindAccessibilityManager | `res://scripts/accessibility/BlindAccessibilityManager.gd` | ✅ |
| MissionManager | `res://scripts/missions/MissionManager.gd` | ✅ |
| TTSManager | `res://scripts/audio/TTSManager.gd` | ✅ |
| SaveManager | `res://scripts/systems/SaveManager.gd` | ✅ |
| InventoryManager | `res://scripts/systems/InventoryManager.gd` | ✅ |
| TutorialManager | `res://scripts/systems/TutorialManager.gd` | ✅ |
| AchievementManager | `res://scripts/systems/AchievementManager.gd` | ✅ |
| LeaderboardManager | `res://scripts/systems/LeaderboardManager.gd` | ✅ |
| LocalizationManager | `res://scripts/systems/LocalizationManager.gd` | ✅ |
| SkillTreeManager | `res://scripts/systems/SkillTreeManager.gd` | ✅ |
| ReputationManager | `res://scripts/systems/ReputationManager.gd` | ✅ |
| CutsceneManager | `res://scripts/gameplay/CutsceneManager.gd` | ✅ |
| NetworkManager | `res://scripts/network/NetworkManager.gd` | ✅ |
| MusicManager | `res://scripts/audio/MusicManager.gd` | ✅ |
| ToastNotification | `res://scripts/ui/ToastNotification.gd` | ✅ |
| StatsManager | `res://scripts/systems/StatsManager.gd` | ✅ |
| HapticFeedback | `res://scripts/input/HapticFeedback.gd` | ✅ |

### Ajout d'Autoloads Manquants

Si des autoloads manquent:

1. `Projet → Paramètres du projet → Autoload`
2. **Chemin**: Naviguer vers le script
3. **Nom du nœud**: Nom en PascalCase
4. Cocher **Activer**
5. Cliquer **Ajouter**

---

## 🎮 Configuration des Inputs

### Inputs Prédéfinis

`Projet → Paramètres du projet → Contrôles`

| Action | Clavier | Souris | Manette |
|--------|---------|--------|---------|
| `move_forward` | W | - | Left Stick ↑ |
| `move_backward` | S | - | Left Stick ↓ |
| `move_left` | A | - | Left Stick ← |
| `move_right` | D | - | Left Stick → |
| `attack` | Espace | Clic Gauche | A / X |
| `dash` | Shift | - | B / O |
| `interact` | E | - | Y / △ |
| `pause` | Échap | - | Start |

### Ajouter un Nouveau Input

1. Cliquer sur **Ajouter une nouvelle action**
2. Nom: ex: `use_ability`
3. Cliquer sur le "+" à droite de l'action
4. Appuyer sur la touche désirée

---

## 🔊 Configuration Audio

### Bus Audio

Le fichier `audio/default_bus_layout.tres` définit les bus:

| Bus | Usage | Volume |
|-----|-------|--------|
| Master | Contrôle global | 0 dB |
| Music | Musiques de fond | -6 dB |
| SFX | Effets sonores | -3 dB |
| Voice | TTS / Voix | 0 dB |
| Ambient | Sons ambiants | -10 dB |

### Création/Modification des Bus

1. Ouvrir `Fenêtre du bas → Audio`
2. Cliquer droit → Ajouter un bus
3. Configurer volume et effets

### Configuration Système

```ini
[audio]
driver/mix_rate=22050  ; Économie de ressources mobile
```

---

## ⚙️ Configuration Physique

### Layers de Collision

`Projet → Paramètres → Noms des couches → Physique 3D`

| Layer | Nom | Usage |
|-------|-----|-------|
| 1 | World | Environnement statique |
| 2 | Player | Joueur |
| 3 | Enemy | Ennemis |
| 4 | Interactable | Objets interactifs |
| 5 | Projectile | Projectiles |

### Configuration des Masques

Pour configurer un `CollisionObject3D`:

```
Collision:
  Layer: [x] Player       # Ce que JE SUIS
  Mask:  [x] World        # Ce que JE DÉTECTE
         [x] Enemy
         [x] Interactable
```

### Paramètres Physique

```ini
[physics]
common/physics_ticks_per_second=30    ; Performance mobile
3d/run_on_separate_thread=true         ; Threading
3d/default_gravity=9.8
```

---

## 🎨 Configuration Rendering

### Paramètres Actuels (Mobile)

```ini
[rendering]
renderer/rendering_method="mobile"                    ; Compatible mobile
renderer/rendering_method.mobile="gl_compatibility"  ; OpenGL ES 3.0
textures/vram_compression/import_etc2_astc=true      ; Compression Android
lights_and_shadows/directional_shadow/size=1024      ; Ombres légères
lights_and_shadows/positional_shadow/atlas_size=1024
anti_aliasing/quality/msaa_3d=0                      ; Pas de MSAA mobile
```

### Optimisation par Plateforme

**Mobile (défaut):**
- Renderer: `mobile`
- Shadows: 1024px
- MSAA: Off

**PC (optionnel):**
```ini
renderer/rendering_method="forward_plus"
lights_and_shadows/directional_shadow/size=4096
anti_aliasing/quality/msaa_3d=2
```

---

## ▶️ Première Compilation

### Exécution dans l'Éditeur

1. Appuyez sur **F5** ou cliquez ▶️
2. La scène `Main.tscn` se lance

### Tester une Scène Spécifique

1. Ouvrir la scène désirée
2. Appuyez sur **F6** ou cliquez ▶️ scène

### Scènes Principales

| Scène | Description |
|-------|-------------|
| `Main.tscn` | Menu principal |
| `CityBlock.tscn` | Niveau principal |
| `TutorialLevel.tscn` | Tutoriel |
| `Player.tscn` | Test joueur seul |

---

## 📱 Export Android

### Prérequis

1. **Android SDK**: Installer via Android Studio
2. **JDK 17**: [Adoptium](https://adoptium.net/)
3. **Debug keystore**: Généré automatiquement

### Configuration Éditeur

`Éditeur → Préférences de l'Éditeur → Export → Android`

| Paramètre | Valeur |
|-----------|--------|
| Android SDK Path | `C:\Users\{user}\AppData\Local\Android\Sdk` |
| Debug Keystore | `{user}\.android\debug.keystore` |
| JDK Path | `C:\Program Files\Java\jdk-17` |

### Création du Preset

1. `Projet → Exporter`
2. **Ajouter... → Android**
3. Configurer:

| Option | Valeur |
|--------|--------|
| Package Unique Name | `com.neonprotocol.game` |
| Version Code | `1` |
| Version Name | `0.1.0` |
| Min SDK | `24` (Android 7.0) |
| Target SDK | `34` |

### Permissions Requises

```
☑ INTERNET (multijoueur)
☑ VIBRATE (haptic feedback)
☑ ACCESS_NETWORK_STATE
```

### Export

1. Cliquer **Exporter le projet**
2. Nom: `NeonProtocol.apk`
3. Cocher **Export avec debug** pour test

---

## 🐛 Dépannage

### Erreur: Script non trouvé

```
Erreur: Cannot load script 'res://scripts/xxx.gd'
```

**Solution**: Vérifier que le fichier existe et recréer l'autoload.

### Erreur: Scène principale manquante

```
No main scene defined
```

**Solution**: `Projet → Paramètres → Application → Run → Main Scene`

### Performances faibles sur mobile

1. Réduire `lights_and_shadows/directional_shadow/size` à 512
2. Désactiver `3d/run_on_separate_thread`
3. Réduire `physics_ticks_per_second` à 20

### TTS ne fonctionne pas

- Windows: Vérifier que les voix FR sont installées
- Mobile: Le TTS natif doit être activé dans les paramètres système

### Navigation des ennemis bloquée

1. Vérifier que la scène a un `NavigationRegion3D`
2. Regénérer le navmesh: Clic droit → Bake Navigation

---

## 📚 Ressources Additionnelles

- [Documentation Godot 4](https://docs.godotengine.org/en/stable/)
- [GDScript Reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)
- [Export Android Guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)

---

## ✅ Checklist de Configuration

- [ ] Godot 4.6+ installé
- [ ] Projet importé
- [ ] Tous les autoloads actifs
- [ ] Inputs configurés
- [ ] Bus audio configurés
- [ ] Première exécution réussie (F5)
- [ ] Export Android configuré (optionnel)

---

*Documentation générée pour Neon Protocol v0.2.0 - Godot 4.6.3*
