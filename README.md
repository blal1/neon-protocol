# 🌆 NEON PROTOCOL

<div align="center">

![Godot](https://img.shields.io/badge/Godot-4.5+-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Mobile%20%2B%20Desktop-green?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-0.0.1-blue?style=for-the-badge)

**Action-RPG Cyberpunk Low-Poly avec Accessibilité Universelle**

*Un monde où chaque choix ferme des portes — et les ouvre rarement.*

[📖 Documentation](#-documentation) • [🎮 Fonctionnalités](#-fonctionnalités) • [🚀 Installation](#-installation) • [🤝 Contribuer](#-contribuer)

</div>

---

## 🎯 Vision du Projet

**Neon Protocol** est un Action-RPG Cyberpunk qui rejette le "power fantasy" traditionnel. Dans ce monde dystopique, vous êtes vulnérable, vos choix ont des conséquences permanentes, et la technologie qui vous augmente vous consume lentement.

### Philosophie de Design

- 🔴 **Vulnérabilité Permanente** — Pas de mode "surpuissant"
- ⚖️ **Choix Lourds** — Chaque décision ferme des portes
- 🌍 **Monde Vivant** — Vos actions modifient l'équilibre local
- ♿ **Accessibilité Totale** — TTS, navigation sonar, audio spatial

---

## 🎮 Fonctionnalités

### 🌆 Monde Ouvert Vertical

| Couche | Description |
|--------|-------------|
| **Corporate Tower** | Tours étincelantes, surveillance maximale |
| **Living City** | Ville dense, commerces, vie quotidienne |
| **Dead Ground** | Bidonvilles, ruines, exclus |
| **Sub-Network** | Souterrains, hackers, secrets |

### ⚔️ Combat Dual-Mode

- **Mode Réflexe** — Temps réel, stress, 60% précision
- **Mode Tactique** — Ralenti 25%, analyse cibles, +30% précision

### 🏴 7 Factions Dynamiques

```
NovaTech • Anarkingdom • Ban-Captchas • Cryptopirates
Police • Citizens • Nomads
```

### 🧠 Systèmes Cyberpunk

- **Cyberware** — Implants avec coûts cachés (humanité fragmentée)
- **Cyberpsychose** — Instabilité croissante, hallucinations
- **Hacking** — ICE, traces persistantes, alertes corpo
- **Réputation** — Multi-couche, antagonisme matriciel

### ♿ Accessibilité Révolutionnaire

- ✅ TTS (Text-to-Speech) natif
- ✅ Navigation sonar 3D
- ✅ Compatible NVDA/JAWS
- ✅ Filtres daltonisme
- ✅ Zones tactiles accessibles
- ✅ Audio spatial complet

---

## 📊 Architecture

```
scripts/                     121 fichiers
├── accessibility/           8 fichiers (TTS, sonar, navigation)
├── audio/                   8 fichiers (ambiance, pas, musique)
├── combat/                  4 fichiers (dégâts, hitbox, projectiles)
├── debug/                   1 fichier  (console in-game)
├── effects/                 5 fichiers (VFX, néons, pluie)
├── enemies/                 4 fichiers (robot, drone, turret, boss)
├── factions/                4 fichiers (7 factions définies)
├── gameplay/                10 fichiers (crafting, hacking, véhicules)
├── input/                   2 fichiers (cross-platform, haptic)
├── navigation/              2 fichiers (NavMesh dynamique, RVO)
├── network/                 2 fichiers (multiplayer sync)
├── player/                  5 fichiers (FSM 24 états, combat)
├── quests/scenarios/        6 fichiers (scénarios à choix)
├── systems/                 18 fichiers (save, inventory, time)
├── ui/                      15 fichiers (HUD, menus, joystick)
└── world/                   27 fichiers (chunks, districts, lieux)

scenes/                      17 fichiers
shaders/                     7 fichiers
```

### 📈 Statistiques

| Métrique | Valeur |
|----------|--------|
| **Scripts GDScript** | 121 |
| **Scènes TSCN** | 17 |
| **Shaders** | 7 |
| **Autoloads** | 19 |
| **Fichiers Audio** | 448 |
| **Districts** | 7 |
| **Factions** | 7 |

---

## 🚀 Installation

### Prérequis

- [Godot 4.5+](https://godotengine.org/download) (Standard ou .NET)
- Git

### Cloner le Repository

```bash
git clone https://github.com/blal1/neon-protocol.git
cd neon-protocol
```

### Ouvrir dans Godot

1. Lancez Godot 4.5+
2. **Import** → Sélectionnez le dossier `neon-protocol`
3. Attendez l'import des assets
4. **Play** (F5)

### Build Mobile

```bash
# Android
godot --export-release "Android" build/neon-protocol.apk

# iOS (requiert macOS)
godot --export-release "iOS" build/neon-protocol.ipa
```

---

## 🛠️ Développement

### Structure des Dossiers

```
neon-protocol/
├── assets/          # Modèles, textures, fonts
├── audio/           # Sons, musiques
├── data/            # JSON (dialogues, missions, items)
├── docs/            # Documentation
├── scenes/          # Scènes Godot (.tscn)
├── scripts/         # Scripts GDScript
├── shaders/         # Shaders GLSL
├── tests/           # Tests unitaires
└── project.godot    # Configuration projet
```

### Console de Debug

Appuyez sur **`** (backtick) en jeu pour ouvrir la console:

```
god                    # Mode invincible
spawn_item medkit 5    # Spawn items
quest_complete quest_1 # Complete une quête
set_rep novatech 50    # Modifier réputation
teleport 0 50 0        # Téléportation
```

### Commandes Utiles

```bash
# Lancer en mode debug
godot --debug

# Vérifier les erreurs
godot --headless --import

# Exporter
godot --export-release "Windows Desktop" build/game.exe
```

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE_REPORT.md](docs/ARCHITECTURE_REPORT.md) | Analyse complète du codebase |
| [GAME_PHILOSOPHY.md](docs/GAME_PHILOSOPHY.md) | Vision et design du jeu |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Guide de contribution |
| [CHANGELOG.md](CHANGELOG.md) | Historique des versions |

---

## 🤝 Contribuer

Les contributions sont les bienvenues ! Consultez [CONTRIBUTING.md](CONTRIBUTING.md) pour les guidelines.

### Workflow

1. Fork le repository
2. Créez une branche (`git checkout -b feature/amazing-feature`)
3. Commit (`git commit -m 'Add amazing feature'`)
4. Push (`git push origin feature/amazing-feature`)
5. Ouvrez une Pull Request

### Code Style

- **GDScript** — Suivez le [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- **Nommage** — snake_case pour variables/fonctions, PascalCase pour classes
- **Documentation** — Commentaires en français ou anglais

---

## 📜 License

Ce projet est sous licence **MIT**. Voir [LICENSE](LICENSE) pour plus de détails.

---

## 🙏 Remerciements

- **Godot Engine** — Moteur de jeu open-source
- **Community** — Tous les contributeurs

---

<div align="center">

**Fait avec 💜 et ☕**

*"Dans la nuit néon, même les ombres ont un prix."*

</div>
