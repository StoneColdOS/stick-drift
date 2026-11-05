extends RefCounted
## 5-speed H-pattern box with ratios close to an old-school Toyota (AE86-ish).
## Gears: -1 = reverse, 0 = neutral, 1..5 forward.

const REVERSE := -1
const NEUTRAL := 0
const TOP := 5
const REVERSE_RATIO := 3.484
const FORWARD := [3.587, 2.022, 1.384, 1.000, 0.72]  ## 5th is a tall overdrive for the highway


static func ratio(gear: int) -> float:
	if gear == REVERSE:
		return -REVERSE_RATIO
	if gear == NEUTRAL:
		return 0.0
	return FORWARD[clampi(gear, 1, TOP) - 1]


static func label(gear: int) -> String:
	if gear == REVERSE:
		return "R"
	if gear == NEUTRAL:
		return "N"
	return str(gear)
