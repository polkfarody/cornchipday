extends Camera2D

# FB6 (2P co-op): Player.tscn's own Camera2D is a direct child with a
# hardcoded single-target follow (see FB29/FB30's camera work), which can't
# track two independent players. This is a level-owned camera instead --
# tracks the midpoint of both players and zooms out as they separate, so
# simple shared-screen co-op keeps both on screen without split-screen.

@export var target_a: Node2D
@export var target_b: Node2D

const MIN_ZOOM_SCALAR := 1.0  # closest zoom, same framing as single-player
const MAX_ZOOM_OUT_SCALAR := 0.55  # furthest zoom-out when players separate
const ZOOM_START_DISTANCE := 300.0  # start zooming out past this on-screen separation
const ZOOM_FULL_OUT_DISTANCE := 900.0
const FOLLOW_SPEED := 4.0
const ZOOM_SPEED := 3.0

func _process(delta: float) -> void:
	if target_a == null or target_b == null:
		return
	var midpoint: Vector2 = (target_a.global_position + target_b.global_position) / 2.0
	global_position = global_position.lerp(midpoint, minf(1.0, delta * FOLLOW_SPEED))

	var separation: float = target_a.global_position.distance_to(target_b.global_position)
	var t: float = clampf((separation - ZOOM_START_DISTANCE) / (ZOOM_FULL_OUT_DISTANCE - ZOOM_START_DISTANCE), 0.0, 1.0)
	var desired_scalar: float = lerpf(MIN_ZOOM_SCALAR, MAX_ZOOM_OUT_SCALAR, t)
	zoom = zoom.lerp(Vector2(desired_scalar, desired_scalar), minf(1.0, delta * ZOOM_SPEED))
