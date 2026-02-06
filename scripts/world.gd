extends Node2D

@export var tile_size := 16
@export var chunk_size := 32
@export var view_distance := 2
@export var enemy_spawn_interval := 1.0
@export var max_enemies := 12
@export var enemy_spawn_radius := 260.0
@export var hard_enemy_unlock_time := 120.0
@export var bomber_enemy_unlock_time := 120.0
@export var bomber_enemy_spawn_chance := 0.3
@export var hard_enemy_spawn_chance := 0.35
@export var escalation_start_time := 180.0
@export var shield_enemy_spawn_chance := 0.45
@export var shield_enemy_amount := 2
@export var hazard_damage := 1
@export var hazard_damage_interval := 0.5
@export var enemy_health_doubling_interval := 120.0

@onready var tile_map: TileMap = $TileMap
@onready var player: CharacterBody2D = $Player
@onready var survival_timer_label: Label = $CanvasLayer/SurvivalTimerLabel
@onready var kill_counter_label: Label = $CanvasLayer/KillCounterLabel
@onready var level_label: Label = $CanvasLayer/LevelLabel
@onready var main_menu: Control = $CanvasLayer/MainMenu
@onready var game_over_menu: Control = $CanvasLayer/GameOverMenu
@onready var game_over_time_label: Label = $CanvasLayer/GameOverMenu/CenterContainer/VBoxContainer/TimeLabel
@onready var retry_button: Button = $CanvasLayer/GameOverMenu/CenterContainer/VBoxContainer/RetryButton
@onready var start_button: Button = $CanvasLayer/MainMenu/CenterContainer/VBoxContainer/StartButton
@onready var exit_button: Button = $CanvasLayer/MainMenu/CenterContainer/VBoxContainer/ExitButton
@onready var shotgun_slot_label: Label = $CanvasLayer/InventoryUI/SlotsContainer/Slot1/Label
@onready var staff_slot_label: Label = $CanvasLayer/InventoryUI/SlotsContainer/Slot2/Label
@onready var pause_button: Button = $CanvasLayer/PauseButton
@onready var level_up_menu: Control = $CanvasLayer/LevelUpMenu
@onready var level_up_title_label: Label = $CanvasLayer/LevelUpMenu/CenterContainer/VBoxContainer/TitleLabel
@onready var level_up_option_1_button: Button = $CanvasLayer/LevelUpMenu/CenterContainer/VBoxContainer/Option1Button
@onready var level_up_option_2_button: Button = $CanvasLayer/LevelUpMenu/CenterContainer/VBoxContainer/Option2Button
@onready var level_up_option_3_button: Button = $CanvasLayer/LevelUpMenu/CenterContainer/VBoxContainer/Option3Button
@onready var chest_indicator_label: Label = $CanvasLayer/ChestIndicatorLabel

var noise := FastNoiseLite.new()
var generated_chunks: Dictionary = {}
var tileset_source_id := -1
var _enemy_spawn_timer := 0.0
var _enemy_script := preload("res://scripts/enemy.gd")
var _shotgun_pickup_script := preload("res://scripts/shotgun_pickup.gd")
var _staff_pickup_script := preload("res://scripts/magic_staff_pickup.gd")
var _game_over := false
var _survival_time := 0.0
var _kill_count := 0
var _level := 1
var _xp := 0
var _xp_to_next_level := 15
var _game_started := false
var _is_paused := false
var _is_level_up_menu_open := false
var _active_upgrade_options: Array = []
var _hazards_active := false
var _hazard_damage_timer := 0.0
var _enemy_health_multiplier := 1
var _next_enemy_health_doubling_time := 0.0
var _shotgun_pickup: Area2D
var _magic_staff_pickup: Area2D

const SHOTGUN_PICKUP_MIN_DISTANCE := 420.0
const SHOTGUN_PICKUP_MAX_DISTANCE := 1150.0
const SHOTGUN_PICKUP_SPAWN_ATTEMPTS := 24
const STAFF_PICKUP_MIN_DISTANCE := 520.0
const STAFF_PICKUP_MAX_DISTANCE := 1300.0
const STAFF_PICKUP_SPAWN_ATTEMPTS := 24

const TILE_GRASS := Vector2i(0, 0)
const TILE_WATER := Vector2i(1, 0)
const TILE_HAZARD := Vector2i(2, 0)

