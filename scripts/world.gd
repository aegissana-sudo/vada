extends Node2D

@export var tile_size := 16
@export var chunk_size := 32
@export var view_distance := 2
@export var enemy_spawn_interval := 1.0
@export var max_enemies := 12
@export var enemy_spawn_radius := 260.0

@onready var tile_map: TileMap = $TileMap
@onready var player: CharacterBody2D = $Player
@onready var survival_timer_label: Label = $CanvasLayer/SurvivalTimerLabel
@onready var game_over_menu: Control = $CanvasLayer/GameOverMenu
@onready var game_over_time_label: Label = $CanvasLayer/GameOverMenu/CenterContainer/VBoxContainer/TimeLabel
@onready var retry_button: Button = $CanvasLayer/GameOverMenu/CenterContainer/VBoxContainer/RetryButton

var noise := FastNoiseLite.new()
var generated_chunks: Dictionary = {}
var tileset_source_id := -1
var _enemy_spawn_timer := 0.0
var _enemy_script := preload("res://scripts/enemy.gd")
var _game_over := false
var _survival_time := 0.0

func _ready() -> void:
    noise.seed = randi()
    noise.frequency = 0.05
    _setup_tileset()
    _update_chunks()
    _update_survival_ui()
    player.died.connect(_on_player_died)
    retry_button.pressed.connect(_on_retry_button_pressed)

func _process(delta: float) -> void:
    if _game_over:
        return
    _survival_time += delta
    _update_survival_ui()
    _update_chunks()
    _update_enemy_spawns(delta)

func _update_survival_ui() -> void:
    var text := "Время: %.1f с" % _survival_time
    survival_timer_label.text = text
    game_over_time_label.text = "Продержались: %.1f с" % _survival_time

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
    var angle := randf() * TAU
    var offset := Vector2(cos(angle), sin(angle)) * enemy_spawn_radius
    enemy.global_position = player.global_position + offset
    enemy.target = player
    add_child(enemy)

func _on_player_died() -> void:
    if _game_over:
        return

    _game_over = true
    player.set_physics_process(false)
    player.set_process(false)
    player.visible = false
    if player.has_node("CollisionShape2D"):
        var collider: CollisionShape2D = player.get_node("CollisionShape2D")
        collider.disabled = true

    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy == null:
            continue
        enemy.set_physics_process(false)
        enemy.set_process(false)
        enemy.target = null

    game_over_menu.visible = true

func _on_retry_button_pressed() -> void:
    get_tree().reload_current_scene()
