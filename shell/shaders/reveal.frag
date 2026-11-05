#version 440
// Su damlası açılışı: içerik, kaynak noktasından dalgalı bir kenarla açılır,
// kenar boyunca ince bir ışık halkası akar.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;   // 0..1
    float time;       // saniye
    vec2 origin;      // kaynak (0..1, öğe koordinatı)
    vec2 aspect;      // (genişlik/yükseklik, 1)
    vec4 rim;         // halka rengi
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 d = (qt_TexCoord0 - origin) * aspect;
    float dist = length(d);
    float ang = atan(d.y, d.x);
    float maxR = length(max(origin, 1.0 - origin) * aspect) + 0.05;
    float wobble = (0.018 * sin(ang * 7.0 + time * 5.0) + 0.010 * sin(ang * 13.0 - time * 7.0)) * (1.0 - progress);
    float edge = progress * maxR + wobble;
    float inside = smoothstep(edge + 0.004, edge - 0.012, dist);
    // Kenara yakın hafif kırılma (su mercek etkisi)
    float near = smoothstep(0.08, 0.0, abs(dist - edge)) * (1.0 - progress);
    vec2 uv = qt_TexCoord0 - normalize(d + 1e-5) / aspect * near * 0.012;
    vec4 c = texture(source, uv) * inside;
    float ring = smoothstep(0.03, 0.0, abs(dist - edge)) * (1.0 - smoothstep(0.85, 1.0, progress));
    c.rgb += rim.rgb * ring * 0.55 * rim.a;
    c.a = max(c.a, ring * 0.35 * rim.a);
    fragColor = c * qt_Opacity;
}