const UPGRADE_POOL := [
    {
        "id": "pistol_damage",
        "title": "Пистолет: урон +1",
        "description": "Каждая пуля базового оружия наносит больше урона."
    },
    {
        "id": "pistol_rate",
        "title": "Пистолет: скорострельность",
        "description": "Пистолет стреляет чаще (уменьшается пауза между выстрелами)."
    },
    {
        "id": "pistol_speed",
        "title": "Пистолет: скорость пули",
        "description": "Пули летят быстрее и быстрее достигают цели."
    },
    {
        "id": "shotgun_pellets",
        "title": "Дробовик: +1 дробина",
        "description": "Каждый выстрел дробовика выпускает больше дробин."
    },
    {
        "id": "shotgun_rate",
        "title": "Дробовик: темп огня",
        "description": "Дробовик стреляет чаще."
    },
    {
        "id": "shotgun_damage",
        "title": "Дробовик: урон дроби",
        "description": "Каждая дробина наносит больше урона."
    },
    {
        "id": "staff_beams",
        "title": "Посох: +1 луч",
        "description": "Магический посох выпускает больше лучей молнии за выстрел."
    },
    {
        "id": "staff_rate",
        "title": "Посох: темп огня",
        "description": "Магический посох стреляет чаще."
    },
    {
        "id": "staff_damage",
        "title": "Посох: урон молнии",
        "description": "Каждый луч молнии наносит больше урона."
    }
]

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    tile_map.process_mode = Node.PROCESS_MODE_PAUSABLE
    player.process_mode = Node.PROCESS_MODE_PAUSABLE
    pause_button.process_mode = Node.PROCESS_MODE_ALWAYS

    noise.seed = randi()
    noise.frequency = 0.05
    _setup_tileset()
    _update_chunks()
    _update_survival_ui()
    _update_kill_counter_ui()
    _update_level_ui()
    _update_inventory_ui()
    _spawn_shotgun_pickup()
    _spawn_staff_pickup()
    _update_chest_indicator_ui()
    player.died.connect(_on_player_died)
    retry_button.pressed.connect(_on_retry_button_pressed)
    start_button.pressed.connect(_on_start_button_pressed)
    exit_button.pressed.connect(_on_exit_button_pressed)
    pause_button.pressed.connect(_on_pause_button_pressed)
    level_up_option_1_button.pressed.connect(_on_level_up_option_selected.bind(0))
    level_up_option_2_button.pressed.connect(_on_level_up_option_selected.bind(1))
    level_up_option_3_button.pressed.connect(_on_level_up_option_selected.bind(2))

    _set_gameplay_active(false)

func _process(delta: float) -> void:
    if not _game_started or _game_over or _is_paused:
        return
    _survival_time += delta
    _update_survival_ui()
    _update_chunks()
    _update_enemy_spawns(delta)
    _update_enemy_health_scaling()
    _update_environment_escalation(delta)
    _update_chest_indicator_ui()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _toggle_pause()


func _set_gameplay_active(is_active: bool) -> void:
    _game_started = is_active
    _is_paused = false
    get_tree().paused = false
    player.set_physics_process(is_active)
    player.set_process(is_active)
    player.visible = is_active

    if player.has_node("CollisionShape2D"):
        var collider: CollisionShape2D = player.get_node("CollisionShape2D")
        collider.disabled = not is_active

    var inventory_ui: Control = $CanvasLayer/InventoryUI
    inventory_ui.visible = is_active
    pause_button.visible = is_active
    pause_button.text = "Пауза (Esc)"
    level_label.visible = is_active
    level_up_menu.visible = false
    chest_indicator_label.visible = is_active and (_shotgun_pickup != null or _magic_staff_pickup != null)

    if is_active:
        _enemy_health_multiplier = 1
        _next_enemy_health_doubling_time = enemy_health_doubling_interval


func _toggle_pause() -> void:
    if not _game_started or _game_over or _is_level_up_menu_open:
        return

    _is_paused = not _is_paused
    get_tree().paused = _is_paused
    pause_button.text = "Продолжить (Esc)" if _is_paused else "Пауза (Esc)"


func _on_pause_button_pressed() -> void:
    _toggle_pause()


func _on_start_button_pressed() -> void:
    main_menu.visible = false
    _set_gameplay_active(true)
    get_tree().paused = false


func _on_exit_button_pressed() -> void:
    get_tree().quit()


