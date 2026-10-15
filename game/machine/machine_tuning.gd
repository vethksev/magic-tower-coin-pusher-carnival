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
@export var fire_speed: float = 180.0
@export var fire_forward_speed: float = 40.0
@export var fire_jitter_deg: float = 6.0
@export var fire_cooldown: float = 0.25
@export var fire_flight_time: float = 0.3
@export var clip_size: int = 20

@export_group("Settle")
@export var settle_speed: float = 4.0
@export var settle_seconds: float = 2.0

@export_group("Bed")
@export var bed_start_y: float = 90.0
@export var bed_end_y: float = 270.0
@export var bed_spacing: float = 17.0
@export var bed_x_start: float = 30.0
@export var bed_x_end: float = 370.0
@export var bed_jitter: float = 1.0
