extends Area2D

@export var speed := 360.0
@export var damage := 1
@export var max_lifetime := 1.6

var direction := Vector2.ZERO
var _time_alive := 0.0

@onready var sprite: Sprite2D = _ensure_sprite()
@onready var collision: CollisionShape2D = _ensure_collision()

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    _time_alive += delta
    if _time_alive >= max_lifetime:
        queue_free()
        return

    global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
    if body.has_method("take_damage"):
        body.take_damage(damage)
        queue_free()

func _ensure_sprite() -> Sprite2D:
    if has_node("Sprite2D"):
        return $Sprite2D

    var sprite_node := Sprite2D.new()
    sprite_node.name = "Sprite2D"
    var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
    image.fill(Color(1.0, 0.9, 0.4))
    var texture := ImageTexture.create_from_image(image)
    sprite_node.texture = texture
    add_child(sprite_node)
    return sprite_node

func _ensure_collision() -> CollisionShape2D:
    if has_node("CollisionShape2D"):
        return $CollisionShape2D

    var shape := CircleShape2D.new()
    shape.radius = 3.0
    var collision_node := CollisionShape2D.new()
    collision_node.name = "CollisionShape2D"
    collision_node.shape = shape
    add_child(collision_node)
    return collision_node
