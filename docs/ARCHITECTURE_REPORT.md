# NEON PROTOCOL - Rapport d'Architecture Complet

> **Version**: 0.0.1 | **Moteur**: Godot 4.5+ | **Plateforme**: Mobile + Desktop  
> **Dernière analyse**: 15 Décembre 2024  
> **Total**: 121 scripts | 17 scènes | 7 shaders | 19 autoloads

---

## 📊 Statistiques Globales

| Métrique | Valeur |
|----------|--------|
| **Scripts GDScript** | 121 |
| **Scènes TSCN** | 17 |
| **Shaders** | 7 |
| **Autoloads** | 19 |
| **Catégories** | 19 dossiers |
| **Fichiers Audio** | 448 |
| **Districts** | 7 |
| **Factions** | 7 |

---

# Table des Matières

1. [Accessibilité (8 scripts)](#accessibilité-8-scripts)
2. [Audio (8 scripts)](#audio-8-scripts)
3. [Caméra (2 scripts)](#caméra-2-scripts)
4. [Combat (4 scripts)](#combat-4-scripts)
5. [Composants (1 script)](#composants-1-script)
6. [Debug (1 script)](#debug-1-script)
7. [Effets (5 scripts)](#effets-5-scripts)
8. [Ennemis (4 scripts)](#ennemis-4-scripts)
9. [Factions (4 scripts)](#factions-4-scripts)
10. [Gameplay (10 scripts)](#gameplay-10-scripts)
11. [Input (2 scripts)](#input-2-scripts)
12. [Missions (1 script)](#missions-1-script)
13. [Navigation (2 scripts)](#navigation-2-scripts)
14. [Network (2 scripts)](#network-2-scripts)
15. [Player (5 scripts)](#player-5-scripts)
16. [Quêtes/Scénarios (6 scripts)](#quêtesscénarios-6-scripts)
17. [Systèmes (18 scripts)](#systèmes-18-scripts)
18. [UI (15 scripts)](#ui-15-scripts)
19. [World (23 scripts)](#world-23-scripts)
20. [Scènes (17 scènes)](#scènes-17-scènes)
21. [Shaders (7 shaders)](#shaders-7-shaders)

---

# Accessibilité (8 scripts)

| Script | Description |
|--------|-------------|
| [AccessibilityManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/accessibility/AccessibilityManager.gd) | Gestionnaire principal d'accessibilité |
| [AudioCueSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/accessibility/AudioCueSystem.gd) | Indices audio pour événements |
| [AudioTutorial.gd](file:///c:/Users/bilal/Downloads/tester/scripts/accessibility/AudioTutorial.gd) | Tutoriels audios guidés |
| [BlindAccessibilityManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/accessibility/BlindAccessibilityManager.gd) | Mode dédié joueurs aveugles |
| [CompassSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/accessibility/CompassSystem.gd) | Boussole audio directionnelle |
| [SonarAudioMap.gd](file:///c:/Users/bilal/Downloads/tester/scripts/accessibility/SonarAudioMap.gd) | Carte audio spatiale |
| [SonarNavigation.gd](file:///c:/Users/bilal/Downloads/tester/scripts/accessibility/SonarNavigation.gd) | Navigation par ping sonore |
| [TouchZoneController.gd](file:///c:/Users/bilal/Downloads/tester/scripts/accessibility/TouchZoneController.gd) | Zones tactiles larges pour mobile |

---

# Audio (8 scripts)

| Script | Description |
|--------|-------------|
| [AmbientAudioManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/audio/AmbientAudioManager.gd) | Sons d'ambiance par zone |
| [AudioCompass.gd](file:///c:/Users/bilal/Downloads/tester/scripts/audio/AudioCompass.gd) | Boussole sonore |
| [EnemyAudioController.gd](file:///c:/Users/bilal/Downloads/tester/scripts/audio/EnemyAudioController.gd) | Contrôleur audio ennemis |
| [EnemyAudioFeedback.gd](file:///c:/Users/bilal/Downloads/tester/scripts/audio/EnemyAudioFeedback.gd) | Retour audio actions ennemis |
| [FootstepAudioGenerator.gd](file:///c:/Users/bilal/Downloads/tester/scripts/audio/FootstepAudioGenerator.gd) | Génération pas par surface |
| [FootstepSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/audio/FootstepSystem.gd) | Système de pas intégré |
| [MusicManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/audio/MusicManager.gd) | Musique adaptative contextuelle |
| [TTSManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/audio/TTSManager.gd) | Text-to-Speech engine |

---

# Caméra (2 scripts)

| Script | Description |
|--------|-------------|
| [CameraController.gd](file:///c:/Users/bilal/Downloads/tester/scripts/camera/CameraController.gd) | Contrôle caméra principal |
| [FollowCamera.gd](file:///c:/Users/bilal/Downloads/tester/scripts/camera/FollowCamera.gd) | Caméra suivi joueur avec collision |

---

# Combat (4 scripts)

| Script | Description |
|--------|-------------|
| [DamageCalculator.gd](file:///c:/Users/bilal/Downloads/tester/scripts/combat/DamageCalculator.gd) | Calcul dégâts, armures, types, critiques |
| [HitboxManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/combat/HitboxManager.gd) | Hitbox/Hurtbox, i-frames, block/parry |
| [ProjectileManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/combat/ProjectileManager.gd) | Pooling projectiles, homing, ricochet |
| [TacticalCombatSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/combat/TacticalCombatSystem.gd) | Combat dual-mode Réflexe/Tactique |

---

# Composants (1 script)

| Script | Description |
|--------|-------------|
| [HealthComponent.gd](file:///c:/Users/bilal/Downloads/tester/scripts/components/HealthComponent.gd) | Composant vie/bouclier réutilisable |

---

# Debug (1 script)

| Script | Description |
|--------|-------------|
| [DebugConsole.gd](file:///c:/Users/bilal/Downloads/tester/scripts/debug/DebugConsole.gd) | Console in-game avec 30+ commandes |

**Commandes disponibles**: god, heal, kill, spawn_item, quest_complete, set_rep, teleport, slowmo, stats...

---

# Effets (5 scripts)

| Script | Description |
|--------|-------------|
| [ImpactEffects.gd](file:///c:/Users/bilal/Downloads/tester/scripts/effects/ImpactEffects.gd) | Effets d'impact (particules) |
| [NeonController.gd](file:///c:/Users/bilal/Downloads/tester/scripts/effects/NeonController.gd) | Contrôle néons dynamiques |
| [NeonRandomizer.gd](file:///c:/Users/bilal/Downloads/tester/scripts/effects/NeonRandomizer.gd) | Randomisation couleurs néons |
| [RainSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/effects/RainSystem.gd) | Système de pluie cyberpunk |
| [VFXPoolManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/effects/VFXPoolManager.gd) | Pool GPU particles (16 types VFX) |

---

# Ennemis (4 scripts)

| Script | Description |
|--------|-------------|
| [BossEnemy.gd](file:///c:/Users/bilal/Downloads/tester/scripts/enemies/BossEnemy.gd) | Boss avec phases |
| [EnemyDrone.gd](file:///c:/Users/bilal/Downloads/tester/scripts/enemies/EnemyDrone.gd) | Drone volant ennemi |
| [EnemyTurret.gd](file:///c:/Users/bilal/Downloads/tester/scripts/enemies/EnemyTurret.gd) | Tourelle statique |
| [SecurityRobot.gd](file:///c:/Users/bilal/Downloads/tester/scripts/enemies/SecurityRobot.gd) | Robot de sécurité corpo |

---

# Factions (4 scripts)

| Script | Description |
|--------|-------------|
| [Anarkingdom.gd](file:///c:/Users/bilal/Downloads/tester/scripts/factions/Anarkingdom.gd) | Faction anarchiste |
| [BanCaptchas.gd](file:///c:/Users/bilal/Downloads/tester/scripts/factions/BanCaptchas.gd) | Collectif IA/humains |
| [Cryptopirates.gd](file:///c:/Users/bilal/Downloads/tester/scripts/factions/Cryptopirates.gd) | Pirates de l'information |
| [FactionManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/factions/FactionManager.gd) | Gestionnaire 7 factions + réputation |

---

# Gameplay (10 scripts)

| Script | Description |
|--------|-------------|
| [CraftingSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/CraftingSystem.gd) | Système de crafting |
| [CutsceneManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/CutsceneManager.gd) | Gestion cinématiques |
| [DroneCompanion.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/DroneCompanion.gd) | Drone compagnon joueur |
| [HackingMinigame.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/HackingMinigame.gd) | Mini-jeu de hacking |
| [Pickup.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/Pickup.gd) | Items ramassables |
| [RandomEventManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/RandomEventManager.gd) | Événements aléatoires monde |
| [SpawnManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/SpawnManager.gd) | Gestion spawn ennemis/items |
| [StealthSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/StealthSystem.gd) | Système furtivité |
| [VehicleController.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/VehicleController.gd) | Contrôle véhicules |
| [WeaponSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/gameplay/WeaponSystem.gd) | Système d'armes |

---

# Input (2 scripts)

| Script | Description |
|--------|-------------|
| [HapticFeedback.gd](file:///c:/Users/bilal/Downloads/tester/scripts/input/HapticFeedback.gd) | Vibrations mobile |
| [UnifiedInputManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/input/UnifiedInputManager.gd) | Abstraction cross-platform |

---

# Missions (1 script)

| Script | Description |
|--------|-------------|
| [MissionManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/missions/MissionManager.gd) | Gestionnaire missions |

---

# Navigation (2 scripts)

| Script | Description |
|--------|-------------|
| [CrowdAvoidanceSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/navigation/CrowdAvoidanceSystem.gd) | RVO évitement foule |
| [ProceduralNavMeshManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/navigation/ProceduralNavMeshManager.gd) | NavMesh dynamique, baking async |

---

# Network (2 scripts)

| Script | Description |
|--------|-------------|
| [MultiplayerSync.gd](file:///c:/Users/bilal/Downloads/tester/scripts/network/MultiplayerSync.gd) | Synchronisation multijoueur |
| [NetworkManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/network/NetworkManager.gd) | Gestionnaire réseau |

---

# Player (5 scripts)

| Script | Description |
|--------|-------------|
| [CharacterStateMachine.gd](file:///c:/Users/bilal/Downloads/tester/scripts/player/CharacterStateMachine.gd) | FSM 24 états, combo buffer |
| [CombatManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/player/CombatManager.gd) | Gestion combat joueur |
| [Player.gd](file:///c:/Users/bilal/Downloads/tester/scripts/player/Player.gd) | Script principal joueur |
| [PlayerAnimationController.gd](file:///c:/Users/bilal/Downloads/tester/scripts/player/PlayerAnimationController.gd) | Contrôleur animations |
| [WeaponVisuals.gd](file:///c:/Users/bilal/Downloads/tester/scripts/player/WeaponVisuals.gd) | Visuels armes équipées |

---

# Quêtes/Scénarios (6 scripts)

| Script | Description |
|--------|-------------|
| [ScenarioCorpsEnRetard.gd](file:///c:/Users/bilal/Downloads/tester/scripts/quests/scenarios/ScenarioCorpsEnRetard.gd) | Dette cybernétique |
| [ScenarioFeteAuxBallons.gd](file:///c:/Users/bilal/Downloads/tester/scripts/quests/scenarios/ScenarioFeteAuxBallons.gd) | Fête + raid police |
| [ScenarioIAArgumentation.gd](file:///c:/Users/bilal/Downloads/tester/scripts/quests/scenarios/ScenarioIAArgumentation.gd) | IA argumente en 5 phases |
| [ScenarioJasmin.gd](file:///c:/Users/bilal/Downloads/tester/scripts/quests/scenarios/ScenarioJasmin.gd) | PNJ tuable + conséquences |
| [ScenarioRobotTriste.gd](file:///c:/Users/bilal/Downloads/tester/scripts/quests/scenarios/ScenarioRobotTriste.gd) | Robot manifestant |
| [ScenarioVeriteEnMouvement.gd](file:///c:/Users/bilal/Downloads/tester/scripts/quests/scenarios/ScenarioVeriteEnMouvement.gd) | Escorte bus hacktiviste |

---

# Systèmes (18 scripts)

| Script | Description |
|--------|-------------|
| [AchievementManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/AchievementManager.gd) | Trophées et succès |
| [CyberneticInstabilitySystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/CyberneticInstabilitySystem.gd) | Cyberpsychose, hallucinations |
| [CyberpunkReputationSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/CyberpunkReputationSystem.gd) | Réputation multi-couche |
| [CyberwareManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/CyberwareManager.gd) | Implants, humanité |
| [HackingSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/HackingSystem.gd) | Hacking ICE, traces |
| [InventoryManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/InventoryManager.gd) | Inventaire joueur |
| [LeaderboardManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/LeaderboardManager.gd) | Classements |
| [LocalizationManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/LocalizationManager.gd) | Traductions |
| [ObjectPool.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/ObjectPool.gd) | Pool d'objets |
| [OppressiveAdvertisingSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/OppressiveAdvertisingSystem.gd) | Publicité AR |
| [PerformanceOptimizer.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/PerformanceOptimizer.gd) | Optimisation runtime |
| [ReputationManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/ReputationManager.gd) | Réputation basique |
| [SaveManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/SaveManager.gd) | Sauvegarde/Chargement |
| [ShopSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/ShopSystem.gd) | Magasins |
| [SkillTreeManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/SkillTreeManager.gd) | Arbre de compétences |
| [StatsManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/StatsManager.gd) | Statistiques joueur |
| [TimeDilationManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/TimeDilationManager.gd) | Bullet-time solo/multi |
| [TutorialManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/systems/TutorialManager.gd) | Tutoriels guidés |

---

# UI (15 scripts)

| Script | Description |
|--------|-------------|
| [AccessibleButton.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/AccessibleButton.gd) | Bouton accessible TTS |
| [CraftingUI.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/CraftingUI.gd) | Interface crafting |
| [DialogueSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/DialogueSystem.gd) | Système dialogues |
| [FloatingDamage.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/FloatingDamage.gd) | Dégâts flottants |
| [GameHUD.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/GameHUD.gd) | HUD principal |
| [GameOverManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/GameOverManager.gd) | Gestionnaire game over |
| [GameOverMenu.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/GameOverMenu.gd) | Écran game over |
| [MainMenu.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/MainMenu.gd) | Menu principal |
| [Minimap.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/Minimap.gd) | Mini-carte |
| [MultiplayerLobby.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/MultiplayerLobby.gd) | Lobby multijoueur |
| [OptionsMenu.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/OptionsMenu.gd) | Menu options |
| [PauseMenu.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/PauseMenu.gd) | Menu pause |
| [SimpleJoystick.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/SimpleJoystick.gd) | Joystick simplifié |
| [ToastNotification.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/ToastNotification.gd) | Notifications toast |
| [VirtualJoystick.gd](file:///c:/Users/bilal/Downloads/tester/scripts/ui/VirtualJoystick.gd) | Joystick virtuel tactile |

---

# World (23 scripts)

## Core

| Script | Description |
|--------|-------------|
| [ChunkStreamer.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/ChunkStreamer.gd) | Streaming chunks |
| [ChunkStateSerializer.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/ChunkStateSerializer.gd) | Persistance état monde |
| [CityManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/CityManager.gd) | Gestionnaire ville |
| [DayNightCycle.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/DayNightCycle.gd) | Cycle jour/nuit |
| [DistanceCuller.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/DistanceCuller.gd) | Culling par distance |
| [DistrictEcosystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/DistrictEcosystem.gd) | 7 districts |
| [Door.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/Door.gd) | Portes |
| [LayerBiomeConfig.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/LayerBiomeConfig.gd) | Config biomes |
| [LODManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/LODManager.gd) | Level of Detail |
| [MeaningfulActivityGenerator.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/MeaningfulActivityGenerator.gd) | 15+ activités |
| [TutorialLevel.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/TutorialLevel.gd) | Niveau tutoriel |
| [WorldLayerManager.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/WorldLayerManager.gd) | 4 couches verticales |
| [WorldLayerTypes.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/WorldLayerTypes.gd) | Types de couches |

## Layer Generators

| Script | Couche |
|--------|--------|
| [CorporateTowerGenerator.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/layers/CorporateTowerGenerator.gd) | Corporate Tower |
| [LivingCityGenerator.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/layers/LivingCityGenerator.gd) | Living City |
| [DeadGroundGenerator.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/layers/DeadGroundGenerator.gd) | Dead Ground |
| [SubNetworkGenerator.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/layers/SubNetworkGenerator.gd) | Sub-Network |

## Locations

| Script | Lieu |
|--------|------|
| [FoodStall.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/locations/FoodStall.gd) | Stand nourriture |
| [HumanChopShop.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/locations/HumanChopShop.gd) | Marché organes |
| [MetroSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/locations/MetroSystem.gd) | Métro |
| [QuietRoom.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/locations/QuietRoom.gd) | QuietRoom™ |
| [VerticalFarm.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/locations/VerticalFarm.gd) | Ferme Verticale |

## Effects

| Script | Description |
|--------|-------------|
| [ToxicFogSystem.gd](file:///c:/Users/bilal/Downloads/tester/scripts/world/effects/ToxicFogSystem.gd) | Brouillard toxique |

---

# Scènes (17 scènes)

| Catégorie | Scènes |
|-----------|--------|
| **Main** | Main.tscn, MainMenu.tscn |
| **Player** | Player.tscn |
| **Enemies** | SecurityRobot.tscn |
| **Gameplay** | CyberMotorcycle.tscn, DroneCompanion.tscn |
| **UI** | GameHUD.tscn, PauseMenu.tscn, OptionsMenu.tscn, GameOverMenu.tscn, CraftingUI.tscn, HackingMinigame.tscn, MultiplayerLobby.tscn, TutorialPanel.tscn, VirtualJoystick.tscn |
| **World** | CityBlock.tscn, TutorialLevel.tscn |

---

# Shaders (7 shaders)

| Shader | Type | Description |
|--------|------|-------------|
| [colorblind_filter.gdshader](file:///c:/Users/bilal/Downloads/tester/shaders/colorblind_filter.gdshader) | Post-Process | Filtres daltonisme |
| [cyberpsychosis_screen.gdshader](file:///c:/Users/bilal/Downloads/tester/shaders/cyberpsychosis_screen.gdshader) | Post-Process | Effets cyberpsychose |
| [cyberpunk_hologram.gdshader](file:///c:/Users/bilal/Downloads/tester/shaders/cyberpunk_hologram.gdshader) | Spatial | Hologrammes scanlines |
| [neon_glow.gdshader](file:///c:/Users/bilal/Downloads/tester/shaders/neon_glow.gdshader) | Spatial | Glow néons basique |
| [neon_volumetric.gdshader](file:///c:/Users/bilal/Downloads/tester/shaders/neon_volumetric.gdshader) | Spatial | Néons volumétriques |
| [triplanar_procedural.gdshader](file:///c:/Users/bilal/Downloads/tester/shaders/triplanar_procedural.gdshader) | Spatial | Mapping procédural |
| [wet_surface.gdshader](file:///c:/Users/bilal/Downloads/tester/shaders/wet_surface.gdshader) | Spatial | Surfaces mouillées |

---

# Récapitulatif

```
scripts/                     121 fichiers
├── accessibility/           8 fichiers
├── audio/                   8 fichiers
├── camera/                  2 fichiers
├── combat/                  4 fichiers
├── components/              1 fichier
├── debug/                   1 fichier
├── effects/                 5 fichiers
├── enemies/                 4 fichiers
├── factions/                4 fichiers
├── gameplay/                10 fichiers
├── input/                   2 fichiers
├── missions/                1 fichier
├── navigation/              2 fichiers
├── network/                 2 fichiers
├── player/                  5 fichiers
├── quests/scenarios/        6 fichiers
├── systems/                 18 fichiers
├── ui/                      15 fichiers
└── world/                   23 fichiers

scenes/                      17 fichiers
shaders/                     7 fichiers
```

---

*Généré automatiquement - Neon Protocol v0.0.1 - 15 Décembre 2024*
