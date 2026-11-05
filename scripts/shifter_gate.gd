extends RefCounted
## The H-pattern gate, in "gate units":
##
##   1   3   5        columns at x = -1, 0, 1
##   |   |   |        neutral row at y = 0
##   +---N---+        gears at y = +1 (up) / -1 (down)
##   |   |   |
##   2   4   R
##
## The knob is locked to the gate, so 2nd -> 3rd travels down to neutral, across, then up.

const REVERSE := -1
const ENGAGE := 0.72  ## how far into a slot before the gear engages


static func gear_at(p: Vector2) -> int:
	if absf(p.y) < ENGAGE:
		return 0
	var col := roundi(p.x)
	var up := p.y > 0.0
	match col:
		-1: return 1 if up else 2
		0: return 3 if up else 4
		_: return 5 if up else REVERSE


static func slot_for(gear: int) -> Vector2:
	match gear:
		1: return Vector2(-1, 1)
		2: return Vector2(-1, -1)
		3: return Vector2(0, 1)
		4: return Vector2(0, -1)
		5: return Vector2(1, 1)
		REVERSE: return Vector2(1, -1)
	return Vector2.ZERO


## Nearest point on the gate (the neutral row or one of the three columns).
static func project(p: Vector2) -> Vector2:
	var best := Vector2(clampf(p.x, -1, 1), 0)
	var best_d := p.distance_squared_to(best)
	for c in [-1, 0, 1]:
		var q := Vector2(c, clampf(p.y, -1, 1))
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


## Move along the gate toward a target without cutting across it.
static func move_along(cur: Vector2, tgt: Vector2, dist: float) -> Vector2:
	for i in 4:
		if dist <= 0.0:
			break
		var wp := _next_waypoint(cur, tgt)
		var len := cur.distance_to(wp)
		if len <= dist:
			cur = wp
			dist -= len
			if cur.distance_squared_to(tgt) < 1e-6:
				return tgt
		else:
			return cur.move_toward(wp, dist)
	return cur


static func _next_waypoint(cur: Vector2, tgt: Vector2) -> Vector2:
	const E := 0.001
	if absf(cur.x - tgt.x) < E:
		return tgt                        # same column (or both on the neutral row)
	if absf(cur.y) > E:
		return Vector2(cur.x, 0)          # drop back to neutral first
	if absf(tgt.y) <= E:
		return tgt                        # slide along the neutral row
	return Vector2(tgt.x, 0)              # line up under the target column
