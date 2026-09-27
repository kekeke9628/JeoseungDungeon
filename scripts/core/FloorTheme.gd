class_name FloorTheme
## Depth bands: a name and a tile set (TileAtlas.BANDS) per group of floors.

const BAND_SIZE: int = 5
const NAMES: Array[String] = ["저승길", "황천강", "지옥문", "염라전"]

static func band(floor_num: int) -> int:
	return clampi((floor_num - 1) / BAND_SIZE, 0, NAMES.size() - 1)

static func band_name(floor_num: int) -> String:
	return NAMES[band(floor_num)]
