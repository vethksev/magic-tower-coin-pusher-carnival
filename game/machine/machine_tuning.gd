class_name MachineTuning
extends Resource
## 所有手感參數。調手感改 .tres，唔改 code。

@export_group("Pusher")
@export var pusher_period: float = 2.4
@export var pusher_stroke: float = 36.0
@export var pusher_thickness: float = 24.0
@export var pusher_rest_y: float = 40.0

@export_group("Coin physics")
@export var linear_damp: float = 3.0
@export var friction: float = 0.6
@export var bounce: float = 0.1
@export var coin_radius: float = 7.0

@export_group("Firing")
## 幣沿推板前條帶橫向滑行嘅速度（像素／秒），撞到幣或對面牆先落地
@export var fire_speed: float = 300.0
## 落地後保留嘅向前速度
@export var fire_forward_speed: float = 30.0
@export var fire_cooldown: float = 0.25
## 落點 y 隨機抖動（像素），令每局唔同
@export var fire_jitter: float = 2.0
@export var clip_size: int = 20

@export_group("Settle")
## 彈匣空後，連續幾多個推板週期無幣跌落／流失就算靜止（停滯）
@export var settle_cycles: int = 2

@export_group("Bed")
## 六角密鋪：相鄰幣中心距；行距 = spacing × 0.866
@export var bed_spacing: float = 14.2
## 第一行 y；行距 12.3 × 15 行 → 最後一行 273，邊緣剛貼跌落線 280
@export var bed_start_y: float = 88.5
@export var bed_end_y: float = 274.0
@export var bed_x_start: float = 25.0
@export var bed_x_end: float = 375.0
@export var bed_jitter: float = 0.0
