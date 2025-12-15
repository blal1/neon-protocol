// ==============================================================================
// cyberpsychosis_screen.gdshader - Post-Process Cyberpsychose
// ==============================================================================
// Effets plein écran pour instabilité cybernétique.
// À utiliser avec ColorRect en mode CanvasItem.
// ==============================================================================

shader_type canvas_item;

// == SCREEN TEXTURE ==
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// == INTENSITY ==
uniform float instability : hint_range(0.0, 1.0) = 0.0;
uniform float hallucination_intensity : hint_range(0.0, 1.0) = 0.0;

// == CHROMATIC ABERRATION ==
uniform float chromatic_amount : hint_range(0.0, 0.1) = 0.01;
uniform float chromatic_speed : hint_range(0.1, 5.0) = 1.0;

// == DISTORTION ==
uniform float distortion_amount : hint_range(0.0, 0.1) = 0.02;
uniform float distortion_frequency : hint_range(1.0, 20.0) = 5.0;
uniform float distortion_speed : hint_range(0.1, 5.0) = 2.0;

// == GLITCH ==
uniform float glitch_block_size : hint_range(0.01, 0.2) = 0.05;
uniform float glitch_probability : hint_range(0.0, 0.3) = 0.1;

// == VIGNETTE ==
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec4 vignette_color : source_color = vec4(0.8, 0.0, 0.0, 1.0);

// == NOISE ==
uniform float noise_intensity : hint_range(0.0, 0.3) = 0.05;
uniform float noise_speed : hint_range(0.1, 10.0) = 5.0;

// == SCAN LINES (écran cassé) ==
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_count : hint_range(50.0, 500.0) = 200.0;

// == HALLUCINATIONS ==
uniform vec4 hallucination_color_1 : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform vec4 hallucination_color_2 : source_color = vec4(0.0, 1.0, 0.8, 1.0);
uniform float hallucination_speed : hint_range(0.1, 3.0) = 1.0;

// == RANDOM FUNCTIONS ==
float random(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

float random2d(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    
    float a = random2d(i);
    float b = random2d(i + vec2(1.0, 0.0));
    float c = random2d(i + vec2(0.0, 1.0));
    float d = random2d(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    float time = TIME;
    
    // Calcul de l'effet basé sur l'instabilité
    float effect_strength = instability;
    
    if (effect_strength <= 0.0 && hallucination_intensity <= 0.0) {
        COLOR = texture(SCREEN_TEXTURE, uv);
        return;
    }
    
    // == DISTORTION ==
    if (effect_strength > 0.1) {
        float distort = sin(uv.y * distortion_frequency + time * distortion_speed);
        distort *= sin(uv.x * distortion_frequency * 0.7 + time * distortion_speed * 0.8);
        uv.x += distort * distortion_amount * effect_strength;
        
        // Vertical wave
        uv.y += sin(time * distortion_speed * 2.0 + uv.x * 10.0) * distortion_amount * effect_strength * 0.5;
    }
    
    // == GLITCH BLOCKS ==
    if (effect_strength > 0.2) {
        float block_y = floor(uv.y / glitch_block_size);
        float glitch_rand = random(block_y + floor(time * 10.0));
        
        if (glitch_rand < glitch_probability * effect_strength) {
            float offset = (random(block_y + time) - 0.5) * 0.1 * effect_strength;
            uv.x += offset;
            
            // Parfois, copier un bloc d'une autre ligne
            if (glitch_rand < glitch_probability * effect_strength * 0.3) {
                float source_y = random(time + uv.x);
                uv.y = source_y;
            }
        }
    }
    
    // == CHROMATIC ABERRATION ==
    float chroma = chromatic_amount * effect_strength;
    chroma *= (1.0 + 0.3 * sin(time * chromatic_speed));
    
    vec3 color;
    color.r = texture(SCREEN_TEXTURE, uv + vec2(chroma, 0.0)).r;
    color.g = texture(SCREEN_TEXTURE, uv).g;
    color.b = texture(SCREEN_TEXTURE, uv - vec2(chroma, 0.0)).b;
    
    // == SCAN LINES ==
    if (effect_strength > 0.15) {
        float scanline = sin(uv.y * scanline_count + time * 10.0);
        scanline = (scanline * 0.5 + 0.5) * scanline_intensity * effect_strength;
        color -= vec3(scanline);
    }
    
    // == NOISE ==
    if (effect_strength > 0.1) {
        float n = random2d(uv * 1000.0 + time * noise_speed);
        color += vec3(n - 0.5) * noise_intensity * effect_strength;
    }
    
    // == HALLUCINATIONS ==
    if (hallucination_intensity > 0.0) {
        float hall_pattern = sin(uv.x * 20.0 + time * hallucination_speed) * 
                             cos(uv.y * 15.0 - time * hallucination_speed * 0.7);
        hall_pattern = (hall_pattern * 0.5 + 0.5);
        
        vec3 hall_color = mix(hallucination_color_1.rgb, hallucination_color_2.rgb, hall_pattern);
        
        // Ajouter des formes fantômes
        float ghost = noise(uv * 5.0 + time * 0.5);
        ghost = smoothstep(0.4, 0.6, ghost);
        
        color = mix(color, hall_color, ghost * hallucination_intensity * 0.3);
        
        // Pulsation des bords
        float edge_pulse = sin(time * hallucination_speed * 3.0) * 0.5 + 0.5;
        float edge = max(0.0, 1.0 - length((uv - 0.5) * 2.0) / 1.5);
        color += hall_color * edge * edge_pulse * hallucination_intensity * 0.2;
    }
    
    // == VIGNETTE (anxiété) ==
    if (effect_strength > 0.0) {
        float vignette = length((uv - 0.5) * 2.0);
        vignette = smoothstep(0.5, 1.5, vignette);
        vignette *= vignette_intensity * effect_strength;
        
        // Pulsation
        vignette *= (1.0 + 0.2 * sin(time * 5.0));
        
        color = mix(color, vignette_color.rgb * 0.3, vignette);
    }
    
    // == OCCASIONAL BLACKOUT ==
    if (effect_strength > 0.7) {
        float blackout = step(0.99, random(floor(time * 5.0)));
        color *= (1.0 - blackout * 0.8);
    }
    
    // == FINAL ==
    COLOR = vec4(color, 1.0);
}
