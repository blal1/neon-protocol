// ==============================================================================
// neon_volumetric.gdshader - Néons Volumétriques Cyberpunk
// ==============================================================================
// Lumières néon avec glow, flicker et réflexions sur surface mouillée.
// ==============================================================================

shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// == NEON PROPERTIES ==
uniform vec4 neon_color : source_color = vec4(1.0, 0.2, 0.6, 1.0);
uniform float intensity : hint_range(0.5, 10.0) = 3.0;
uniform float glow_size : hint_range(0.0, 2.0) = 0.5;
uniform float glow_falloff : hint_range(0.5, 5.0) = 2.0;

// == FLICKER ==
uniform bool flicker_enabled = true;
uniform float flicker_speed : hint_range(1.0, 30.0) = 12.0;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.1;
uniform float damaged_flicker : hint_range(0.0, 1.0) = 0.0;

// == GLOW ATMOSPHERE ==
uniform float atmosphere_density : hint_range(0.0, 1.0) = 0.3;
uniform sampler2D noise_texture : hint_default_white;

// == TUBE PROPERTIES ==
uniform float tube_radius : hint_range(0.01, 0.5) = 0.05;
uniform bool is_tube = true;

// == RANDOM ==
float random(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

// == VERTEX ==
void vertex() {
    // Slight pulse expansion
    if (is_tube) {
        float pulse = sin(TIME * 3.0) * 0.02 + 1.0;
        VERTEX *= pulse;
    }
}

// == FRAGMENT ==
void fragment() {
    float time = TIME;
    
    // Base color
    vec3 color = neon_color.rgb;
    float alpha = 1.0;
    
    // == CORE GLOW ==
    // Fresnel for tube
    float fresnel = 1.0 - abs(dot(NORMAL, VIEW));
    fresnel = pow(fresnel, glow_falloff);
    
    // Core brightness
    float core = 1.0 - fresnel;
    core = pow(core, 0.5);
    
    // == FLICKER ==
    float flicker = 1.0;
    if (flicker_enabled) {
        // Regular flicker
        flicker = 1.0 - flicker_intensity + flicker_intensity * 
                  (sin(time * flicker_speed) * 0.5 + 0.5);
        
        // Random occasional flicker
        float random_flicker = step(0.97, random(floor(time * 20.0)));
        flicker *= (1.0 - random_flicker * 0.3);
    }
    
    // == DAMAGED NEON ==
    if (damaged_flicker > 0.0) {
        // More aggressive flickering for damaged signs
        float damage_flick = step(0.7 - damaged_flicker * 0.5, random(floor(time * 30.0)));
        flicker *= (1.0 - damage_flick * damaged_flicker);
        
        // Occasional full shutdown
        float shutdown = step(0.95, random(floor(time * 2.0)));
        flicker *= (1.0 - shutdown * damaged_flicker * 0.8);
    }
    
    // == ATMOSPHERIC GLOW ==
    float atmosphere = fresnel * atmosphere_density;
    vec3 atmo_color = color * atmosphere * intensity * 0.3;
    
    // == COMBINE ==
    float final_intensity = intensity * flicker;
    
    // Core (brightest)
    vec3 core_color = color * core * final_intensity;
    
    // Glow (falloff)
    vec3 glow_color = color * fresnel * glow_size * final_intensity * 0.5;
    
    vec3 final_color = core_color + glow_color + atmo_color;
    
    // Alpha based on glow
    alpha = (core + fresnel * glow_size) * flicker;
    alpha = clamp(alpha, 0.0, 1.0);
    
    ALBEDO = final_color;
    ALPHA = alpha;
    EMISSION = final_color;
}
