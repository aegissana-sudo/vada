extends CharacterBody2D

@export var speed := 80.0
@export var max_health := 3
@export var contact_damage := 1
@export var contact_damage_interval := 0.6
@export var health_bar_size := Vector2(18.0, 3.0)
@export var health_bar_offset := Vector2(-9.0, -14.0)

var target: Node2D
var _health := max_health
var _contact_timer := 0.0

@onready var sprite: Sprite2D = _ensure_sprite()
@onready var collision: CollisionShape2D = _ensure_collision()

func _ready() -> void:
    add_to_group("enemies")
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
        var collision := get_slide_collision(index)
        var collider := collision.get_collider()
        if collider == target and collider.has_method("take_damage"):
            collider.take_damage(contact_damage)
            _contact_timer = contact_damage_interval
            return

func take_damage(amount: int) -> void:
    _health -= amount
    queue_redraw()
    if _health <= 0:
        queue_free()

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
