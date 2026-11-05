extends RefCounted
## One place the car reads input from. Touch controls, keyboard and gamepad all write here.

var steer := 0.0       ## -1 left .. 1 right
var handbrake := 0.0   ## 0..1
var gear := 0          ## -1 R, 0 N, 1..5
