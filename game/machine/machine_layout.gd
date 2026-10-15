class_name MachineLayout
extends RefCounted
## 機台幾何常數同純函數。唔持有狀態，所有嘢 static。
## 座標：機台左上角 (0,0)，x 向右，y 向前（向玩家／塔門）。

const WIDTH: float = 400.0
const HEIGHT: float = 300.0
const BEZEL_Y: float = 40.0          # 推板完全收回時嘅前沿 y
const FRONT_START_Y: float = 150.0   # 後台結束、前台（有邊坑）開始
const DROP_Y: float = 280.0          # 前緣：幣中心過呢條線即跌入塔門
const GUTTER_W: float = 18.0         # 前台左右邊坑闊度
const CHUTE_LEFT: Vector2 = Vector2(30.0, 48.0)
const CHUTE_RIGHT: Vector2 = Vector2(370.0, 48.0)

enum Zone { BOARD, SCORED, LOST_LEFT, LOST_RIGHT }


static func pusher_front_y(time: float, period: float, stroke: float, rest_y: float) -> float:
	if period <= 0.0:
		return rest_y
	var phase: float = fmod(time, period) / period
	return rest_y + stroke * (0.5 - 0.5 * cos(TAU * phase))


static func classify(pos: Vector2) -> Zone:
	if pos.y >= DROP_Y:
		return Zone.SCORED
	if pos.y >= FRONT_START_Y:
		if pos.x < GUTTER_W:
			return Zone.LOST_LEFT
		if pos.x > WIDTH - GUTTER_W:
			return Zone.LOST_RIGHT
	return Zone.BOARD


static func cycle_index(time: float, period: float) -> int:
	if period <= 0.0:
		return 0
	return int(floor(time / period))
