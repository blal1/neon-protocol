# 📦 Guide d'Assets - Neon Protocol

## Statut des Bloquants

| Élément | Statut | Notes |
|---------|--------|-------|
| **project.godot** | ✅ Fait | Configuration complète, Godot 4.6.3 |
| **Scènes .tscn** | ✅ Fait | 17 scènes créées |
| **Input Map** | ✅ Fait | WASD, Espace, E, Escape |
| **Autoloads** | ✅ Fait | 37 managers enregistrés |
| **Assets graphiques** | 🟡 Partiel | Meshes procéduraux + 6 bâtiments `.glb` (skyline `Main.tscn`) |
| **Assets audio** | ✅ Fait | 448 fichiers, câblés via SFXManager/EnemyAudioController/MusicManager |

---

## 🎵 Assets Audio (Implémenté)

448 fichiers audio sont présents dans `audio/` et utilisés par les Autoloads
`SFXManager.gd`, `EnemyAudioController.gd`, `MusicManager.gd`, `AmbientAudioManager.gd`,
`AudioCompass.gd`, `FootstepSystem.gd`, `TTSManager.gd`.

### Structure réelle des dossiers

```
audio/
├── default_bus_layout.tres   # Bus: Music/SFX/Voice/Ambient/UI/TTS
├── AUDIO_BUS_SETUP.md
├── music/                     # 54 fichiers
├── navigation/                # 8 fichiers (sonar, ping objectif...)
└── sfx/
    ├── ui/                     # 200 fichiers (Kenney UI Audio: click_001.ogg, hover...)
    ├── combat/                 # 146 fichiers (Kenney: laserSmall_000.ogg, impactMetal_003.ogg...)
    ├── environment/            # 30 fichiers
    └── ambient/                # 8 fichiers
```

### Câblage actuel

| Système | Sons utilisés |
|---------|---------------|
| `SFXManager.play_ui()` | `click_001`, `hover`, `back`, `confirm`, `error`, `open`, `close`, `pickup`, `toggle`, `notification`, `door_open`, `door_close` (depuis `audio/sfx/ui/` et `audio/sfx/environment/`) |
| `SFXManager.play_combat()` | `laserSmall_000` (attaque), `impactMetal_003` (hit), combo finisher (depuis `audio/sfx/combat/`) |
| `EnemyAudioController` | footstep/idle/alert/attack/death par type d'ennemi (robot/drone/turret/boss), mix `audio/sfx/ui/`, `audio/sfx/combat/`, `audio/navigation/` |
| `EnemyAudioFeedback` (sur `SecurityRobot.tscn`) | footstep/servo/hum/alert/chase/attack/death, mix `audio/sfx/combat/` et `audio/sfx/environment/` |
| `MainMenu.gd` | hover/click sur tous les boutons via `SFXManager.play_ui()` |
| `CombatManager.gd` | `player_attack` à l'attaque, `player_hit`/`player_combo_finisher` à l'impact |
| `Pickup.gd` | `pickup` au ramassage d'objet |
| `Door.gd` | `door_open`/`door_close` (fallback si pas d'`AudioPlayer` dédié) |
| `ToastNotification.gd` | `notification` à chaque toast affiché |
| `PauseMenu.gd` | `hover`/`click` sur les boutons, `toggle` à la pause/reprise |
| `OptionsMenu.gd` | `toggle` sur les switches accessibilité, `back` à la fermeture |
| `CraftingSystem.gd` | `confirm` au craft réussi |

### Pistes d'amélioration

- `audio/sfx/ambient/` (8) et `audio/sfx/environment/` sont disponibles pour enrichir
  `AmbientAudioManager.gd` par district (`DistrictEcosystem.gd`).

---

## 🎨 Assets Graphiques

### Option 1 : Meshes Procéduraux (ACTUEL)
✅ **Déjà implémenté** - Le projet utilise des CapsuleMesh, BoxMesh, etc.
- Avantage : Zéro dépendance externe
- Inconvénient : Look basique

### Option 2 : Packs Gratuits Recommandés

| Pack | Lien | Contenu |
|------|------|---------|
| **Kenney City Kit** | [kenney.nl](https://kenney.nl/assets/city-kit-suburban) | Bâtiments, routes |
| **Kenney Sci-Fi** | [kenney.nl](https://kenney.nl/assets/space-kit) | Éléments futuristes |
| **Quaternius Low-Poly** | [quaternius.com](https://quaternius.com/) | Personnages, props |
| **Poly Haven** | [polyhaven.com](https://polyhaven.com/) | Textures PBR gratuites |

### Option 3 : Asset Store

| Pack | Prix | Qualité |
|------|------|---------|
| Synty Polygon Sci-Fi | ~$20 | ⭐⭐⭐⭐⭐ |
| Low Poly Cyberpunk | ~$15 | ⭐⭐⭐⭐ |

---

## 🔤 Polices Requises

| Police | Usage | Lien |
|--------|-------|------|
| **OpenDyslexic** | Mode dyslexie | [opendyslexic.org](https://opendyslexic.org/) |
| **Orbitron** | Titre cyberpunk | [Google Fonts](https://fonts.google.com/specimen/Orbitron) |
| **Roboto Mono** | Terminal/Code | [Google Fonts](https://fonts.google.com/specimen/Roboto+Mono) |

### Installation des polices

```
assets/
└── fonts/
    ├── OpenDyslexic-Regular.otf
    ├── Orbitron-Bold.ttf
    └── RobotoMono-Regular.ttf
```

---

## 📥 Script de Téléchargement Auto

Exécutez ce script PowerShell pour créer la structure de base :

```powershell
# Créer les dossiers
$folders = @(
    "assets/fonts",
    "assets/textures",
    "assets/models",
    "audio/music",
    "audio/sfx/footsteps",
    "audio/sfx/combat",
    "audio/sfx/enemy",
    "audio/sfx/ui",
    "audio/navigation",
    "audio/environment"
)

foreach ($folder in $folders) {
    New-Item -Path $folder -ItemType Directory -Force
    Write-Host "Created: $folder"
}

Write-Host "Structure créée ! Ajoutez vos assets dans les dossiers."
```

---

## ✅ Checklist de Lancement

- [x] project.godot configuré (Godot 4.6.3)
- [x] Scènes principales créées (17)
- [x] Input map défini
- [x] Autoloads enregistrés (37)
- [x] Bus audio configurés
- [x] SFX UI + combat câblés (SFXManager)
- [x] Audio ennemis câblé (EnemyAudioController, autoload)
- [x] Décor 3D : skyline de bâtiments dans Main.tscn/TestLevel
- [ ] Police OpenDyslexic ajoutée
- [ ] Test sur Android
- [ ] Build APK signé
