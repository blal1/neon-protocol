# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

---

## [0.0.1] - 2024-12-15

### ✨ Ajouté

#### 🧭 Navigation & IA
- `ProceduralNavMeshManager.gd` — NavMesh dynamique avec baking asynchrone
- `CrowdAvoidanceSystem.gd` — Évitement de foule RVO avec détection de goulots

#### 🎭 Animation
- `CharacterStateMachine.gd` — FSM 24 états avec combo buffering et intégration AnimationTree

#### 🎮 Input
- `UnifiedInputManager.gd` — Abstraction cross-platform (Touch/Clavier/Souris)

#### ⚔️ Combat (Split du système)
- `DamageCalculator.gd` — Calcul de dégâts (types, armure, critiques, DoT)
- `HitboxManager.gd` — Gestion hitbox/hurtbox avec i-frames et block/parry
- `ProjectileManager.gd` — Pool de projectiles avec homing et ricochet

#### ⏱️ Temps
- `TimeDilationManager.gd` — Gestion bullet-time solo/multijoueur

#### 💥 VFX
- `VFXPoolManager.gd` — Pool de particules GPU (16 types VFX)

#### 💾 Persistance
- `ChunkStateSerializer.gd` — Sauvegarde état du monde procédural

#### 🖥️ Debug
- `DebugConsole.gd` — Console in-game avec 30+ commandes

#### 🎨 Shaders
- `cyberpunk_hologram.gdshader` — Hologrammes avec scanlines et glitch
- `triplanar_procedural.gdshader` — Mapping triplanaire anti-étirement
- `cyberpsychosis_screen.gdshader` — Post-process cyberpsychose
- `neon_volumetric.gdshader` — Néons volumétriques avec flicker
- `wet_surface.gdshader` — Surfaces mouillées avec reflets néon

#### 🌍 Monde
- `DistrictEcosystem.gd` — 7 districts avec économies distinctes
- `MeaningfulActivityGenerator.gd` — 15+ activités secondaires significatives

#### 📜 Scénarios
- `ScenarioFeteAuxBallons.gd` — Fête avec raid police
- `ScenarioJasmin.gd` — PNJ central tuable avec conséquences
- `ScenarioIAArgumentation.gd` — IA qui argumente pour son existence
- `ScenarioRobotTriste.gd` — Robot manifestant Ban-Captchas
- `ScenarioVeriteEnMouvement.gd` — Escorte bus hacktiviste
- `ScenarioCorpsEnRetard.gd` — Dette et cyberware repris

#### 🏴 Factions
- `FactionManager.gd` — 7 factions avec réputation et relations

#### 🤖 Systèmes Cyberpunk
- `CyberneticInstabilitySystem.gd` — Cyberpsychose et hallucinations
- `CyberpunkReputationSystem.gd` — Réputation multi-couche
- `OppressiveAdvertisingSystem.gd` — Publicité hypnotique
- `CyberwareManager.gd` — Implants avec humanité fragmentée
- `HackingSystem.gd` — Hacking avec ICE et traces

---

## [0.0.0] - 2024-12-01

### 🎉 Initial

- Structure de base du projet Godot 4.5
- Système de joueur avec mouvement et caméra
- Système d'accessibilité (TTS, Sonar)
- Interface utilisateur de base
- Audio et musique adaptative
- 19 autoloads configurés

---

## Types de Changements

- ✨ `Ajouté` — Nouvelles fonctionnalités
- 🔄 `Modifié` — Changements de fonctionnalités existantes
- 🗑️ `Déprécié` — Fonctionnalités bientôt supprimées
- ❌ `Supprimé` — Fonctionnalités supprimées
- 🐛 `Corrigé` — Corrections de bugs
- 🔒 `Sécurité` — Corrections de vulnérabilités
