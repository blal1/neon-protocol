# 🏗️ Guide des Scènes - Neon Protocol

## Vue d'Ensemble

Ce guide explique comment configurer et utiliser les différentes scènes du projet.

---

## 📂 Structure des Scènes

```
scenes/
├── main/
│   ├── Main.tscn           # Niveau de jeu (TestLevel + skyline de bâtiments)
│   └── MainMenu.tscn       # Menu principal (point d'entrée, run/main_scene)
├── player/
│   └── Player.tscn         # Scène du joueur
├── enemies/
│   └── SecurityRobot.tscn  # Robot de sécurité
├── gameplay/
│   ├── CyberMotorcycle.tscn
│   └── DroneCompanion.tscn
├── ui/
│   ├── GameHUD.tscn        # Interface en jeu (anciennement nommé "HUD.tscn" dans cette doc)
│   ├── PauseMenu.tscn      # Menu pause
│   ├── OptionsMenu.tscn
│   ├── GameOverMenu.tscn
│   ├── CraftingUI.tscn
│   ├── HackingMinigame.tscn
│   ├── MultiplayerLobby.tscn
│   ├── TutorialPanel.tscn
│   └── VirtualJoystick.tscn # Joystick mobile
└── world/
    ├── CityBlock.tscn      # Niveau alternatif jouable
    └── TutorialLevel.tscn  # Niveau tutoriel
```

> **run/main_scene** est `scenes/main/MainMenu.tscn`. Le bouton "Jouer" charge `scenes/main/Main.tscn`.
> Le bouton "🏙 NIVEAU ALTERNATIF" charge `scenes/world/CityBlock.tscn`.

---

## 🎭 Scène Player.tscn

### Hiérarchie

```
Player (CharacterBody3D)
├── CollisionShape3D
├── MeshPivot (Node3D)
│   └── MeshInstance3D      # Modèle joueur
├── Camera3D                # Caméra 3ème personne
├── HealthComponent
├── CombatManager
├── DashAbility
├── WeaponVisuals
└── PlayerAnimationController
```

### Configuration

1. **Ouvrir** `scenes/player/Player.tscn`
2. **Sélectionner** le nœud root `Player`
3. **Attacher le script** `scripts/player/Player.gd`

### Composants Requis

| Nœud | Script | Obligatoire |
|------|--------|-------------|
| Player | Player.gd | ✅ |
| HealthComponent | HealthComponent.gd | ✅ |
| CombatManager | CombatManager.gd | ✅ |
| DashAbility | DashAbility.gd | ✅ |

### Groupes

Le Player doit être dans le groupe `player`:
```
Player → Nœud → Groupes → Ajouter: "player"
```

### Collision Layers

```
Layer: 2 (Player)
Mask: 1, 3, 4 (World, Enemy, Interactable)
```

---

## 👾 Scène SecurityRobot.tscn

### Hiérarchie

```
SecurityRobot (CharacterBody3D)
├── CollisionShape3D
├── MeshPivot (Node3D)
│   └── MeshInstance3D
├── NavigationAgent3D
├── DetectionArea (Area3D)
├── HealthComponent
└── AudioStreamPlayer3D
```

### Configuration Waypoints

1. Créer des Node3D dans le niveau
2. Les ajouter au tableau `waypoints` dans l'inspecteur
3. L'ennemi patrouillera entre eux

### Variables Importantes

| Variable | Description | Défaut |
|----------|-------------|--------|
| detection_range | Portée de détection | 10.0 |
| attack_range | Portée d'attaque | 2.0 |
| patrol_speed | Vitesse patrouille | 3.0 |
| chase_speed | Vitesse poursuite | 5.0 |

### Groupes Requis

- `enemy` (obligatoire)
- `robot` (pour sons spécifiques)

---

## 🏙️ Scène Main.tscn (niveau de jeu actuel)

### Hiérarchie

