extends Resource

@export var stops: PackedVector2Array
@export var starting_stop := 0
@export var pitch_radius := 22.0


func is_valid(bounds: Rect2) -> bool:
	if stops.size() < 2 or starting_stop not in range(stops.size()):
		return false
	if not is_finite(pitch_radius) or pitch_radius < 8.0:
		return false
	for point: Vector2 in stops:
		if not bounds.has_point(point):
			return false
	var axis := stops[stops.size() - 1] - stops[0]
	var length := axis.length()
	if not is_finite(length) or length < 8.0:
		return false
	var dir := axis / length
	var prev_t := -1.0
	for index: int in range(stops.size()):
		var offset := stops[index] - stops[0]
		if absf(offset.cross(dir)) > 2.5:
			return false
		var t := offset.dot(dir)
		if index > 0 and t <= prev_t:
			return false
		prev_t = t
	return true


func position_at(stop_value: float) -> Vector2:
	if stops.is_empty():
		return Vector2.ZERO
	if stops.size() == 1:
		return stops[0]
	var clamped := clampf(stop_value, 0.0, float(stops.size() - 1))
	var low := clampi(int(floorf(clamped)), 0, stops.size() - 1)
	var high := mini(low + 1, stops.size() - 1)
	return stops[low].lerp(stops[high], clamped - float(low))


func project_to_stop_value(plate_point: Vector2) -> float:
	if stops.size() < 2:
		return 0.0
	var axis := stops[stops.size() - 1] - stops[0]
	var length := axis.length()
	if length <= 0.001:
		return 0.0
	var dir := axis / length
	var proj := (plate_point - stops[0]).dot(dir)
	if proj <= 0.0:
		return 0.0
	for index: int in range(stops.size() - 1):
		var t0 := (stops[index] - stops[0]).dot(dir)
		var t1 := (stops[index + 1] - stops[0]).dot(dir)
		if proj <= t1 or index == stops.size() - 2:
			var span := maxf(t1 - t0, 0.001)
			return clampf(float(index) + (proj - t0) / span, 0.0, float(stops.size() - 1))
	return float(stops.size() - 1)


func nearest_stop(stop_value: float) -> int:
	if stops.is_empty():
		return 0
	return clampi(roundi(stop_value), 0, stops.size() - 1)