func _update_inventory_ui() -> void:
    if bool(player.call("has_shotgun")):
        shotgun_slot_label.text = "2: ДРБ"
    else:
        shotgun_slot_label.text = "2"

    if bool(player.call("has_magic_staff")):
        staff_slot_label.text = "3: ПСХ"
    else:
        staff_slot_label.text = "3"

func _spawn_shotgun_pickup() -> void:
    _shotgun_pickup = Area2D.new()
    _shotgun_pickup.set_script(_shotgun_pickup_script)
    _shotgun_pickup.process_mode = Node.PROCESS_MODE_PAUSABLE
    _shotgun_pickup.global_position = _pick_random_shotgun_position()
    _shotgun_pickup.picked_up.connect(_on_shotgun_picked_up)
    add_child(_shotgun_pickup)

func _on_shotgun_picked_up() -> void:
    _shotgun_pickup = null
    _update_inventory_ui()
    _update_chest_indicator_ui()

func _spawn_staff_pickup() -> void:
    _magic_staff_pickup = Area2D.new()
    _magic_staff_pickup.set_script(_staff_pickup_script)
    _magic_staff_pickup.process_mode = Node.PROCESS_MODE_PAUSABLE
    _magic_staff_pickup.global_position = _pick_random_staff_position()
    _magic_staff_pickup.picked_up.connect(_on_staff_picked_up)
    add_child(_magic_staff_pickup)

func _on_staff_picked_up() -> void:
    _magic_staff_pickup = null
    _update_inventory_ui()
    _update_chest_indicator_ui()

func _pick_random_shotgun_position() -> Vector2:
    for _attempt in range(SHOTGUN_PICKUP_SPAWN_ATTEMPTS):
        var angle := randf() * TAU
        var distance := randf_range(SHOTGUN_PICKUP_MIN_DISTANCE, SHOTGUN_PICKUP_MAX_DISTANCE)
        var offset := Vector2(cos(angle), sin(angle)) * distance
        var world_position := player.global_position + offset
        var tile_position := Vector2i(
            floor(world_position.x / tile_size),
            floor(world_position.y / tile_size)
        )
        var chunk := Vector2i(
            floor(float(tile_position.x) / chunk_size),
            floor(float(tile_position.y) / chunk_size)
        )
        if not generated_chunks.has(chunk):
            _generate_chunk(chunk)

        if _select_atlas_for_tile(tile_position.x, tile_position.y) == TILE_GRASS:
            return world_position

    return player.global_position + Vector2(SHOTGUN_PICKUP_MIN_DISTANCE, 0.0)

func _pick_random_staff_position() -> Vector2:
    for _attempt in range(STAFF_PICKUP_SPAWN_ATTEMPTS):
        var angle := randf() * TAU
        var distance := randf_range(STAFF_PICKUP_MIN_DISTANCE, STAFF_PICKUP_MAX_DISTANCE)
        var offset := Vector2(cos(angle), sin(angle)) * distance
        var world_position := player.global_position + offset
        var tile_position := Vector2i(
            floor(world_position.x / tile_size),
            floor(world_position.y / tile_size)
        )
        var chunk := Vector2i(
            floor(float(tile_position.x) / chunk_size),
            floor(float(tile_position.y) / chunk_size)
        )
        if not generated_chunks.has(chunk):
            _generate_chunk(chunk)

        if _select_atlas_for_tile(tile_position.x, tile_position.y) == TILE_GRASS:
            return world_position

    return player.global_position + Vector2(STAFF_PICKUP_MIN_DISTANCE, 0.0)

func _update_chest_indicator_ui() -> void:
    var closest_pickup := _find_closest_pickup()
    if closest_pickup.is_empty():
        chest_indicator_label.visible = false
        return

    var pickup_node: Area2D = closest_pickup["node"]
    var pickup_title: String = closest_pickup["title"]
    var to_chest := pickup_node.global_position - player.global_position
    var distance := int(to_chest.length())
    var direction_arrow := _get_direction_arrow(to_chest)
    chest_indicator_label.text = "%s: %s %d" % [pickup_title, direction_arrow, distance]
    chest_indicator_label.visible = _game_started and not _game_over

