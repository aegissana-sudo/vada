extends CharacterBody2D

@export var speed := 80.0
@export var max_health := 3
@export var contact_damage := 1
@export var damage_interval := 0.8

var target: Node2D
var _health := max_health
var _damage_timer := 0.0

@onready var sprite: Sprite2D = _ensure_sprite()
@onready var collision: CollisionShape2D = _ensure_collision()
@onready var health_label: Label = _ensure_health_label()

func _ready() -> void:
    add_to_group("enemies")
    _health = max_health
    _update_health_label()

func _physics_process(_delta: float) -> void:
    if target == null:
        return

    _damage_timer = maxf(_damage_timer - _delta, 0.0)
    var direction := (target.global_position - global_position)
    if direction.length() > 1.0:
        velocity = direction.normalized() * speed
    else:
        velocity = Vector2.ZERO

    move_and_slide()

    if _damage_timer == 0.0 and direction.length() <= 12.0 and target.has_method("take_damage"):
        target.take_damage(contact_damage)
        _damage_timer = damage_interval

func take_damage(amount: int) -> void:
    _health -= amount
    _update_health_label()
    if _health <= 0:
        queue_free()

func configure(stats: Dictionary) -> void:
    if stats.has("max_health"):
        max_health = stats.max_health
        _health = max_health
    if stats.has("speed"):
        speed = stats.speed
    if stats.has("contact_damage"):
        contact_damage = stats.contact_damage
    if stats.has("color"):
        sprite.modulate = stats.color
    _update_health_label()

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

func _ensure_health_label() -> Label:
    if has_node("HealthLabel"):
        return $HealthLabel

    var label := Label.new()
    label.name = "HealthLabel"
    label.position = Vector2(-10, -18)
    label.modulate = Color(1.0, 1.0, 1.0)
    add_child(label)
    return label

func _update_health_label() -> void:
    if health_label == null:
        return
    health_label.text = str(_health)
