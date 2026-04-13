precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 color = texture2D(tex, v_texcoord);
    float strength = 0.000;
    vec3 warmed = vec3(
        min(1.0, color.r * (1.0 + 0.035 * strength)),
        min(1.0, color.g * (1.0 + 0.010 * strength)),
        max(0.0, color.b * (1.0 - 0.055 * strength))
    );
    vec3 balanced = mix(color.rgb, warmed, strength * 0.85);
    gl_FragColor = vec4(balanced, color.a);
}
