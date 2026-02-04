extends CharacterBody2D

@export var speed := 80.0
@export var max_health := 3

var target: Node2D
var _health := max_health

@onready var sprite: Sprite2D = _ensure_sprite()
@onready var collision: CollisionShape2D = _ensure_collision()

func _ready() -> void:
    add_to_group("enemies")

func _physics_process(_delta: float) -> void:
    if target == null:
        return

    var direction := (target.global_position - global_position)
    if direction.length() > 1.0:
        velocity = direction.normalized() * speed
    else:
        velocity = Vector2.ZERO

    move_and_slide()

func take_damage(amount: int) -> void:
    _health -= amount
    if _health <= 0:
        queue_free()

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
