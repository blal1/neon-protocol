# 🚀 Optimisation Android - Checklist Performance

## 10 Paramètres Critiques pour Android Bas de Gamme

> **Project → Project Settings** dans Godot 4

---

### 1. 📐 Résolution et Rendu

**Chemin**: `Display → Window`

| Paramètre | Valeur Recommandée | Raison |
|-----------|-------------------|--------|
| `Viewport Width` | 960 | Résolution réduite pour performance |
| `Viewport Height` | 540 | Ratio 16:9 maintenu |
| `Mode` | `viewport` | Upscaling hardware |
| `Stretch Aspect` | `keep` | Évite la distortion |

```ini
[display]
window/size/viewport_width=960
window/size/viewport_height=540
window/stretch/mode="viewport"
window/stretch/aspect="keep"
```

---

### 2. 🎨 Qualité des Textures

**Chemin**: `Rendering → Textures`

| Paramètre | Valeur | Impact |
|-----------|--------|--------|
| `Canvas Textures → Default Texture Filter` | `Nearest` | -50% mémoire GPU |
| `Vram Compression → Import ETC2 ASTC` | `true` | Compression Android native |

```ini
[rendering]
textures/canvas_textures/default_texture_filter=0
textures/vram_compression/import_etc2_astc=true
```

---

### 3. 🌑 Ombres (CRITIQUE)

**Chemin**: `Rendering → Lights and Shadows`

| Paramètre | Valeur | Gain |
|-----------|--------|------|
| `Directional Shadow → Size` | 1024 | -60% GPU (vs 4096) |
| `Positional Shadow → Atlas Size` | 1024 | Moins de mémoire |
| `Soft Shadow Filter Quality` | `Soft Very Low` | Performance max |

```ini
[rendering]
lights_and_shadows/directional_shadow/size=1024
lights_and_shadows/directional_shadow/soft_shadow_filter_quality=0
lights_and_shadows/positional_shadow/atlas_size=1024
```

**💡 Alternative**: Désactiver complètement les ombres dynamiques et utiliser des ombres "baked" ou projetées via texture.

---

### 4. 🌍 Anti-Aliasing

**Chemin**: `Rendering → Anti Aliasing`

| Paramètre | Valeur | Note |
|-----------|--------|------|
| `Quality → MSAA → 3D` | `Disabled` | MSAA très coûteux sur mobile |
| `Quality → Screen Space AA` | `Disabled` | Économie GPU |

```ini
[rendering]
anti_aliasing/quality/msaa_3d=0
anti_aliasing/quality/screen_space_aa=0
```

---

### 5. 🌫️ Effets Post-Process

**Chemin**: `Rendering → Environment`

| Paramètre | Valeur | Impact |
|-----------|--------|--------|
| `Glow → Enabled` | `false` | -15% GPU |
| `SS Reflections → Enabled` | `false` | -20% GPU |
| `SSAO → Enabled` | `false` | -25% GPU |
| `SDFGI → Enabled` | `false` | Incompatible mobile |

```ini
[rendering]
environment/glow/enabled=false
environment/ssao/enabled=false
environment/ss_reflections/enabled=false
environment/sdfgi/enabled=false
```

---

### 6. 🔧 Moteur de Rendu

**Chemin**: `Rendering → Renderer`

| Paramètre | Valeur | Note |
|-----------|--------|------|
| `Rendering Method` | `mobile` | **OBLIGATOIRE** |
| `Rendering Method → Mobile → Driver` | `vulkan` | OpenGL ES 3.0 en fallback |

```ini
[rendering]
renderer/rendering_method="mobile"
```

> ⚠️ **IMPORTANT**: Le renderer `mobile` est optimisé pour les GPUs mobiles (Mali, Adreno).

---

### 7. ⚡ Physique

**Chemin**: `Physics → 3D`

| Paramètre | Valeur | Raison |
|-----------|--------|--------|
| `Default Gravity` | 9.8 | Standard |
| `Physics Ticks Per Second` | 30 | -50% CPU (vs 60) |
| `Jolt Physics → Enabled` | `false` | Godot Physics plus léger |

```ini
[physics]
common/physics_ticks_per_second=30
3d/run_on_separate_thread=true
```

---

### 8. 🔊 Audio

**Chemin**: `Audio`

| Paramètre | Valeur | Gain |
|-----------|--------|------|
| `Driver → Mix Rate` | 22050 | -50% mémoire audio |
| `Channel Disable Threshold DB` | -60 | Auto-mute sons faibles |

```ini
[audio]
driver/mix_rate=22050
buses/channel_disable_threshold_db=-60.0
```

---

### 9. 📱 Export Android Spécifique

**Chemin**: `Export → Android`

| Option | Valeur |
|--------|--------|
| `Min SDK` | 21 (Android 5.0) |
| `Target SDK` | 33+ |
| `Architectures` | `arm64-v8a` uniquement (ou + `armeabi-v7a` pour vieux devices) |
| `XR Mode` | `Regular` |
| `Graphics API` | `Vulkan` + `OpenGL ES 3.0` fallback |

---

### 10. 🗂️ Optimisation des Assets

| Technique | Mise en œuvre |
|-----------|---------------|
| **Textures max 512x512** | Réduire via import settings |
| **Compression ETC2** | Activer dans Project Settings |
| **LOD sur modèles** | 3 niveaux de détail |
| **Mesh simplification** | < 5000 triangles par objet |
| **Audio compressé** | OGG Vorbis, mono pour SFX |

---

## ✅ Script d'Optimisation Automatique

Ajoutez ce script pour ajuster dynamiquement la qualité:

```gdscript
# PerformanceManager.gd
extends Node

func _ready() -> void:
    # Détecter si device bas de gamme
    var gpu_name := RenderingServer.get_video_adapter_name().to_lower()
    
    if _is_low_end_device(gpu_name):
        _apply_low_quality_settings()

func _is_low_end_device(gpu: String) -> bool:
    # GPUs bas de gamme connus
    var low_end := ["mali-400", "mali-t", "adreno 3", "adreno 4", "powervr"]
    for pattern in low_end:
        if pattern in gpu:
            return true
    return false

func _apply_low_quality_settings() -> void:
    # Réduire la résolution
    get_viewport().scaling_3d_scale = 0.5
    
    # Désactiver les ombres
    RenderingServer.directional_soft_shadow_filter_set_quality(
        RenderingServer.SHADOW_QUALITY_HARD
    )
    
    print("Mode basse qualité activé pour: ", RenderingServer.get_video_adapter_name())
```

---

## 📊 Benchmarks Cibles

| Métrique | Objectif Bas de Gamme |
|----------|----------------------|
| **FPS** | 30 stable |
| **RAM** | < 500 MB |
| **APK Size** | < 100 MB |
| **Battery Drain** | < 15%/heure |
| **Température** | < 40°C |

---

## 🔗 Ressources

- [Documentation Godot Mobile](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_for_mobile.html)
- [Vulkan Best Practices for Mobile](https://developer.arm.com/documentation/102190/latest)
