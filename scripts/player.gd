extends CharacterBody2D

@export var speed := 220.0

@onready var sprite: Sprite2D = $Sprite2D

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
