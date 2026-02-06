extends Area2D

signal picked_up

@export var pickup_radius := 8.0

@onready var sprite: Sprite2D = _ensure_sprite()
@onready var collision: CollisionShape2D = _ensure_collision()

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if body == null or not body.has_method("equip_magic_staff"):
        return

    body.call("equip_magic_staff")
    picked_up.emit()
    queue_free()

func _ensure_sprite() -> Sprite2D:
    if has_node("Sprite2D"):
        return $Sprite2D

    var sprite_node := Sprite2D.new()
    sprite_node.name = "Sprite2D"
    var image := Image.create(14, 14, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.12, 0.08, 0.2))
    image.fill_rect(Rect2i(6, 2, 2, 10), Color(0.55, 0.4, 0.2))
    image.fill_rect(Rect2i(4, 0, 6, 4), Color(0.45, 0.85, 1.0))
    image.fill_rect(Rect2i(5, 1, 4, 2), Color(0.8, 0.95, 1.0))
    var texture := ImageTexture.create_from_image(image)
    sprite_node.texture = texture
    add_child(sprite_node)
    return sprite_node

func _ensure_collision() -> CollisionShape2D:
    if has_node("CollisionShape2D"):
        return $CollisionShape2D

    var shape := CircleShape2D.new()
    shape.radius = pickup_radius
    var collision_node := CollisionShape2D.new()
    collision_node.name = "CollisionShape2D"
    collision_node.shape = shape
    add_child(collision_node)
    return collision_node
