shader_type spatial;
render_mode cull_disabled;
uniform vec3 grid_color : source_color = vec3(0.05, 0.05, 0.05);
uniform vec3 line_color : source_color = vec3(0.4, 0.4, 0.4);
uniform float line_thickness : hint_range(0.0, 0.1) = 0.02;
uniform float grid_scale : hint_range(0.1, 10.0) = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    // Передаем нормаль в мировых координатах, чтобы знать, куда смотрит стена
    world_normal = abs(MODEL_NORMAL_MATRIX * NORMAL);
}

float get_grid(vec2 pos) {
    vec2 grid = abs(fract(pos * grid_scale - 0.5) - 0.5) / fwidth(pos * grid_scale);
    return 1.0 - smoothstep(0.0, line_thickness * 50.0, min(grid.x, grid.y));
}

void fragment() {
    // Считаем сетку для каждой из трех плоскостей
    float x_plane = get_grid(world_pos.zy);
    float y_plane = get_grid(world_pos.xz);
    float z_plane = get_grid(world_pos.xy);
    
    // Смешиваем их на основе того, куда смотрит поверхность
    // world_normal уже нормализован и взят по модулю в vertex
    float mask = x_plane * world_normal.x + y_plane * world_normal.y + z_plane * world_normal.z;
    
    ALBEDO = mix(grid_color, line_color, mask);
}