func _find_closest_pickup() -> Dictionary:
    var candidates: Array = []
    if _shotgun_pickup != null:
        candidates.append({"node": _shotgun_pickup, "title": "Сундук с дробовиком"})
    if _magic_staff_pickup != null:
        candidates.append({"node": _magic_staff_pickup, "title": "Сундук с посохом"})

    if candidates.is_empty():
        return {}

    var closest: Dictionary = candidates[0]
    var best_distance: float = (closest["node"].global_position - player.global_position).length()
    for candidate in candidates:
        var candidate_distance: float = (candidate["node"].global_position - player.global_position).length()
        if candidate_distance < best_distance:
            best_distance = candidate_distance
            closest = candidate

    return closest

func _get_direction_arrow(direction: Vector2) -> String:
    if direction.length() <= 0.001:
        return "•"

    var angle := fposmod(direction.angle(), TAU)
    var octant := int(round(angle / (PI / 4.0))) % 8
    var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
    return arrows[octant]

func _update_survival_ui() -> void:
    var formatted_time := _format_survival_time(_survival_time)
    var text := "Время: %s" % formatted_time
    survival_timer_label.text = text
    game_over_time_label.text = "Продержались: %s" % formatted_time


func _update_kill_counter_ui() -> void:
    kill_counter_label.text = "Убийства: %d" % _kill_count

func _update_level_ui() -> void:
    level_label.text = "Уровень: %d (%d/%d XP)" % [_level, _xp, _xp_to_next_level]

func _format_survival_time(total_seconds: float) -> String:
    var whole_seconds := int(total_seconds)
    var minutes := whole_seconds / 60
    var seconds := whole_seconds % 60
    return "%02d:%02d" % [minutes, seconds]

func _setup_tileset() -> void:
    var tileset := TileSet.new()
    var source := TileSetAtlasSource.new()
    tileset_source_id = tileset.add_source(source)

    var image := Image.create(tile_size * 3, tile_size, false, Image.FORMAT_RGBA8)
    image.fill_rect(Rect2i(0, 0, tile_size, tile_size), Color(0.2, 0.6, 0.2))
    image.fill_rect(Rect2i(tile_size, 0, tile_size, tile_size), Color(0.2, 0.4, 0.8))
    image.fill_rect(Rect2i(tile_size * 2, 0, tile_size, tile_size), Color(0.75, 0.25, 0.15))

    var texture := ImageTexture.create_from_image(image)
    source.texture = texture
    source.texture_region_size = Vector2i(tile_size, tile_size)
    source.create_tile(TILE_GRASS)
    source.create_tile(TILE_WATER)
    source.create_tile(TILE_HAZARD)

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
            tile_map.set_cell(0, Vector2i(x, y), tileset_source_id, _select_atlas_for_tile(x, y))


func _select_atlas_for_tile(x: int, y: int) -> Vector2i:
    var value := noise.get_noise_2d(float(x), float(y))
    if value < -0.1:
        return TILE_WATER

    if _hazards_active and value > 0.42 and value < 0.56:
        return TILE_HAZARD

    return TILE_GRASS

func _update_environment_escalation(delta: float) -> void:
    if not _hazards_active and _survival_time >= escalation_start_time:
        _hazards_active = true
        _refresh_nearby_chunk_hazards()

    _apply_ground_hazard_damage(delta)

func _refresh_nearby_chunk_hazards() -> void:
    var player_tile := Vector2i(
        floor(player.global_position.x / tile_size),
        floor(player.global_position.y / tile_size)
    )
    var player_chunk := Vector2i(
        floor(float(player_tile.x) / chunk_size),
        floor(float(player_tile.y) / chunk_size)
    )

    for x in range(player_chunk.x - view_distance - 1, player_chunk.x + view_distance + 2):
        for y in range(player_chunk.y - view_distance - 1, player_chunk.y + view_distance + 2):
            var start := Vector2i(x, y) * chunk_size
            for tx in range(start.x, start.x + chunk_size):
                for ty in range(start.y, start.y + chunk_size):
                    tile_map.set_cell(0, Vector2i(tx, ty), tileset_source_id, _select_atlas_for_tile(tx, ty))

