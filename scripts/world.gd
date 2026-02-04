extends Node2D

@export var tile_size := 16
@export var chunk_size := 32
@export var view_distance := 2
@export var enemy_spawn_interval := 1.0
@export var max_enemies := 12
@export var enemy_spawn_radius := 260.0
@export var hard_mode_time := 300.0
@export var hard_enemy_health := 8
@export var hard_enemy_speed := 110.0
@export var hard_enemy_contact_damage := 2
@export var hard_enemy_color := Color(0.7, 0.2, 0.9)

@onready var tile_map: TileMap = $TileMap
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = _ensure_hud()
@onready var timer_label: Label = _ensure_timer_label()
@onready var health_label: Label = _ensure_health_label()

var noise := FastNoiseLite.new()
var generated_chunks: Dictionary = {}
var tileset_source_id := -1
var _enemy_spawn_timer := 0.0
var _enemy_script := preload("res://scripts/enemy.gd")
var _elapsed_time := 0.0
var _hard_mode_started := false

func _ready() -> void:
    noise.seed = randi()
    noise.frequency = 0.05
    _setup_tileset()
    _update_chunks()
    if player.has_signal("health_changed"):
        player.health_changed.connect(_on_player_health_changed)
        if player.has_method("get_health") and player.has_method("get_max_health"):
            _on_player_health_changed(player.get_health(), player.get_max_health())
    _update_timer_label()

func _process(delta: float) -> void:
    _update_chunks()
    _update_enemy_spawns(delta)
    _update_timer(delta)

func _setup_tileset() -> void:
    var tileset := TileSet.new()
    var source := TileSetAtlasSource.new()
    tileset_source_id = tileset.add_source(source)

    var image := Image.create(tile_size * 2, tile_size, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.2, 0.6, 0.2))
    image.fill_rect(Rect2i(tile_size, 0, tile_size, tile_size), Color(0.2, 0.4, 0.8))

    var texture := ImageTexture.create_from_image(image)
    source.texture = texture
    source.texture_region_size = Vector2i(tile_size, tile_size)
    source.create_tile(Vector2i(0, 0))
    source.create_tile(Vector2i(1, 0))

    tile_map.tile_set = tileset

func _update_chunks() -> void:
    var player_tile := Vector2i(
        floor(player.global_position.x / tile_size),
        floor(player.global_position.y / tile_size)
    )
    var player_chunk := Vector2i(
        floor(float(player_tile.x) / chunk_size),
        floor(float(player_tile.y) / chunk_size)
    )

    for x in range(player_chunk.x - view_distance, player_chunk.x + view_distance + 1):
        for y in range(player_chunk.y - view_distance, player_chunk.y + view_distance + 1):
            var chunk := Vector2i(x, y)
            if not generated_chunks.has(chunk):
                _generate_chunk(chunk)

func _generate_chunk(chunk: Vector2i) -> void:
    generated_chunks[chunk] = true
    var start := chunk * chunk_size
    for x in range(start.x, start.x + chunk_size):
        for y in range(start.y, start.y + chunk_size):
            var value := noise.get_noise_2d(float(x), float(y))
            var atlas := Vector2i(0, 0)
            if value < -0.1:
                atlas = Vector2i(1, 0)
            tile_map.set_cell(0, Vector2i(x, y), tileset_source_id, atlas)

func _update_enemy_spawns(delta: float) -> void:
    _enemy_spawn_timer -= delta
    if _enemy_spawn_timer > 0.0:
        return

    var enemies := get_tree().get_nodes_in_group("enemies")
    if enemies.size() >= max_enemies:
        _enemy_spawn_timer = enemy_spawn_interval
        return

    _enemy_spawn_timer = enemy_spawn_interval
    _spawn_enemy()

func _spawn_enemy() -> void:
    var enemy := CharacterBody2D.new()
    enemy.set_script(_enemy_script)
    if _hard_mode_started and enemy.has_method("configure"):
        enemy.configure({
            "max_health": hard_enemy_health,
            "speed": hard_enemy_speed,
            "contact_damage": hard_enemy_contact_damage,
            "color": hard_enemy_color,
        })
    var angle := randf() * TAU
    var offset := Vector2(cos(angle), sin(angle)) * enemy_spawn_radius
    enemy.global_position = player.global_position + offset
    enemy.target = player
    add_child(enemy)

func _update_timer(delta: float) -> void:
    _elapsed_time += delta
    if not _hard_mode_started and _elapsed_time >= hard_mode_time:
        _hard_mode_started = true
    _update_timer_label()

func _update_timer_label() -> void:
    if timer_label == null:
        return
    var total_seconds := int(_elapsed_time)
    var minutes := total_seconds / 60
    var seconds := total_seconds % 60
    timer_label.text = "Timer: %02d:%02d" % [minutes, seconds]

func _on_player_health_changed(current: int, maximum: int) -> void:
    if health_label == null:
        return
    health_label.text = "HP: %d/%d" % [current, maximum]

func _ensure_hud() -> CanvasLayer:
    if has_node("HUD"):
        return $HUD
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    return layer

func _ensure_timer_label() -> Label:
    if hud.has_node("TimerLabel"):
        return hud.get_node("TimerLabel")
    var label := Label.new()
    label.name = "TimerLabel"
    label.position = Vector2(16, 16)
    hud.add_child(label)
    return label

func _ensure_health_label() -> Label:
    if hud.has_node("HealthLabel"):
        return hud.get_node("HealthLabel")
    var label := Label.new()
    label.name = "HealthLabel"
    label.position = Vector2(16, 36)
    hud.add_child(label)
    return label
