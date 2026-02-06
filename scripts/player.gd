extends CharacterBody2D

signal died

@export var speed := 220.0
@export var shoot_interval := 0.4
@export var bullet_speed := 380.0
@export var bullet_damage := 1
@export var max_health := 6
@export var health_bar_size := Vector2(20.0, 4.0)
@export var health_bar_offset := Vector2(-10.0, -18.0)
@export var shotgun_pellet_count := 6
@export var shotgun_spread_degrees := 24.0
@export var shotgun_shoot_interval := 0.7
@export var shotgun_bullet_speed := 350.0
@export var shotgun_bullet_damage := 1
@export var shotgun_damage_bonus_per_upgrade := 1
@export var staff_beam_count := 6
@export var staff_spread_degrees := 24.0
@export var staff_shoot_interval := 0.7
@export var staff_beam_length := 280.0
@export var staff_beam_damage := 1
@export var staff_damage_bonus_per_upgrade := 1

@onready var sprite: Sprite2D = $Sprite2D

var _shoot_timer := 0.0
var _bullet_script := preload("res://scripts/bullet.gd")
var _health := max_health
var _has_shotgun := false
var _has_magic_staff := false

func apply_weapon_upgrade(upgrade_id: String) -> void:
    match upgrade_id:
        "pistol_damage":
            bullet_damage += 1
        "pistol_rate":
            shoot_interval = max(shoot_interval - 0.05, 0.1)
        "pistol_speed":
            bullet_speed += 40.0
        "shotgun_pellets":
            shotgun_pellet_count += 1
        "shotgun_rate":
            shotgun_shoot_interval = max(shotgun_shoot_interval - 0.07, 0.2)
        "shotgun_damage":
            shotgun_bullet_damage += shotgun_damage_bonus_per_upgrade
        "staff_beams":
            staff_beam_count += 1
        "staff_rate":
            staff_shoot_interval = max(staff_shoot_interval - 0.07, 0.2)
        "staff_damage":
            staff_beam_damage += staff_damage_bonus_per_upgrade

func _ready() -> void:
    add_to_group("player")
    var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.fill(Color(1.0, 0.85, 0.2))
    var texture := ImageTexture.create_from_image(image)
    sprite.texture = texture
    queue_redraw()

func _physics_process(_delta: float) -> void:
    var input_vector := Vector2(
        Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
        Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
    )

    if input_vector.length() > 1.0:
        input_vector = input_vector.normalized()

    velocity = input_vector * speed
    move_and_slide()

func _process(delta: float) -> void:
    _shoot_timer -= delta
    if _shoot_timer > 0.0:
        return

    var target := _find_nearest_enemy()
    if target == null:
        return

    _shoot_timer = _get_shoot_interval()
    _shoot_at(target)

func _find_nearest_enemy() -> Node2D:
    var enemies := get_tree().get_nodes_in_group("enemies")
    if enemies.is_empty():
        return null

    var closest: Node2D = null
    var closest_distance := INF
    for enemy in enemies:
        if enemy == null or not enemy is Node2D:
            continue
        var distance := global_position.distance_to(enemy.global_position)
        if distance < closest_distance:
            closest_distance = distance
            closest = enemy
    return closest

func _shoot_at(target: Node2D) -> void:
    var direction := (target.global_position - global_position)
    if direction.length() == 0.0:
        return

    if _has_magic_staff:
        _shoot_lightning_staff(direction.normalized())
        return

    if _has_shotgun:
        _shoot_shotgun(direction.normalized())
        return

    _spawn_bullet(direction.normalized(), bullet_speed, bullet_damage)

func equip_shotgun() -> void:
    _has_shotgun = true

func equip_magic_staff() -> void:
    _has_magic_staff = true

func has_shotgun() -> bool:
    return _has_shotgun

func has_magic_staff() -> bool:
    return _has_magic_staff

func _get_shoot_interval() -> float:
    if _has_magic_staff:
        return staff_shoot_interval

    if _has_shotgun:
        return shotgun_shoot_interval
    return shoot_interval

func _shoot_lightning_staff(base_direction: Vector2) -> void:
    var beam_count := maxi(staff_beam_count, 1)
    if beam_count == 1:
        _fire_lightning_beam(base_direction)
        return

    var spread_radians := deg_to_rad(staff_spread_degrees)
    for index in range(beam_count):
        var ratio := float(index) / float(beam_count - 1)
        var angle_offset: float = lerpf(-spread_radians * 0.5, spread_radians * 0.5, ratio)
        var beam_direction := base_direction.rotated(angle_offset).normalized()
        _fire_lightning_beam(beam_direction)

func _fire_lightning_beam(direction: Vector2) -> void:
    var space_state := get_world_2d().direct_space_state
    var query := PhysicsRayQueryParameters2D.create(
        global_position,
        global_position + direction * staff_beam_length
    )
    query.exclude = [self]
    query.collide_with_areas = false
    query.collide_with_bodies = true
    var hit := space_state.intersect_ray(query)
    var end_point := global_position + direction * staff_beam_length

    if not hit.is_empty():
        end_point = hit.position
        var collider := hit.collider
        if collider != null and collider.is_in_group("enemies") and collider.has_method("take_damage"):
            collider.take_damage(staff_beam_damage)

    var beam := Line2D.new()
    beam.width = 2.5
    beam.default_color = Color(0.45, 0.85, 1.0, 0.95)
    beam.add_point(global_position)
    beam.add_point(end_point)
    get_parent().add_child(beam)

    var timer := get_tree().create_timer(0.06)
    timer.timeout.connect(func() -> void:
        if is_instance_valid(beam):
            beam.queue_free()
    )

func _shoot_shotgun(base_direction: Vector2) -> void:
    var pellet_count := maxi(shotgun_pellet_count, 1)
    if pellet_count == 1:
        _spawn_bullet(base_direction, shotgun_bullet_speed, shotgun_bullet_damage)
        return

    var spread_radians := deg_to_rad(shotgun_spread_degrees)
    for index in range(pellet_count):
        var ratio := float(index) / float(pellet_count - 1)
        var angle_offset: float = lerpf(-spread_radians * 0.5, spread_radians * 0.5, ratio)
        var pellet_direction := base_direction.rotated(angle_offset).normalized()
        _spawn_bullet(pellet_direction, shotgun_bullet_speed, shotgun_bullet_damage)

func _spawn_bullet(direction: Vector2, speed_value: float, damage_value: int) -> void:
    var bullet := Area2D.new()
    bullet.set_script(_bullet_script)
    bullet.global_position = global_position
    bullet.direction = direction
    bullet.speed = speed_value
    bullet.damage = damage_value
    get_parent().add_child(bullet)

func take_damage(amount: int) -> void:
    _health = max(_health - amount, 0)
    queue_redraw()
    if _health <= 0:
        died.emit()

func _draw() -> void:
    if max_health <= 0:
        return

    var ratio: float = clamp(float(_health) / float(max_health), 0.0, 1.0)
    var background_rect := Rect2(health_bar_offset, health_bar_size)
    var foreground_rect := Rect2(
        health_bar_offset,
        Vector2(health_bar_size.x * ratio, health_bar_size.y)
    )
    draw_rect(background_rect, Color(0.1, 0.1, 0.1, 0.8))
    draw_rect(foreground_rect, Color(0.2, 0.9, 0.2, 0.9))