func _apply_ground_hazard_damage(delta: float) -> void:
    if not _hazards_active:
        return

    _hazard_damage_timer = max(_hazard_damage_timer - delta, 0.0)
    if _hazard_damage_timer > 0.0:
        return

    var player_tile := Vector2i(
        floor(player.global_position.x / tile_size),
        floor(player.global_position.y / tile_size)
    )
    var tile_data := tile_map.get_cell_atlas_coords(0, player_tile)
    if tile_data != TILE_HAZARD:
        return

    if player.has_method("take_damage"):
        player.take_damage(hazard_damage)
        _hazard_damage_timer = hazard_damage_interval

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
    enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
    _configure_enemy_difficulty(enemy)

    var angle := randf() * TAU
    var offset := Vector2(cos(angle), sin(angle)) * enemy_spawn_radius
    enemy.global_position = player.global_position + offset
    enemy.target = player
    if enemy.has_method("multiply_health") and _enemy_health_multiplier > 1:
        enemy.multiply_health(_enemy_health_multiplier)
    enemy.died.connect(_on_enemy_died)
    add_child(enemy)

func _update_enemy_health_scaling() -> void:
    if enemy_health_doubling_interval <= 0.0:
        return

    while _survival_time >= _next_enemy_health_doubling_time:
        _enemy_health_multiplier *= 2
        _next_enemy_health_doubling_time += enemy_health_doubling_interval
        _double_existing_enemies_health()

func _double_existing_enemies_health() -> void:
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy != null and enemy.has_method("multiply_health"):
            enemy.multiply_health(2)

func _configure_enemy_difficulty(enemy: CharacterBody2D) -> void:
    if not enemy.has_method("setup_stats"):
        return

    var is_bomber_enemy := _survival_time >= bomber_enemy_unlock_time and randf() < bomber_enemy_spawn_chance
    if is_bomber_enemy:
        enemy.setup_stats(108.0, 3, 1, Color(1.0, 0.45, 0.15), 15, 0, true, 3)
        return

    var is_hard_enemy := _survival_time >= hard_enemy_unlock_time and randf() < hard_enemy_spawn_chance
    if is_hard_enemy:
        enemy.setup_stats(120.0, 6, 2, Color(0.6, 0.1, 0.9), 18)

    var should_spawn_shielded_enemy := _survival_time >= escalation_start_time and randf() < shield_enemy_spawn_chance
    if should_spawn_shielded_enemy:
        if is_hard_enemy:
            enemy.setup_stats(132.0, 8, 2, Color(0.45, 0.75, 1.0), 18, shield_enemy_amount)
        else:
            enemy.setup_stats(92.0, 4, 1, Color(0.45, 0.75, 1.0), 15, shield_enemy_amount)

func _on_enemy_died() -> void:
    if _game_over:
        return

    _kill_count += 1
    _xp += 1
    _update_kill_counter_ui()
    _update_level_ui()

    if _xp >= _xp_to_next_level:
        _level_up()

func _level_up() -> void:
    _level += 1
    _xp -= _xp_to_next_level
    _xp_to_next_level += 9
    _update_level_ui()
    _show_level_up_menu()

func _show_level_up_menu() -> void:
    _is_level_up_menu_open = true
    _is_paused = true
    get_tree().paused = true

    level_up_title_label.text = "Новый уровень: %d" % _level
    _active_upgrade_options = _build_upgrade_options(3)
    _set_upgrade_button(level_up_option_1_button, 0)
    _set_upgrade_button(level_up_option_2_button, 1)
    _set_upgrade_button(level_up_option_3_button, 2)

    level_up_menu.visible = true
    pause_button.text = "Пауза (Esc)"

func _build_upgrade_options(count: int) -> Array:
    var options := UPGRADE_POOL.duplicate(true)
    options.shuffle()
    return options.slice(0, mini(count, options.size()))

func _set_upgrade_button(button: Button, index: int) -> void:
    if index >= _active_upgrade_options.size():
        button.visible = false
        button.disabled = true
        return

    var option: Dictionary = _active_upgrade_options[index]
    var option_text := "%s\n%s" % [option["title"], option["description"]]
    button.text = option_text
    button.visible = true
    button.disabled = false

func _on_level_up_option_selected(index: int) -> void:
    if index >= _active_upgrade_options.size():
        return

    var option: Dictionary = _active_upgrade_options[index]
    if player.has_method("apply_weapon_upgrade"):
        player.apply_weapon_upgrade(option["id"])

    level_up_menu.visible = false
    _active_upgrade_options.clear()
    _is_level_up_menu_open = false

    if _game_over:
        return

    _is_paused = false
    get_tree().paused = false
    pause_button.text = "Пауза (Esc)"

func _on_player_died() -> void:
    if _game_over:
        return

    _game_over = true
    _is_paused = false
    _is_level_up_menu_open = false
    get_tree().paused = false
    pause_button.visible = false
    level_up_menu.visible = false
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
