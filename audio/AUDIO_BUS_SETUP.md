# ==============================================================================
# audio_bus_layout.tres - Configuration des Bus Audio
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# À importer dans Project Settings > Audio > Default Bus Layout
# ==============================================================================
#
# STRUCTURE DES BUS :
#
# Master
# ├── Music       (Musique d'ambiance)
# ├── SFX         (Bruits d'impacts, pas, combats)
# ├── Environment (Pluie, ville, néons)
# ├── Interface   (Menus, TTS, UI)
# └── Navigation  (Radar sonore pour accessibilité)
#
# ==============================================================================
# INSTRUCTIONS MANUELLES (Godot ne peut pas créer ce fichier par code)
# ==============================================================================
#
# 1. En bas de l'éditeur Godot, cliquez sur l'onglet "Audio"
#
# 2. Ajoutez les bus suivants (clic droit > Add Bus) :
#
#    BUS NAME        | VOLUME  | EFFETS SUGGÉRÉS
#    ----------------|---------|------------------
#    Music           | -5 dB   | (aucun)
#    SFX             | 0 dB    | (aucun)
#    Environment     | -3 dB   | Reverb (léger)
#    Interface       | 0 dB    | (aucun)
#    Navigation      | +3 dB   | (aucun, doit être audible)
#
# 3. Configuration recommandée par bus :
#
#    MUSIC :
#    - Pour la musique de fond synthwave
#    - Volume plus bas pour ne pas couvrir les sons importants
#
#    SFX :
#    - Tous les sons de gameplay (attaques, impacts, pas)
#    - Volume standard
#
#    ENVIRONMENT :
#    - Pluie, néons qui grésillent, bourdonnement de ville
#    - Ajouter un effet Reverb léger :
#      * Room Size: 0.3
#      * Damping: 0.5
#      * Spread: 0.7
#
#    INTERFACE :
#    - Sons de menu, notifications
#    - TTS (Text-to-Speech) pour accessibilité
#    - Pas d'effets pour clarté maximale
#
#    NAVIGATION :
#    - CRITIQUE pour les joueurs aveugles
#    - Volume plus élevé (+3 dB)
#    - Sons du radar/sonar AudioCompass
#    - Pas d'effets pour direction claire
#
# 4. Sauvegardez : Cliquez sur le menu ≡ > Save As...
#    Sauvegardez sous : res://audio/default_bus_layout.tres
#
# 5. Dans Project Settings > Audio :
#    - Default Bus Layout : res://audio/default_bus_layout.tres
#
# ==============================================================================
# EFFETS OPTIONNELS AVANCÉS
# ==============================================================================
#
# Pour une ambiance encore plus immersive :
#
# BUS: Environment
# - Ajouter effet "LowPassFilter" (coupe les hautes fréquences)
#   * Cutoff Hz: 5000
#   * Resonance: 0.5
#   → Simule les sons étouffés de la ville
#
# BUS: Master
# - Ajouter effet "Limiter" (évite la distorsion)
#   * Ceiling dB: -0.5
#   * Threshold dB: -6
#   → Protège les oreilles des joueurs
#
# ==============================================================================
# UTILISATION DANS LES SCRIPTS
# ==============================================================================
#
# Pour assigner un AudioStreamPlayer à un bus :
#
#   audio_player.bus = "SFX"
#   audio_player.bus = "Navigation"
#
# Pour ajuster le volume d'un bus depuis les options :
#
#   AudioServer.set_bus_volume_db(
#       AudioServer.get_bus_index("Music"),
#       volume_slider.value
#   )
#
# Pour muter un bus :
#
#   AudioServer.set_bus_mute(
#       AudioServer.get_bus_index("Music"),
#       true
#   )
#
# ==============================================================================
