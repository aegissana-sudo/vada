extends CharacterBody2D

signal died

@export var speed := 80.0
@export var max_health := 3
@export var contact_damage := 1
@export var contact_damage_interval := 0.6
@export var health_bar_size := Vector2(18.0, 3.0)
@export var health_bar_offset := Vector2(-9.0, -14.0)
@export var shield_bar_size := Vector2(18.0, 2.0)
@export var shield_bar_offset := Vector2(-9.0, -18.0)
@export var explode_on_contact := false
@export var explosion_damage := 2

var target: Node2D
var _health := max_health
var _max_shield := 0
var _shield := 0
var _contact_timer := 0.0
var _body_color := Color(0.9, 0.2, 0.2)
var _body_size := 14

@onready var sprite: Sprite2D = _ensure_sprite()
@onready var collision: CollisionShape2D = _ensure_collision()

func _ready() -> void:
    add_to_group("enemies")
    _health = max_health
    _apply_visual_style()
    queue_redraw()

func setup_stats(new_speed: float, new_max_health: int, new_contact_damage: int, color: Color, body_size: int = 14, shield_amount: int = 0, should_explode_on_contact: bool = false, new_explosion_damage: int = 2) -> void:
    speed = new_speed
    max_health = new_max_health
    contact_damage = new_contact_damage
    _health = max_health
    _body_color = color
    _body_size = max(body_size, 8)
    _max_shield = max(shield_amount, 0)
    _shield = _max_shield
    explode_on_contact = should_explode_on_contact
    explosion_damage = max(new_explosion_damage, 1)

    if is_node_ready():
        _apply_visual_style()
        queue_redraw()

func set_shield(shield_amount: int) -> void:
    _max_shield = max(shield_amount, 0)
    _shield = _max_shield
    queue_redraw()

func _physics_process(delta: float) -> void:
    _contact_timer = max(_contact_timer - delta, 0.0)
    if target == null:
        return

    var direction := (target.global_position - global_position)
    if direction.length() > 1.0:
        velocity = direction.normalized() * speed
    else:
        velocity = Vector2.ZERO

    move_and_slide()
    _apply_contact_damage()

func _apply_contact_damage() -> void:
    if _contact_timer > 0.0:
        return

    for index in range(get_slide_collision_count()):
        var collision: KinematicCollision2D = get_slide_collision(index)
        var collider := collision.get_collider()
        if collider == target and collider.has_method("take_damage"):
            if explode_on_contact:
                collider.take_damage(max(explosion_damage, contact_damage))
                died.emit()
                queue_free()
                return

            collider.take_damage(contact_damage)
            _contact_timer = contact_damage_interval
            return

func take_damage(amount: int) -> void:
    var remaining_damage := amount
    if _shield > 0:
        var absorbed := mini(_shield, remaining_damage)
        _shield -= absorbed
        remaining_damage -= absorbed

    if remaining_damage > 0:
        _health -= remaining_damage

    queue_redraw()
    if _health <= 0:
        died.emit()
        queue_free()

func multiply_health(multiplier: int) -> void:
    var safe_multiplier := maxi(multiplier, 1)
    max_health *= safe_multiplier
    _health *= safe_multiplier
    queue_redraw()

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

    if _max_shield <= 0:
        return

    var shield_ratio: float = clamp(float(_shield) / float(_max_shield), 0.0, 1.0)
    var shield_background := Rect2(shield_bar_offset, shield_bar_size)
    var shield_foreground := Rect2(
        shield_bar_offset,
        Vector2(shield_bar_size.x * shield_ratio, shield_bar_size.y)
    )
    draw_rect(shield_background, Color(0.05, 0.08, 0.2, 0.85))
    draw_rect(shield_foreground, Color(0.35, 0.75, 1.0, 0.95))

func _ensure_sprite() -> Sprite2D:
    if has_node("Sprite2D"):
        return $Sprite2D

    var sprite_node := Sprite2D.new()
    sprite_node.name = "Sprite2D"
    var image := Image.create(14, 14, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.9, 0.2, 0.2))
    var texture := ImageTexture.create_from_image(image)
    sprite_node.texture = texture
    add_child(sprite_node)
    return sprite_node

func _apply_visual_style() -> void:
    var image := Image.create(_body_size, _body_size, false, Image.FORMAT_RGBA8)
    image.fill(_body_color)
    sprite.texture = ImageTexture.create_from_image(image)
    sprite.centered = true

    var shape := collision.shape as CircleShape2D
    if shape == null:
        shape = CircleShape2D.new()
        collision.shape = shape
    shape.radius = _body_size * 0.45

    health_bar_size = Vector2(max(float(_body_size) + 4.0, 18.0), 3.0)
    health_bar_offset = Vector2(-health_bar_size.x * 0.5, -float(_body_size) * 0.8)
    shield_bar_size = Vector2(health_bar_size.x, 2.0)
    shield_bar_offset = health_bar_offset + Vector2(0.0, -4.0)

func _ensure_collision() -> CollisionShape2D:
    if has_node("CollisionShape2D"):
        return $CollisionShape2D

    var shape := CircleShape2D.new()
    shape.radius = 6.0
    var collision_node := CollisionShape2D.new()
    collision_node.name = "CollisionShape2D"
    collision_node.shape = shape
    add_child(collision_node)
    return collision_node
