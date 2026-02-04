extends CharacterBody2D

@export var speed := 220.0
@export var shoot_interval := 0.4
@export var bullet_speed := 380.0
@export var bullet_damage := 1

@onready var sprite: Sprite2D = $Sprite2D

var _shoot_timer := 0.0
var _bullet_script := preload("res://scripts/bullet.gd")

func _ready() -> void:
    var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.fill(Color(1.0, 0.85, 0.2))
    var texture := ImageTexture.create_from_image(image)
    sprite.texture = texture

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

    _shoot_timer = shoot_interval
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

    var bullet := Area2D.new()
    bullet.set_script(_bullet_script)
    bullet.global_position = global_position
    bullet.direction = direction.normalized()
    bullet.speed = bullet_speed
    bullet.damage = bullet_damage
    get_parent().add_child(bullet)