```
Main (Node3D)
├── WorldEnvironment           # Environnement cyberpunk (fog, glow, ambient)
├── DirectionalLight3D
├── TestLevel (Node3D)
│   ├── Floor / Walls          # Sol + 4 murs (StaticBody3D + meshes procéduraux)
│   ├── NeonPillar1-4           # Piliers néon colorés (cyan/magenta/vert/jaune)
│   ├── ObjectiveMarker         # Marqueur d'objectif (groupe "objective")
│   └── Skyline (Node3D)        # 6 bâtiments .glb en périphérie
│       ├── Building1-6         # instances de assets/models/buildings/*.glb
├── PlayerSpawn (Marker3D)
├── Enemies (Node3D)
├── CanvasLayer
├── AmbientAudio (AmbientAudioManager.gd)
└── Player (instance Player.tscn)
```

### Skyline (ajouté récemment)

6 bâtiments `.glb` (skyscraper-a à e + low-detail-building-wide-a) sont placés en périmètre du
`TestLevel` pour donner une impression de skyline :

| Nœud | Modèle | Position approx. |
|------|--------|-------------------|
| Building1 | building-skyscraper-a.glb | (-45, 0, -45) |
| Building2 | building-skyscraper-b.glb | (45, 0, -50) |
| Building3 | building-skyscraper-c.glb | (-50, 0, 45) |
| Building4 | building-skyscraper-d.glb | (50, 0, 50) |
| Building5 | building-skyscraper-e.glb | (0, 0, -60) |
| Building6 | low-detail-building-wide-a.glb | (-60, 0, 0) |

Pour ajouter d'autres bâtiments, instancier d'autres `.glb` de `assets/models/buildings/` sous
`TestLevel/Skyline` avec un `Transform3D` positionné en dehors de la zone de jeu (rayon > 25).

---

## 🌆 Scène CityBlock.tscn (niveau alternatif)

Petit niveau "block urbain" jouable, accessible via le bouton "🏙 NIVEAU ALTERNATIF" du
`MainMenu` (`MainMenu.gd._on_district_pressed()` → `change_scene_to_file("res://scenes/world/CityBlock.tscn")`).

### Hiérarchie

```
CityBlock (Node3D, groupe "world_chunk")
├── WorldEnvironment           # Environnement cyberpunk (fog, glow, ambient)
├── DirectionalLight3D
├── Ground (StaticBody3D, groupes "ground","concrete")
│   ├── FloorMesh
│   └── FloorCollision
├── Buildings (Node3D)
│   └── Building1-4 (StaticBody3D + Mesh + CollisionShape3D)
├── Neons (Node3D)            # Barres/enseignes néon (ShaderMaterial neon_glow)
├── StreetLamps (Node3D)      # Lamp1-2 (Pole + Light + OmniLight3D)
├── Props (Node3D)            # Crate1-2 (StaticBody3D)
├── PlayerSpawn (Marker3D)
├── Enemies (Node3D)
│   └── SecurityRobot1-2 (instances de SecurityRobot.tscn)
├── CanvasLayer (layer=10)
├── AmbientAudio (AmbientAudioManager.gd)
└── Player (instance Player.tscn)
```

### Notes

- Toutes les `StaticBody3D` (sol, bâtiments, caisses) ont désormais un `CollisionShape3D`
  (Building3/Building4 en manquaient auparavant).
- Pas de `NavigationRegion3D` : comme `Main.tscn`, les `SecurityRobot` se déplacent sans navmesh
  baked (suffisant pour ce niveau de petite taille).
- `BoxMesh_sidewalk` reste défini en sub-resource mais non utilisé — réservoir pour ajouter des
  trottoirs plus tard.

---

## 📱 Scène VirtualJoystick.tscn

### Configuration

```
VirtualJoystick (Control)
├── Background (TextureRect)
└── Knob (TextureRect)
```

### Script

Attacher `scripts/ui/SimpleJoystick.gd`

### Intégration dans le HUD

1. Ouvrir `scenes/ui/GameHUD.tscn`
2. Ajouter `VirtualJoystick.tscn` en enfant
3. Positionner en bas à gauche

### Récupérer l'Input

```gdscript
var joystick = get_node_or_null("/root/CurrentScene/HUD/VirtualJoystick")
if joystick:
    var input = joystick.get_input()  # Vector2
    velocity.x = input.x * speed
    velocity.z = input.y * speed
```

---

## 🖥️ Scène GameHUD.tscn

