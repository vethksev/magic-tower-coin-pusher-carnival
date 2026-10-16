class_name MachineTuning
extends Resource
## 所有手感參數（3D 版）。調手感改 .tres，唔改 code。單位：1 = 一枚幣直徑。

@export_group("Pusher")
@export var pusher_period: float = 2.4
@export var pusher_stroke: float = 6.0

@export_group("Coin physics")
@export var friction: float = 0.2
## 彈性：落地會彈開（0 = 唔彈）
@export var bounce: float = 0.25
@export var coin_radius: float = 0.5
@export var coin_thickness: float = 0.12
@export var coin_mass: float = 1.0

@export_group("Firing")
## 側槽初速（單位／秒）
@export var fire_speed: float = 22.0
## 側槽射出角度（度，向下為正）
@export var fire_angle_deg: float = 20.0
## 上方槽落下初速（向下）
@export var top_drop_speed: float = 3.0
## 上方槽少量向前初速
@export var top_forward_speed: float = 1.5
## 幣射出時嘅傾角範圍（度）：0 = 平放，90 = 企直滾動；每枚隨機
@export var fire_tilt_min_deg: float = 55.0
@export var fire_tilt_max_deg: float = 90.0
## 自轉角速度（弧度／秒）隨機上限
@export var fire_spin: float = 12.0
## 初速隨機倍率範圍
@export var fire_speed_jitter: float = 0.12
## 水平偏航隨機（度）
@export var fire_yaw_jitter_deg: float = 6.0
@export var fire_cooldown: float = 0.25
@export var clip_size: int = 20

@export_group("Settle")
## 彈匣空後，連續幾多個推板週期無幣跌落／流失就算靜止（停滯）
@export var settle_cycles: int = 2

@export_group("Bed")
## 六角密鋪：相鄰幣中心距；行距 = spacing × 0.866
@export var bed_spacing: float = 1.02
## 床幣由推板最前位置 + 呢個距離開始
@export var bed_z_gap: float = 0.02
@export var bed_z_end: float = 5.6
@export var bed_x_half: float = 8.9
@export var bed_jitter: float = 0.0
## 由呢個 z 起（向前）床幣鋪第二層；真機前段有 2–3 層幣先會「入一枚跌一枚」。設 99 = 唔鋪
@export var bed_layer2_from_z: float = 2.5
