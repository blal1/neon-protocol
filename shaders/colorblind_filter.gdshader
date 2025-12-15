// ==============================================================================
// colorblind_filter.gdshader - Filtre de simulation/correction daltonisme
// Action-RPG Cyberpunk Low-Poly - Godot 4
// ==============================================================================
// Applique une transformation de couleur pour simuler ou corriger
// différents types de daltonisme
// ==============================================================================

shader_type canvas_item;

// Mode de daltonisme (0 = None, 1 = Deuteranopia, 2 = Protanopia, 3 = Tritanopia)
uniform int mode : hint_range(0, 3) = 0;

// Intensité du filtre (0.0 = désactivé, 1.0 = plein effet)
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// Matrices de transformation pour chaque type de daltonisme
// Ces matrices simulent la vision daltonienne puis appliquent une correction

// Deuteranopia (Rouge-Vert) - le plus commun (~6% des hommes)
const mat3 DEUTERANOPIA_MATRIX = mat3(
    vec3(0.625, 0.375, 0.0),
    vec3(0.7, 0.3, 0.0),
    vec3(0.0, 0.3, 0.7)
);

// Protanopia (Rouge)
const mat3 PROTANOPIA_MATRIX = mat3(
    vec3(0.567, 0.433, 0.0),
    vec3(0.558, 0.442, 0.0),
    vec3(0.0, 0.242, 0.758)
);

// Tritanopia (Bleu-Jaune)
const mat3 TRITANOPIA_MATRIX = mat3(
    vec3(0.95, 0.05, 0.0),
    vec3(0.0, 0.433, 0.567),
    vec3(0.0, 0.475, 0.525)
);

// Matrice identité (pas de changement)
const mat3 IDENTITY_MATRIX = mat3(
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

void fragment() {
    // Récupérer la couleur originale
    vec4 original_color = texture(TEXTURE, UV);
    
    // Si mode désactivé ou intensité nulle, pas de changement
    if (mode == 0 || intensity < 0.001) {
        COLOR = original_color;
        return;
    }
    
    // Sélectionner la matrice appropriée
    mat3 color_matrix;
    
    if (mode == 1) {
        color_matrix = DEUTERANOPIA_MATRIX;
    } else if (mode == 2) {
        color_matrix = PROTANOPIA_MATRIX;
    } else if (mode == 3) {
        color_matrix = TRITANOPIA_MATRIX;
    } else {
        color_matrix = IDENTITY_MATRIX;
    }
    
    // Appliquer la transformation
    vec3 transformed = color_matrix * original_color.rgb;
    
    // Mélanger avec l'original selon l'intensité
    vec3 final_color = mix(original_color.rgb, transformed, intensity);
    
    // Conserver l'alpha original
    COLOR = vec4(final_color, original_color.a);
}