> Nom de fichier réel : `scenes/ui/GameHUD.tscn`, script `scripts/ui/GameHUD.gd` (`class_name GameHUD`).

### Hiérarchie Recommandée

```
GameHUD (CanvasLayer)
├── TopBar (HBoxContainer)
│   ├── HealthBar (ProgressBar)
│   └── CreditsLabel (Label)
├── LeftSide (VBoxContainer)
│   └── VirtualJoystick
├── RightSide (VBoxContainer)
│   ├── AttackButton (TouchScreenButton)
│   └── DashButton (TouchScreenButton)
├── Minimap (Control)
└── ObjectivePanel (PanelContainer)
```

### Connexion au Player

```gdscript
func _ready():
    var player = get_tree().get_first_node_in_group("player")
    if player and player.has_node("HealthComponent"):
        player.get_node("HealthComponent").health_changed.connect(_on_health_changed)

func _on_health_changed(current: float, max: float):
    $TopBar/HealthBar.value = (current / max) * 100
```

---

## 🎓 Scène TutorialLevel.tscn

### Zones de Tutoriel

```
TutorialLevel (Node3D)
├── [Environment...]
├── TutorialZones (Node3D)
│   ├── Zone1_Movement (Area3D)
│   ├── Zone2_Combat (Area3D)
│   ├── Zone3_Dash (Area3D)
│   └── Zone4_Interact (Area3D)
└── [EnemySpawns, Interactables...]
```

### Configuration des Zones

1. Créer une `Area3D` par zone
2. Ajouter un `CollisionShape3D` définissant la zone
3. Connecter le signal `body_entered`

### Script TutorialLevel.gd

Attacher `scripts/world/TutorialLevel.gd` au nœud root.

---

## 🔧 Création d'une Nouvelle Scène

### Niveau de Jeu

1. **Créer** `Scene → New Scene → Node3D`
2. **Renommer** en nom du niveau
3. **Ajouter**:
   - `WorldEnvironment`
   - `DirectionalLight3D`
   - `NavigationRegion3D`
4. **Configurer** l'environnement (ciel, fog, ambient)
5. **Placer** la géométrie dans NavigationRegion3D
6. **Bake** le navigation mesh
7. **Ajouter** spawn points
8. **Sauvegarder** dans `scenes/world/`

### Ennemi

1. **Créer** `Scene → New Scene → CharacterBody3D`
2. **Ajouter** `CollisionShape3D`, `NavigationAgent3D`
3. **Ajouter** `MeshInstance3D` pour le visuel
4. **Ajouter** `HealthComponent` (enfant)
5. **Attacher** le script approprié
6. **Ajouter** aux groupes (`enemy`, type spécifique)
7. **Sauvegarder** dans `scenes/enemies/`

### UI

1. **Créer** `Scene → New Scene → Control` (ou CanvasLayer)
2. **Designer** l'interface
3. **Attacher** le script UI
4. **Sauvegarder** dans `scenes/ui/`

---

## ⚙️ Paramètres d'Environnement

### WorldEnvironment Cyberpunk

```
WorldEnvironment:
  Environment:
    Background:
      Mode: Sky
      Sky:
        Material: ProceduralSkyMaterial
          Sky Top Color: #0a0a15
          Sky Horizon Color: #ff00ff (magenta)
          Ground Bottom Color: #000022
    
    Ambient Light:
      Source: Color
      Color: #1a1a2e
      Energy: 0.3
    
    Fog:
      Enabled: true
      Light Color: #0d0d1a
      Density: 0.01
```

### Éclairage Neon

Pour les lumières neon:
```
OmniLight3D:
  Color: #00ffff (cyan) ou #ff00ff (magenta)
  Energy: 2.0
  Range: 10.0
  Attenuation: 1.5
```

---

## 📝 Checklist Nouvelle Scène

- [ ] Type de nœud root approprié
- [ ] Collision shapes configurés
- [ ] Navigation mesh (si niveau)
- [ ] Scripts attachés
- [ ] Groupes assignés
- [ ] Collision layers/masks configurés
- [ ] Spawn points placés
- [ ] Test en standalone (F6)

---

*Guide des Scènes - Neon Protocol v0.2.0 - 11 Juin 2026*
