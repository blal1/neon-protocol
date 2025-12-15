# 📦 Guide d'Assets - Neon Protocol

## Statut des Bloquants

| Élément | Statut | Notes |
|---------|--------|-------|
| **project.godot** | ✅ Fait | Configuration complète |
| **Scènes .tscn** | ✅ Fait | 6 scènes créées |
| **Input Map** | ✅ Fait | WASD, Espace, E, Escape |
| **Autoloads** | ✅ Fait | 4 managers enregistrés |
| **Assets graphiques** | 🟡 Partiel | Meshes procéduraux (OK pour MVP) |
| **Assets audio** | ⚠️ Manquant | Voir guide ci-dessous |

---

## 🎵 Assets Audio Requis

### Sons Essentiels (Priorité Haute)

| Fichier | Usage | Téléchargement |
|---------|-------|----------------|
| `ping_sonar.ogg` | AudioCompass navigation | [Freesound: Sonar](https://freesound.org/search/?q=sonar+beep) |
| `footstep_concrete.ogg` | Pas sur béton | [Freesound: Footsteps](https://freesound.org/search/?q=footstep+concrete) |
| `footstep_metal.ogg` | Pas sur métal | [Freesound: Metal Steps](https://freesound.org/search/?q=footstep+metal) |
| `attack_hit.ogg` | Impact attaque | [Freesound: Punch](https://freesound.org/search/?q=punch+hit) |
| `enemy_alert.ogg` | Détection joueur | [Freesound: Alert](https://freesound.org/search/?q=robot+alert) |
| `ui_click.ogg` | Clic menu | [Freesound: UI Click](https://freesound.org/search/?q=ui+click) |

### Sons d'Ambiance (Priorité Moyenne)

| Fichier | Usage |
|---------|-------|
| `rain_loop.ogg` | Pluie ambiante |
| `city_drone.ogg` | Bourdonnement ville |
| `neon_buzz.ogg` | Grésillement néon |
| `music_synthwave.ogg` | Musique de fond |

### Structure de dossiers

```
audio/
├── default_bus_layout.tres  ✅ Créé
├── music/
│   └── synthwave_loop.ogg
├── sfx/
│   ├── footsteps/
│   │   ├── concrete_01.ogg
│   │   ├── concrete_02.ogg
│   │   ├── metal_01.ogg
│   │   └── metal_02.ogg
│   ├── combat/
│   │   ├── attack_swing.ogg
│   │   └── attack_hit.ogg
│   ├── enemy/
│   │   ├── robot_alert.ogg
│   │   ├── robot_footstep.ogg
│   │   └── robot_death.ogg
│   └── ui/
│       ├── click.ogg
│       └── hover.ogg
├── navigation/
│   ├── ping_far.ogg
│   ├── ping_close.ogg
│   └── objective_reached.ogg
└── environment/
    ├── rain_loop.ogg
    ├── city_drone.ogg
    └── neon_buzz.ogg
```

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

- [x] project.godot configuré
- [x] Scènes principales créées
- [x] Input map défini
- [x] Autoloads enregistrés
- [x] Bus audio configurés
- [ ] 6 sons minimum ajoutés
- [ ] Police OpenDyslexic ajoutée
- [ ] Test sur Android
- [ ] Build APK signé
