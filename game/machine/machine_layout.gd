class_name MachineLayout
extends RefCounted
## 3D 機台幾何常數同純函數。唔持有狀態，所有嘢 static。
## 單位：1 = 一枚幣直徑。座標：x 左右（右為正）、y 上、z 向前（向玩家／塔門為正）。

const HALF_WIDTH: float = 10.0          # 平台半闊（側牆內面）
const FRONT_EDGE_Z: float = 6.0         # 前緣：過咗就跌入塔門
const PLATFORM_BACK_Z: float = -12.0    # 平台最後
const PUSHER_DEPTH: float = 8.0
const PUSHER_HEIGHT: float = 1.2        # 推板頂面 = 上層架
const PUSHER_REST_FRONT_Z: float = -4.0 # 推板完全後退時前面 z
const WIPER_FRONT_Z: float = -3.0       # 固定刮板前面 z（比推板後退位前 1 單位，令頂面嘅幣被完整掃落）
const GUTTER_START_Z: float = 5.0       # 由此向前（最前 1 單位），平台收窄，兩側係邊坑
const GUTTER_HALF_WIDTH: float = 9.3    # 邊坑段平台半闊
const DROP_Y: float = -1.0              # 幣中心低過呢個高度＝已離開平台
const SCORE_MIN_Z: float = 5.0          # 離開平台時 z ≥ 呢個＝前緣跌落（計分），否則係邊坑
const CHUTE_Z: float = -2.0             # 發幣槽喺推板頂面嘅 z

enum Zone { BOARD, SCORED, LOST_LEFT, LOST_RIGHT }


static func pusher_front_z(time: float, period: float, stroke: float, rest_z: float) -> float:
	if period <= 0.0:
		return rest_z
	var phase: float = fmod(time, period) / period
	return rest_z + stroke * (0.5 - 0.5 * cos(TAU * phase))


static func classify(pos: Vector3) -> Zone:
	if pos.y >= DROP_Y:
		return Zone.BOARD
	if pos.z >= SCORE_MIN_Z:
		return Zone.SCORED
	return Zone.LOST_LEFT if pos.x < 0.0 else Zone.LOST_RIGHT


static func cycle_index(time: float, period: float) -> int:
	if period <= 0.0:
		return 0
	return int(floor(time / period))
