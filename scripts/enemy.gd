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
    sprite.texture = _create_monster_texture()
    sprite.centered = true

    var shape := collision.shape as CircleShape2D
    if shape == null:
        shape = CircleShape2D.new()
        collision.shape = shape
    shape.radius = _body_size * 0.42

    health_bar_size = Vector2(max(float(_body_size) + 4.0, 18.0), 3.0)
    health_bar_offset = Vector2(-health_bar_size.x * 0.5, -float(_body_size) * 0.85)
    shield_bar_size = Vector2(health_bar_size.x, 2.0)
    shield_bar_offset = health_bar_offset + Vector2(0.0, -4.0)

func _create_monster_texture() -> ImageTexture:
    var size := maxi(_body_size, 8)
    var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.0, 0.0, 0.0, 0.0))

    var center := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
    var radius := size * 0.42
    var edge_softness: float = maxf(radius * 0.18, 1.0)
    var highlight_dir := Vector2(-0.55, -0.8).normalized()

    var shadow := _body_color.darkened(0.38)
    var base := _body_color
    var highlight := _body_color.lightened(0.3)

    for y in range(size):
        for x in range(size):
            var pixel_pos := Vector2(x, y)
            var local := pixel_pos - center
            var distance := local.length()
            if distance > radius:
                continue

            var edge_alpha := clamp((radius - distance) / edge_softness, 0.0, 1.0)
            var normal: Vector2 = local / maxf(distance, 0.0001)
            var light_mix := clamp((normal.dot(highlight_dir) + 1.0) * 0.5, 0.0, 1.0)
            var base_color := shadow.lerp(base, 0.45 + 0.45 * light_mix)
            base_color = base_color.lerp(highlight, pow(light_mix, 1.6) * 0.6)

            var inner_glow := clamp((radius * 0.35 - distance) / (radius * 0.35), 0.0, 1.0)
            if inner_glow > 0.0:
                base_color = base_color.lightened(inner_glow * 0.08)

            image.set_pixel(x, y, Color(base_color.r, base_color.g, base_color.b, edge_alpha))

    var eye_glow := Color(1.0, 0.93, 0.4, 0.95)
    var eye_core := Color(0.12, 0.04, 0.04, 1.0)
    var eye_y := int(round(size * 0.45))
    var eye_offset := int(round(size * 0.18))
    var left_eye_x := int(round(center.x)) - eye_offset
    var right_eye_x := int(round(center.x)) + eye_offset

    _paint_circle(image, Vector2(left_eye_x, eye_y), max(size * 0.09, 1.0), eye_glow)
    _paint_circle(image, Vector2(right_eye_x, eye_y), max(size * 0.09, 1.0), eye_glow)
    _paint_circle(image, Vector2(left_eye_x, eye_y), max(size * 0.045, 1.0), eye_core)
    _paint_circle(image, Vector2(right_eye_x, eye_y), max(size * 0.045, 1.0), eye_core)

    var horn_color := _body_color.lightened(0.22)
    var horn_height := max(size * 0.12, 1.0)
    var horn_width := max(size * 0.1, 1.0)
    _paint_triangle(
        image,
        Vector2(center.x - size * 0.18, center.y - radius * 0.72),
        Vector2(center.x - size * 0.18 - horn_width, center.y - radius * 0.72 + horn_height),
        Vector2(center.x - size * 0.18 + horn_width, center.y - radius * 0.72 + horn_height),
        horn_color
    )
    _paint_triangle(
        image,
        Vector2(center.x + size * 0.18, center.y - radius * 0.72),
        Vector2(center.x + size * 0.18 - horn_width, center.y - radius * 0.72 + horn_height),
        Vector2(center.x + size * 0.18 + horn_width, center.y - radius * 0.72 + horn_height),
        horn_color
    )

    return ImageTexture.create_from_image(image)

func _paint_circle(image: Image, position: Vector2, radius: float, color: Color) -> void:
    var min_x := maxi(int(floor(position.x - radius)), 0)
    var max_x := mini(int(ceil(position.x + radius)), image.get_width() - 1)
    var min_y := maxi(int(floor(position.y - radius)), 0)
    var max_y := mini(int(ceil(position.y + radius)), image.get_height() - 1)

    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            var distance := Vector2(float(x), float(y)).distance_to(position)
            if distance <= radius:
                image.set_pixel(x, y, color)

func _paint_triangle(image: Image, p0: Vector2, p1: Vector2, p2: Vector2, color: Color) -> void:
    var min_x := maxi(int(floor(min(p0.x, min(p1.x, p2.x)))), 0)
    var max_x := mini(int(ceil(max(p0.x, max(p1.x, p2.x)))), image.get_width() - 1)
    var min_y := maxi(int(floor(min(p0.y, min(p1.y, p2.y)))), 0)
    var max_y := mini(int(ceil(max(p0.y, max(p1.y, p2.y)))), image.get_height() - 1)

    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            var pt := Vector2(x + 0.5, y + 0.5)
            if _point_in_triangle(pt, p0, p1, p2):
                image.set_pixel(x, y, color)

func _point_in_triangle(pt: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
    var d1 := _sign(pt, a, b)
    var d2 := _sign(pt, b, c)
    var d3 := _sign(pt, c, a)

    var has_negative := (d1 < 0.0) or (d2 < 0.0) or (d3 < 0.0)
    var has_positive := (d1 > 0.0) or (d2 > 0.0) or (d3 > 0.0)
    return not (has_negative and has_positive)

func _sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)

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
