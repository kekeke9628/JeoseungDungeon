class_name FloorTheme
## Depth bands: a name and a tile tint per group of floors.

const BAND_SIZE: int = 5
const NAMES: Array[String] = ["저승길", "황천강", "지옥문", "염라전"]
const TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.72, 0.9, 1.2),
	Color(1.25, 0.78, 0.78),
	Color(1.2, 1.05, 0.72),
]

static func band(floor_num: int) -> int:
	return clampi((floor_num - 1) / BAND_SIZE, 0, NAMES.size() - 1)

static func band_name(floor_num: int) -> String:
	return NAMES[band(floor_num)]

static func tint(floor_num: int) -> Color:
	return TINTS[band(floor_num)]
