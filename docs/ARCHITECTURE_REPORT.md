# NEON PROTOCOL - Rapport d'Architecture Complet

> **Version**: 0.0.1 | **Moteur**: Godot 4.6.3 | **Plateforme**: Mobile + Desktop
> **Dernière analyse**: 11 Juin 2026
> **Total**: 126 scripts | 17 scènes | 7 shaders | 37 autoloads

---

## 📊 Statistiques Globales

| Métrique | Valeur |
|----------|--------|
| **Scripts GDScript** | 126 |
| **Scènes TSCN** | 17 |
| **Shaders** | 7 |
| **Autoloads** | 37 |
| **Catégories** | 22 dossiers |
| **Fichiers Audio** | 448 |
| **Districts** | 7 |
| **Factions** | 7 |

> **Note historique**: la version précédente de ce rapport (Déc. 2024) annonçait 121 scripts / 19 autoloads
> avec des liens pointant vers `c:/Users/bilal/Downloads/tester/...`. Le projet a été déplacé vers
> `neon-protocol`, mis à jour vers Godot 4.6, et plusieurs systèmes audio/UI ont été ajoutés ou complétés.
> Les liens ci-dessous sont relatifs au dossier `docs/`.

---

# Table des Matières

1. [Accessibilité (9 scripts)](#accessibilité-9-scripts)
2. [Audio (9 scripts)](#audio-9-scripts)
3. [Caméra (2 scripts)](#caméra-2-scripts)
4. [Combat (4 scripts)](#combat-4-scripts)
5. [Composants (1 script)](#composants-1-script)
6. [Debug (1 script)](#debug-1-script)
7. [Effets (4 scripts)](#effets-4-scripts)
8. [Ennemis (4 scripts)](#ennemis-4-scripts)
9. [Factions (4 scripts)](#factions-4-scripts)
10. [Gameplay (10 scripts)](#gameplay-10-scripts)
11. [Input (2 scripts)](#input-2-scripts)
12. [Missions (1 script)](#missions-1-script)
13. [Navigation (2 scripts)](#navigation-2-scripts)
14. [Network (2 scripts)](#network-2-scripts)
15. [Player (5 scripts)](#player-5-scripts)
16. [Quêtes/Scénarios (6 scripts)](#quêtesscénarios-6-scripts)
17. [Systèmes (20 scripts)](#systèmes-20-scripts)
18. [UI (17 scripts)](#ui-17-scripts)
19. [World (23 scripts)](#world-23-scripts)
20. [Scènes (17 scènes)](#scènes-17-scènes)
21. [Shaders (7 shaders)](#shaders-7-shaders)
22. [Autoloads (37)](#autoloads-37)
23. [Prochaines Étapes / TODO](#-prochaines-étapes--todo)
24. [Fonctionnalités à Ajouter](#-fonctionnalités-à-ajouter)

---

# Accessibilité (9 scripts)

| Script | Description |
|--------|-------------|
| [AccessibilityManager.gd](../scripts/accessibility/AccessibilityManager.gd) | Préférences d'accessibilité globales, sauvegarde JSON (Autoload) |
| [AudioCueSystem.gd](../scripts/accessibility/AudioCueSystem.gd) | Indices audio 3D pour événements/combat |
| [AudioTutorial.gd](../scripts/accessibility/AudioTutorial.gd) | Tutoriel 100% audio avec TTS |
| [BlindAccessibilityManager.gd](../scripts/accessibility/BlindAccessibilityManager.gd) | Mode dédié joueurs aveugles : TTS, audio 3D, coordination tactile (Autoload) |
| [CompassSystem.gd](../scripts/accessibility/CompassSystem.gd) | Boussole audio directionnelle (points cardinaux) |
| [KeyboardAccessibilityManager.gd](../scripts/accessibility/KeyboardAccessibilityManager.gd) | **Nouveau** — Accessibilité clavier complète pour joueurs aveugles PC : ciblage + TTS (Autoload) |
| [SonarAudioMap.gd](../scripts/accessibility/SonarAudioMap.gd) | Carte audio spatiale (ping de localisation) |
| [SonarNavigation.gd](../scripts/accessibility/SonarNavigation.gd) | Navigation par ping sonore vers objectif |
| [TouchZoneController.gd](../scripts/accessibility/TouchZoneController.gd) | Zones tactiles larges pour joueurs aveugles (tap/swipe/hold) |

---

# Audio (9 scripts)

| Script | Description |
|--------|-------------|
| [AmbientAudioManager.gd](../scripts/audio/AmbientAudioManager.gd) | Sons d'ambiance cyberpunk (pluie, néons, trafic, drones) (Autoload) |
| [AudioCompass.gd](../scripts/audio/AudioCompass.gd) | Boussole sonore 3D vers l'objectif |
| [EnemyAudioController.gd](../scripts/audio/EnemyAudioController.gd) | **Mis à jour** — Contrôleur audio spatial des ennemis (footstep/idle/alert/attack/death par type), maintenant Autoload |
| [EnemyAudioFeedback.gd](../scripts/audio/EnemyAudioFeedback.gd) | Retour audio par ennemi (script enfant, exporte des AudioStream par action) — non câblé actuellement |
| [FootstepAudioGenerator.gd](../scripts/audio/FootstepAudioGenerator.gd) | Génération procédurale de pas selon le terrain |
| [FootstepSystem.gd](../scripts/audio/FootstepSystem.gd) | Système de pas 3D selon surface/vitesse |
| [MusicManager.gd](../scripts/audio/MusicManager.gd) | Musique adaptative contextuelle (Autoload) |
| [SFXManager.gd](../scripts/audio/SFXManager.gd) | **Nouveau** — SFX UI 2D (`play_ui`) et SFX combat 3D positionnel (`play_combat`), pool de lecteurs (Autoload) |
| [TTSManager.gd](../scripts/audio/TTSManager.gd) | Text-to-Speech engine, file de priorité (Autoload) |

---

# Caméra (2 scripts)

| Script | Description |
|--------|-------------|
| [CameraController.gd](../scripts/camera/CameraController.gd) | Contrôle caméra TPS tactile |
| [FollowCamera.gd](../scripts/camera/FollowCamera.gd) | Caméra suivi joueur avec collision |

---

# Combat (4 scripts)

| Script | Description |
|--------|-------------|
| [DamageCalculator.gd](../scripts/combat/DamageCalculator.gd) | Calcul dégâts, armures, types, résistances |
| [HitboxManager.gd](../scripts/combat/HitboxManager.gd) | Hitbox/Hurtbox, collisions de combat physiques |
| [ProjectileManager.gd](../scripts/combat/ProjectileManager.gd) | Pooling projectiles, balistique, homing, ricochet |
| [TacticalCombatSystem.gd](../scripts/combat/TacticalCombatSystem.gd) | Combat dual-mode Réflexe (temps réel) / Tactique (ralenti) |

---

# Composants (1 script)

| Script | Description |
|--------|-------------|
| [HealthComponent.gd](../scripts/components/HealthComponent.gd) | Composant vie/dégâts/mort réutilisable, hooks de sync multijoueur |

---

# Debug (1 script)

| Script | Description |
|--------|-------------|
| [DebugConsole.gd](../scripts/debug/DebugConsole.gd) | Console in-game avec 30+ commandes (Autoload) |

**Commandes disponibles**: god, heal, kill, spawn_item, quest_complete, set_rep, teleport, slowmo, stats...

---

# Effets (4 scripts)

> ⚠️ `ImpactEffects.gd` listé dans la version précédente de ce rapport n'existe plus dans le dépôt.

| Script | Description |
|--------|-------------|
| [NeonController.gd](../scripts/effects/NeonController.gd) | Contrôle shader néon (pulsation, changement de couleur) |
| [NeonRandomizer.gd](../scripts/effects/NeonRandomizer.gd) | Couleurs néon aléatoires + flicker |
| [RainSystem.gd](../scripts/effects/RainSystem.gd) | Pluie cyberpunk optimisée mobile, suit le joueur, pas de pluie en intérieur |
| [VFXPoolManager.gd](../scripts/effects/VFXPoolManager.gd) | Pool de GPU particles (explosions, impacts, muzzle flashes) (Autoload) |

---

# Ennemis (4 scripts)

| Script | Description |
|--------|-------------|
| [BossEnemy.gd](../scripts/enemies/BossEnemy.gd) | Boss multi-phases avec attaques spéciales |
| [EnemyDrone.gd](../scripts/enemies/EnemyDrone.gd) | Drone volant avec attaques à distance |
| [EnemyTurret.gd](../scripts/enemies/EnemyTurret.gd) | Tourelle statique, rotation + tir auto, hackable |
| [SecurityRobot.gd](../scripts/enemies/SecurityRobot.gd) | Robot de sécurité, FSM PATROL/CHASE/ATTACK/RETURN |

> Les bugs de comportement de `EnemyDrone.gd` et `EnemyTurret.gd` (états bloqués / mismatch CHASE→ATTACK)
> ont été corrigés et vérifiés en runtime via le plugin Godot MCP Pro.

---

# Factions (4 scripts)

| Script | Description |
|--------|-------------|
| [Anarkingdom.gd](../scripts/factions/Anarkingdom.gd) | Faction anarchiste, élections violentes paradoxales |
| [BanCaptchas.gd](../scripts/factions/BanCaptchas.gd) | Mouvement pour les droits de l'IA, quêtes philosophiques |
| [Cryptopirates.gd](../scripts/factions/Cryptopirates.gd) | Hackers nomades, diffusion de vérité (bus/drones/pirate waves) |
| [FactionManager.gd](../scripts/factions/FactionManager.gd) | Gestionnaire 7 factions, relations, quêtes, réputation, fins (Autoload) |

---

# Gameplay (10 scripts)

| Script | Description |
|--------|-------------|
| [CraftingSystem.gd](../scripts/gameplay/CraftingSystem.gd) | Système de crafting (consommables, munitions, upgrades, hacking) |
| [CutsceneManager.gd](../scripts/gameplay/CutsceneManager.gd) | Gestion cinématiques et séquences scriptées (Autoload) |
| [DroneCompanion.gd](../scripts/gameplay/DroneCompanion.gd) | Drone compagnon IA du joueur |
| [HackingMinigame.gd](../scripts/gameplay/HackingMinigame.gd) | Mini-jeu de hacking |
| [Pickup.gd](../scripts/gameplay/Pickup.gd) | Items ramassables (crédits, vie, munitions, énergie, XP, clés, data chips) |
| [RandomEventManager.gd](../scripts/gameplay/RandomEventManager.gd) | Événements aléatoires d'exploration (embuscade, vendeur, cache, etc.) |
| [SpawnManager.gd](../scripts/gameplay/SpawnManager.gd) | Gestionnaire de vagues d'ennemis |
| [StealthSystem.gd](../scripts/gameplay/StealthSystem.gd) | Système de furtivité |
| [VehicleController.gd](../scripts/gameplay/VehicleController.gd) | Contrôleur de véhicule (Moto Cyberpunk) |
| [WeaponSystem.gd](../scripts/gameplay/WeaponSystem.gd) | Système d'armes variées |

---

# Input (2 scripts)

| Script | Description |
|--------|-------------|
| [HapticFeedback.gd](../scripts/input/HapticFeedback.gd) | Vibrations mobile (Autoload) |
| [UnifiedInputManager.gd](../scripts/input/UnifiedInputManager.gd) | Abstraction d'entrée cross-platform mobile/desktop (Autoload) |

---

# Missions (1 script)

| Script | Description |
|--------|-------------|
| [MissionManager.gd](../scripts/missions/MissionManager.gd) | Charge et suit les missions depuis JSON (Autoload) |

---

# Navigation (2 scripts)

| Script | Description |
|--------|-------------|
| [CrowdAvoidanceSystem.gd](../scripts/navigation/CrowdAvoidanceSystem.gd) | Évitement de foule RVO, optimisé pour ruelles étroites |
| [ProceduralNavMeshManager.gd](../scripts/navigation/ProceduralNavMeshManager.gd) | NavMesh dynamique pour monde procédural, baking async |

---

# Network (2 scripts)

| Script | Description |
|--------|-------------|
| [MultiplayerSync.gd](../scripts/network/MultiplayerSync.gd) | Synchronisation position/rotation/animations multijoueur |
| [NetworkManager.gd](../scripts/network/NetworkManager.gd) | Connexions, sync, lobby (Autoload) |

---

# Player (5 scripts)

| Script | Description |
|--------|-------------|
| [CharacterStateMachine.gd](../scripts/player/CharacterStateMachine.gd) | FSM des transitions d'animation (Idle/Attack/HitStun/Roll) |
| [CombatManager.gd](../scripts/player/CombatManager.gd) | Auto-targeting (5m), attaques, combos, **SFX d'attaque/impact câblés** |
| [Player.gd](../scripts/player/Player.gd) | Mouvement et contrôles mobiles (joystick + boutons d'action) |
| [PlayerAnimationController.gd](../scripts/player/PlayerAnimationController.gd) | Animations procédurales par tweens/transforms |
| [WeaponVisuals.gd](../scripts/player/WeaponVisuals.gd) | Modèles 3D et animations des armes équipées |

---

# Quêtes/Scénarios (6 scripts)

Détails (déclencheurs, choix, conséquences) : [QUESTS_GUIDE.md](QUESTS_GUIDE.md).

| Script | Description |
|--------|-------------|
| [ScenarioCorpsEnRetard.gd](../scripts/quests/scenarios/ScenarioCorpsEnRetard.gd) | Dette cybernétique, repossession d'implants |
| [ScenarioFeteAuxBallons.gd](../scripts/quests/scenarios/ScenarioFeteAuxBallons.gd) | Fête illégale + raid policier |
| [ScenarioIAArgumentation.gd](../scripts/quests/scenarios/ScenarioIAArgumentation.gd) | IA argumente son existence (5 phases) |
| [ScenarioJasmin.gd](../scripts/quests/scenarios/ScenarioJasmin.gd) | PNJ manipulateur tuable, conséquences sur le monde |
| [ScenarioRobotTriste.gd](../scripts/quests/scenarios/ScenarioRobotTriste.gd) | Robot manifestant "BAN CAPTCHAS" |
| [ScenarioVeriteEnMouvement.gd](../scripts/quests/scenarios/ScenarioVeriteEnMouvement.gd) | Escorte de bus hacktiviste sous le feu |

---

# Systèmes (20 scripts)

| Script | Description |
|--------|-------------|
| [AchievementManager.gd](../scripts/systems/AchievementManager.gd) | Trophées et succès, progression et récompenses (Autoload) |
| [CyberneticInstabilitySystem.gd](../scripts/systems/CyberneticInstabilitySystem.gd) | Cyberpsychose, instabilité liée aux implants (Autoload) |
| [CyberpunkReputationSystem.gd](../scripts/systems/CyberpunkReputationSystem.gd) | Réputation multi-couche, interdépendances entre groupes (Autoload) |
| [CyberwareManager.gd](../scripts/systems/CyberwareManager.gd) | Implants, humanité, cyberware décisionnel (Autoload) |
| [HackingSystem.gd](../scripts/systems/HackingSystem.gd) | Hacking persistant avec conséquences et traces (Autoload) |
| [InventoryManager.gd](../scripts/systems/InventoryManager.gd) | Inventaire joueur (Autoload) |
| [LazyLoader.gd](../scripts/systems/LazyLoader.gd) | **Nouveau** — Charge les systèmes lourds à la demande (Autoload) |
| [LeaderboardManager.gd](../scripts/systems/LeaderboardManager.gd) | Scores et classements locaux (Autoload) |
| [LocalizationManager.gd](../scripts/systems/LocalizationManager.gd) | Traductions et changement de langue (Autoload) |
| [ObjectPool.gd](../scripts/systems/ObjectPool.gd) | Pool d'objets réutilisables |
| [OppressiveAdvertisingSystem.gd](../scripts/systems/OppressiveAdvertisingSystem.gd) | Kiosques publicitaires payant les pauvres pour regarder des pubs (Autoload) |
| [PerformanceManager.gd](../scripts/systems/PerformanceManager.gd) | **Nouveau** — Détecte le type d'appareil et applique les paramètres de qualité (Autoload) |
| [PerformanceOptimizer.gd](../scripts/systems/PerformanceOptimizer.gd) | Optimisations runtime : streaming audio, occlusion, LOD |
| [ReputationManager.gd](../scripts/systems/ReputationManager.gd) | Réputation basique avec les factions (Autoload) |
| [SaveManager.gd](../scripts/systems/SaveManager.gd) | Sauvegarde/chargement de la progression (Autoload) |
| [ShopSystem.gd](../scripts/systems/ShopSystem.gd) | Achats/ventes avec marchands |
| [SkillTreeManager.gd](../scripts/systems/SkillTreeManager.gd) | Compétences, points de talent, upgrades (Autoload) |
| [StatsManager.gd](../scripts/systems/StatsManager.gd) | Statistiques joueur : kills, deaths, temps, etc. (Autoload) |
| [TimeDilationManager.gd](../scripts/systems/TimeDilationManager.gd) | Bullet-time solo et multijoueur (Autoload) |
| [TutorialManager.gd](../scripts/systems/TutorialManager.gd) | Tutoriels guidés interactifs (Autoload) |

---

# UI (17 scripts)

| Script | Description |
|--------|-------------|
| [AccessibleButton.gd](../scripts/ui/AccessibleButton.gd) | Bouton accessible avec TTS et sons UI |
| [CraftingUI.gd](../scripts/ui/CraftingUI.gd) | Interface de crafting |
| [DialogueSystem.gd](../scripts/ui/DialogueSystem.gd) | Système de dialogue, effet machine à écrire |
| [FloatingDamage.gd](../scripts/ui/FloatingDamage.gd) | Dégâts flottants au-dessus des ennemis/joueur |
| [GameHUD.gd](../scripts/ui/GameHUD.gd) | HUD principal : mission, santé, infos |
| [GameOverManager.gd](../scripts/ui/GameOverManager.gd) | Gestion écran de mort, respawn, continue |
| [GameOverMenu.gd](../scripts/ui/GameOverMenu.gd) | Écran affiché à la mort du joueur |
| [MainMenu.gd](../scripts/ui/MainMenu.gd) | Menu principal — **sons hover/click câblés via SFXManager** |
| [Minimap.gd](../scripts/ui/Minimap.gd) | Mini-carte joueur/ennemis/objectifs |
| [MultiplayerLobby.gd](../scripts/ui/MultiplayerLobby.gd) | Interface lobby, host/join |
| [OptionsMenu.gd](../scripts/ui/OptionsMenu.gd) | Menu d'options avec accessibilité |
| [PauseMenu.gd](../scripts/ui/PauseMenu.gd) | Menu de pause in-game |
| [PlatformUIController.gd](../scripts/ui/PlatformUIController.gd) | **Nouveau** — Adapte l'UI selon la plateforme (Mobile vs Desktop) (Autoload) |
| [SafeAreaManager.gd](../scripts/ui/SafeAreaManager.gd) | **Nouveau** — Gère encoches, coins arrondis, zones système mobile (Autoload) |
| [SimpleJoystick.gd](../scripts/ui/SimpleJoystick.gd) | Joystick virtuel minimaliste mobile |
| [ToastNotification.gd](../scripts/ui/ToastNotification.gd) | Notifications temporaires (achievements, etc.) (Autoload) |
| [VirtualJoystick.gd](../scripts/ui/VirtualJoystick.gd) | Joystick virtuel tactile optimisé mobile |

---

# World (23 scripts)

## Core

| Script | Description |
|--------|-------------|
| [ChunkStreamer.gd](../scripts/world/ChunkStreamer.gd) | Streaming de chunks |
| [ChunkStateSerializer.gd](../scripts/world/ChunkStateSerializer.gd) | Persistance de l'état du monde procédural |
| [CityManager.gd](../scripts/world/CityManager.gd) | Générateur de ville procédural (grille 2D) |
| [DayNightCycle.gd](../scripts/world/DayNightCycle.gd) | Cycle jour/nuit |
| [DistanceCuller.gd](../scripts/world/DistanceCuller.gd) | Culling par distance (LOD simple) |
| [DistrictEcosystem.gd](../scripts/world/DistrictEcosystem.gd) | Quartiers comme écosystèmes vivants (7 districts) |
| [Door.gd](../scripts/world/Door.gd) | Portes interactives (NONE/KEY/HACK/SWITCH/MISSION) |
| [LayerBiomeConfig.gd](../scripts/world/LayerBiomeConfig.gd) | Configuration de biome par couche (Resource) |
| [LODManager.gd](../scripts/world/LODManager.gd) | Level of Detail simple |
| [MeaningfulActivityGenerator.gd](../scripts/world/MeaningfulActivityGenerator.gd) | 15+ activités secondaires significatives |
| [TutorialLevel.gd](../scripts/world/TutorialLevel.gd) | Contrôleur du niveau tutoriel |
| [WorldLayerManager.gd](../scripts/world/WorldLayerManager.gd) | Gestionnaire global des 4 couches verticales NEON DELTA (Autoload) |
| [WorldLayerTypes.gd](../scripts/world/WorldLayerTypes.gd) | Définition des types de couches |

## Layer Generators

| Script | Couche |
|--------|--------|
| [CorporateTowerGenerator.gd](../scripts/world/layers/CorporateTowerGenerator.gd) | Corporate Tower |
| [LivingCityGenerator.gd](../scripts/world/layers/LivingCityGenerator.gd) | Living City |
| [DeadGroundGenerator.gd](../scripts/world/layers/DeadGroundGenerator.gd) | Dead Ground |
| [SubNetworkGenerator.gd](../scripts/world/layers/SubNetworkGenerator.gd) | Sub-Network (souterrain) |

## Locations

| Script | Lieu |
|--------|------|
| [FoodStall.gd](../scripts/world/locations/FoodStall.gd) | Food trucks & noodle stalls |
| [HumanChopShop.gd](../scripts/world/locations/HumanChopShop.gd) | Cliniques de récupération humaine |
| [MetroSystem.gd](../scripts/world/locations/MetroSystem.gd) | Métro & rails aériens |
| [QuietRoom.gd](../scripts/world/locations/QuietRoom.gd) | Cafés QuietRoom™ (zones sûres EMF) |
| [VerticalFarm.gd](../scripts/world/locations/VerticalFarm.gd) | Fermes verticales & viande synthétique |

## Effects

| Script | Description |
|--------|-------------|
| [ToxicFogSystem.gd](../scripts/world/effects/ToxicFogSystem.gd) | Brouillard toxique |

---

# Scènes (17 scènes)

| Catégorie | Scènes |
|-----------|--------|
| **Main** | [Main.tscn](../scenes/main/Main.tscn) (TestLevel + skyline de bâtiments .glb), [MainMenu.tscn](../scenes/main/MainMenu.tscn) |
| **Player** | [Player.tscn](../scenes/player/Player.tscn) |
| **Enemies** | [SecurityRobot.tscn](../scenes/enemies/SecurityRobot.tscn) |
| **Gameplay** | [CyberMotorcycle.tscn](../scenes/gameplay/CyberMotorcycle.tscn), [DroneCompanion.tscn](../scenes/gameplay/DroneCompanion.tscn) |
| **UI** | [GameHUD.tscn](../scenes/ui/GameHUD.tscn), [PauseMenu.tscn](../scenes/ui/PauseMenu.tscn), [OptionsMenu.tscn](../scenes/ui/OptionsMenu.tscn), [GameOverMenu.tscn](../scenes/ui/GameOverMenu.tscn), [CraftingUI.tscn](../scenes/ui/CraftingUI.tscn), [HackingMinigame.tscn](../scenes/ui/HackingMinigame.tscn), [MultiplayerLobby.tscn](../scenes/ui/MultiplayerLobby.tscn), [TutorialPanel.tscn](../scenes/ui/TutorialPanel.tscn), [VirtualJoystick.tscn](../scenes/ui/VirtualJoystick.tscn) |
| **World** | [CityBlock.tscn](../scenes/world/CityBlock.tscn) — niveau alternatif jouable (accessible via "🏙 NIVEAU ALTERNATIF" dans MainMenu), [TutorialLevel.tscn](../scenes/world/TutorialLevel.tscn) |

> Le nom de fichier réel du HUD est `GameHUD.tscn` (anciennement référencé comme `HUD.tscn` dans certains
> docs — corrigé dans `SCENES_GUIDE.md`).

---

# Shaders (7 shaders)

| Shader | Type | Description |
|--------|------|-------------|
| [colorblind_filter.gdshader](../shaders/colorblind_filter.gdshader) | Post-Process | Filtres daltonisme |
| [cyberpsychosis_screen.gdshader](../shaders/cyberpsychosis_screen.gdshader) | Post-Process | Effets cyberpsychose |
| [cyberpunk_hologram.gdshader](../shaders/cyberpunk_hologram.gdshader) | Spatial | Hologrammes scanlines |
| [neon_glow.gdshader](../shaders/neon_glow.gdshader) | Spatial | Glow néons basique |
| [neon_volumetric.gdshader](../shaders/neon_volumetric.gdshader) | Spatial | Néons volumétriques |
| [triplanar_procedural.gdshader](../shaders/triplanar_procedural.gdshader) | Spatial | Mapping procédural |
| [wet_surface.gdshader](../shaders/wet_surface.gdshader) | Spatial | Surfaces mouillées |

---

# Autoloads (37)

Ordre d'enregistrement dans `project.godot` :

| # | Autoload | Script |
|---|----------|--------|
| 1 | AccessibilityManager | scripts/accessibility/AccessibilityManager.gd |
| 2 | BlindAccessibilityManager | scripts/accessibility/BlindAccessibilityManager.gd |
| 3 | MissionManager | scripts/missions/MissionManager.gd |
| 4 | TTSManager | scripts/audio/TTSManager.gd |
| 5 | SaveManager | scripts/systems/SaveManager.gd |
| 6 | InventoryManager | scripts/systems/InventoryManager.gd |
| 7 | TutorialManager | scripts/systems/TutorialManager.gd |
| 8 | AchievementManager | scripts/systems/AchievementManager.gd |
| 9 | LeaderboardManager | scripts/systems/LeaderboardManager.gd |
| 10 | LocalizationManager | scripts/systems/LocalizationManager.gd |
| 11 | SkillTreeManager | scripts/systems/SkillTreeManager.gd |
| 12 | ReputationManager | scripts/systems/ReputationManager.gd |
| 13 | CutsceneManager | scripts/gameplay/CutsceneManager.gd |
| 14 | NetworkManager | scripts/network/NetworkManager.gd |
| 15 | MusicManager | scripts/audio/MusicManager.gd |
| 16 | ToastNotification | scripts/ui/ToastNotification.gd |
| 17 | StatsManager | scripts/systems/StatsManager.gd |
| 18 | HapticFeedback | scripts/input/HapticFeedback.gd |
| 19 | WorldLayerManager | scripts/world/WorldLayerManager.gd |
| 20 | FactionManager | scripts/factions/FactionManager.gd |
| 21 | PerformanceManager | scripts/systems/PerformanceManager.gd |
| 22 | DebugConsole | scripts/debug/DebugConsole.gd |
| 23 | CyberwareManager | scripts/systems/CyberwareManager.gd |
| 24 | HackingSystem | scripts/systems/HackingSystem.gd |
| 25 | CyberneticInstabilitySystem | scripts/systems/CyberneticInstabilitySystem.gd |
| 26 | CyberpunkReputationSystem | scripts/systems/CyberpunkReputationSystem.gd |
| 27 | OppressiveAdvertisingSystem | scripts/systems/OppressiveAdvertisingSystem.gd |
| 28 | TimeDilationManager | scripts/systems/TimeDilationManager.gd |
| 29 | VFXPoolManager | scripts/effects/VFXPoolManager.gd |
| 30 | UnifiedInputManager | scripts/input/UnifiedInputManager.gd |
| 31 | AmbientAudioManager | scripts/audio/AmbientAudioManager.gd |
| 32 | SafeAreaManager | scripts/ui/SafeAreaManager.gd |
| 33 | LazyLoader | scripts/systems/LazyLoader.gd |
| 34 | PlatformUIController | scripts/ui/PlatformUIController.gd |
| 35 | KeyboardAccessibilityManager | scripts/accessibility/KeyboardAccessibilityManager.gd |
| 36 | SFXManager | scripts/audio/SFXManager.gd |
| 37 | EnemyAudioController | scripts/audio/EnemyAudioController.gd |

> En plus de ces 37 autoloads "gameplay", l'éditeur peut ajouter dynamiquement des autoloads liés au plugin
> **Godot MCP Pro** (ex: `MCPScreenshot`, `MCPInputService`, `MCPGameInspector`) utilisés uniquement pendant
> le développement/automation — ils ne font pas partie du build final.

---

# 🚧 Prochaines Étapes / TODO

## Priorité Haute

- [x] **CityBlock.tscn intégrée** comme niveau alternatif jouable : collisions Building3/4 ajoutées,
  WorldEnvironment + DirectionalLight3D + PlayerSpawn + Player + 2 SecurityRobot + CanvasLayer +
  AmbientAudio ajoutés, accessible via le bouton "🏙 NIVEAU ALTERNATIF" du MainMenu.
- [x] **EnemyAudioFeedback.gd câblé** sur `SecurityRobot.tscn` : tableaux `footstep_sounds`
  (impactMetal_000/001), `servo_sounds` (forceField_000/001), `patrol_hum_sound` (computerNoise_000),
  `alert_sound` (laserRetro_000), `chase_sound` (spaceEngineSmall_000), `attack_sound`
  (laserSmall_000), `death_sound` (explosionCrunch_000) assignés depuis `audio/sfx/`.
  `SecurityRobot.gd._on_died()` appelle désormais `play_death_sound()`. Complémentaire à
  `EnemyAudioController.gd` (générique/auto-détection) — celui-ci reste actif pour les autres
  ennemis sans `EnemyAudioFeedback`.
- [x] **Tests de combat élargis** : nouveau `tests/unit/test_combat_advanced.gd` (enregistré dans
  `TestRunner.gd::_unit_tests`) couvrant `HitboxManager.gd` (création/suivi de hitbox,
  enregistrement/suppression de hurtbox, cycle de vie des i-frames) et `TacticalCombatSystem.gd`
  (bascule de mode tactique avec vérification d'`Engine.time_scale`, drain de la ressource
  tactique, bonus de précision en mode ralenti). Validation runtime via `execute_game_script` non
  effectuée — plugin Godot MCP Pro non connecté pendant cette session ; lancer
  `tests/TestRunner.tscn` (bouton "Tests Unitaires") pour exécuter la suite.
- [x] **Vérifier `get_editor_errors`** régulièrement pendant le dev — connu pour renvoyer un cache
  obsolète ; toujours confirmer via `execute_game_script` / `get_output_log`. (Note de process pour
  les sessions de dev, pas de changement de code requis — à garder en tête pour les items runtime
  ci-dessous comme "Tests de combat élargis".)

## Priorité Moyenne

- [x] **Étoffer le skyline** : `Main.tscn/TestLevel/Skyline` passe de 6 à 12 bâtiments
  (`Building7-12`, nouveaux `.glb` building-f/g et low-detail-building-b/wide-b) avec variation
  d'échelle (0.8x à 1.6x) et 8 `OmniLight3D` "WindowLights" néon (cyan/magenta/vert/jaune) en
  hauteur. Côté procédural, `LivingCityGenerator.gd::_generate_residential()` applique désormais
  une échelle aléatoire (`residential_scale_range`, défaut 0.8-1.4), une lumière de fenêtre néon
  par bâtiment avec probabilité `window_light_chance` (0.5), et `residential_density` passe de
  0.4 à 0.55 pour un remplissage plus dense.
- [x] **SFX manquants par catégorie** : `SFXManager.gd` ajoute 5 nouvelles catégories `play_ui` —
  `pickup` (pluck_001/002), `toggle` (toggle_001-004), `notification` (bong_001, scroll_001/002),
  `door_open`/`door_close` (doorOpen/doorClose_000-002). Câblées dans : `Pickup.gd` (`collect()` →
  `pickup`, corrige aussi une référence obsolète à `/root/AudioManager`), `Door.gd` (`open()`/`close()`
  → `door_open`/`door_close` quand pas d'`AudioPlayer` dédié), `ToastNotification.gd`
  (`show_notification()` → `notification`), `PauseMenu.gd` (hover/click sur boutons + `toggle` sur
  pause/resume), `OptionsMenu.gd` (`toggle` sur les switches accessibilité, `back` sur fermeture),
  `CraftingSystem.gd` (`confirm` sur craft réussi).
- [x] **Musique de combat dynamique** : `CombatManager.gd` connecte désormais `target_acquired`
  → `MusicManager.enter_combat()` et `target_lost` (si plus aucun ennemi en `auto_target_range`)
  → `MusicManager.enter_exploration()`.
- [x] **Documenter les scénarios de quêtes** : nouveau [QUESTS_GUIDE.md](QUESTS_GUIDE.md) détaille
  les 6 scénarios (`scripts/quests/scenarios/`) — déclencheurs, déroulement, choix du joueur et
  conséquences (réputation, crédits, monde, quêtes verrouillées/débloquées).

## Priorité Basse / Nettoyage

- [ ] **Fichiers gmap_* / addons obsolètes** : `addons/gmap_hotkeys`, `addons/gmap_viewer`,
  `addons/godot-accessibility` apparaissent supprimés dans l'arbre de travail mais pas encore
  commités — décider de finaliser cette suppression ou de les restaurer.
- [ ] **`config/version`** dans `project.godot` toujours à `0.0.0` — à incrémenter quand une
  première build stable est prête.

---

# ✨ Fonctionnalités à Ajouter

Idées issues de l'analyse du code existant (systèmes présents mais partiellement exploités) :

- **Boss fights additionnels** : `BossEnemy.gd` supporte un système de phases générique — créer
  2-3 boss thématiques (un par district) en variant `enemy_sounds`, attaques et seuils de phase.
- [x] **Crafting avancé** : `CraftingSystem.gd::learn_recipe()` appelle déjà
  `ToastNotification.show_achievement("📖 Recette apprise", item_name)` quand une nouvelle recette
  est débloquée (déjà câblé, pas de changement nécessaire). Le toast de craft réussi a aussi
  désormais un son `confirm` (cf. SFX manquants ci-dessus).
- [x] **Réputation ↔ Monde** : `DistrictEcosystem.gd` est désormais déclaré en autoload
  (`project.godot`, corrige les appels globaux cassés dans `ScenarioFeteAuxBallons.gd` et
  `MeaningfulActivityGenerator.gd` qui le référençaient sans qu'il soit chargé).
  `CyberpunkReputationSystem.gd::add_reputation()` appelle désormais
  `_propagate_to_districts()` : via la table `FACTION_TO_GROUP` (mappant les factions de
  `DistrictEcosystem.controlling_faction` aux 4 groupes de réputation), tout changement de
  réputation avec un groupe répercute `DistrictEcosystem.modify_local_reputation()` et
  `modify_tension()` sur les districts contrôlés par ce groupe.
  `LivingCityGenerator.gd` expose un `@export var district_id` ; `_connect_world_state_signals()`
  s'abonne à `CyberpunkReputationSystem.reputation_changed` et
  `DistrictEcosystem.district_tension_changed`. `_refresh_world_state()` calcule un niveau
  d'hostilité (`max(tension, -réputation_locale/100)`) et : teinte les lumières de fenêtres
  (`_add_window_light`) vers le rouge alerte avec intensité accrue (`_apply_hostility_visuals`,
  effet "patrouilles renforcées" visible), émet `patrol_density_changed(multiplier)` (à
  consommer par `SpawnManager`) et `price_modifier_changed(modifier)` (relayant
  `DistrictEcosystem.get_price_modifier()`, à consommer par l'UI de commerce) — ces deux
  signaux sont des points d'accroche pour les systèmes de gameplay correspondants.
- [x] **Cycle jour/nuit ↔ Spawns** : `DayNightCycle.gd` est désormais déclaré en autoload
  (`project.godot`) et rejoint le groupe `day_night_cycle` (`_ready()`) — corrige les appels
  globaux cassés `/root/DayNightCycle` déjà présents dans `StealthSystem.gd`,
  `RandomEventManager.gd`, `SecurityRobot.gd` et `DebugConsole.gd::_cmd_set_time()`, qui
  n'avaient jusqu'ici aucune instance à trouver.
  `SpawnManager.gd::_get_spawn_multiplier()` lit `DayNightCycle.get_enemy_spawn_multiplier()`
  (×1.5 la nuit, ×0.8 le jour) et l'applique au nombre d'ennemis de `_spawn_wave()` et
  `_spawn_procedural_wave()`, ainsi qu'à l'intervalle de `start_continuous_spawn()` (vagues plus
  rapprochées la nuit).
  `LivingCityGenerator.gd::_connect_world_state_signals()` s'abonne à
  `DayNightCycle.period_changed` ; `_on_period_changed()` règle `_current_night_factor`
  (0.15 le jour, 0.4 à l'aube, 0.7 au crépuscule, 1.0 la nuit) et `_apply_window_lights()`
  multiplie l'intensité des lumières de fenêtres par ce facteur — les néons résidentiels
  s'éteignent progressivement le jour et s'allument la nuit, en plus de la teinte d'hostilité
  (cf. Réputation ↔ Monde ci-dessus).
- [x] **Mode Bullet-Time accessible** : nouvelle action input `tactical_mode` (touche `B` /
  bouton L3 manette, déclarée dans `project.godot` et mappée dans
  `UnifiedInputManager.gd::_game_action_to_input()` via `GameAction.TACTICAL_MODE`).
  `Player.gd::_unhandled_input()` détecte l'appui et appelle `_toggle_bullet_time()`, qui
  bascule `TimeDilationManager.enter_tactical_mode(self)` / `exit_tactical_mode()`, joue un son
  `toggle` (`SFXManager.play_ui`) et annonce "Mode bullet-time activé/désactivé" via
  `TTSManager.speak()`. Côté mobile, `Player.gd::request_tactical_mode()` est appelé par un
  double-tap dans la zone basse de `TouchZoneController.gd::_handle_bottom_zone_gesture()`.
- **Co-op multijoueur** : `NetworkManager.gd` + `MultiplayerSync.gd` + `MultiplayerLobby.tscn`
  sont en place — un mode "survie en vagues" co-op via `SpawnManager.gd` serait un bon premier
  test multijoueur.
- **Achievements liés aux scénarios** : connecter `AchievementManager.gd` aux choix moraux des
  `ScenarioXxx.gd` (ex: "Pacifiste", "Briseur de chaînes IA", etc.).
- **Garage / personnalisation véhicule** : `VehicleController.gd` (CyberMotorcycle) — ajouter
  un système d'amélioration via `ShopSystem.gd` / `CraftingSystem.gd`.

---

# Récapitulatif

```
scripts/                     126 fichiers
├── accessibility/           9 fichiers
├── audio/                   9 fichiers
├── camera/                  2 fichiers
├── combat/                  4 fichiers
├── components/              1 fichier
├── debug/                   1 fichier
├── effects/                 4 fichiers
├── enemies/                 4 fichiers
├── factions/                4 fichiers
├── gameplay/                10 fichiers
├── input/                   2 fichiers
├── missions/                1 fichier
├── navigation/              2 fichiers
├── network/                 2 fichiers
├── player/                  5 fichiers
├── quests/scenarios/        6 fichiers
├── systems/                 20 fichiers
├── ui/                      17 fichiers
└── world/                   23 fichiers
    ├── (core)               13 fichiers
    ├── layers/              4 fichiers
    ├── locations/           5 fichiers
    └── effects/             1 fichier

scenes/                      17 fichiers
shaders/                      7 fichiers
autoloads/                    37 entrées
```

---

*Généré automatiquement - Neon Protocol v0.0.1 - 11 Juin 2026*
