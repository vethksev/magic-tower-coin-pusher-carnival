# Phase 0b 3D 機台手感 Demo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將 Phase 0 嘅 2D 頂視機台換成真 3D 機台（Godot 3D + Jolt），保留同一組對外信號、同一套 demo 鍵位、同一套測試結構，出 v0.2.0 EXE 畀 owner 試手感。

**Architecture:** `game/machine/` 五個檔原地換成 3D 版：`MachineLayout`（3D 常數＋純函數）、`MachineTuning`、`Coin`（RigidBody3D 圓柱）、`Pusher`（AnimatableBody3D 長方體）、`Machine`（Node3D：平台、側牆、刮板、床幣、發幣、分區、靜止）。Demo 場景（Node3D）加 Camera3D、DirectionalLight3D、WorldEnvironment，HUD 放 CanvasLayer。3D 喺 640×360 viewport 渲染、整數放大 → 自動像素粒。

**Tech Stack:** Godot 4.7.1 standard，Jolt Physics（內建），gl_compatibility 3D。

## Global Constraints

- 同 Phase 0 plan；另加：`physics/3d/physics_engine="Jolt Physics"`、`physics/3d/default_gravity=400.0`（1 單位＝1 幣直徑≈2.4cm）。
- 機台幾何以 spec 1.6 為準：平台半闊 10、前緣 z=6、推板 20×1.2×8、行程 4、刮板前面 z=−4、邊坑段 z>3 平台半闊 9。
- 分支 `feat/phase0b-machine3d`。

## 檔案結構

| 檔 | 責任 |
|---|---|
| `project.godot` | 加 Jolt + 重力 400 |
| `game/machine/machine_layout.gd` | 3D 常數、`pusher_front_z()`、`classify(Vector3)`、`cycle_index()` |
| `game/machine/machine_tuning.gd/.tres` | 3D 手感參數 |
| `game/machine/coin.gd` | RigidBody3D 圓柱、滑行→落地、CylinderMesh 佔位 |
| `game/machine/pusher.gd` | AnimatableBody3D 正弦推板、BoxMesh |
| `game/machine/machine.gd` | Node3D：靜態幾何、床幣、發幣、分區、靜止、信號 |
| `game/demo/phase0_demo.gd` | Node3D demo：Camera3D／燈／環境／CanvasLayer HUD／鍵位 |
| `main.tscn` | root 改 Node3D |
| `tests/*.gd` | 五個測試改 3D；`tuning_sweep.gd` 參數改 3D |

## Tasks

### Task 1: Layout + Tuning（TDD）
- [ ] 改寫 `tests/machine_layout_tests.gd`（3D 斷言），跑確認 fail
- [ ] 寫 `machine_layout.gd`、`machine_tuning.gd`、`.tres`、`project.godot`
- [ ] import + 測試綠，commit

### Task 2: Coin + Pusher（TDD）
- [ ] 改寫 `tests/coin_pusher_tests.gd`（Vector3、CylinderShape3D、BoxShape3D），跑確認 fail
- [ ] 寫 `coin.gd`、`pusher.gd`
- [ ] import + 測試綠，commit

### Task 3: Machine（模擬測試）
- [ ] 改寫 `tests/machine_sim_tests.gd`（床幣 80–250、跌落 ≥ 3、跌落 > 流失、同 seed ±3、不同 seed 不同）
- [ ] 寫 `machine.gd`
- [ ] `--fixed-fps 60` 跑綠；用 `tests/tuning_sweep.gd` 掃床幣間距／摩擦／行程，commit

### Task 4: Demo + smoke + capture
- [ ] `phase0_demo.gd` 改 Node3D + Camera + 燈 + CanvasLayer HUD；`main.tscn` root Node3D
- [ ] `tests/smoke.gd` 用 `find_child("Hud", true, false)`；`tests/demo_capture.gd` 不變
- [ ] smoke 綠、截圖目視（要見到立體幣堆、推板、前緣、HUD 喺右）
- [ ] commit

### Task 5: 打包 v0.2.0 + 文件 + PR
- [ ] `tools/build.ps1 -Version 0.2.0`，EXE 開 4 秒
- [ ] AGENTS.md 進度、README 版本、spec 數值同步
- [ ] PR → squash merge → Release `v0.2.0-phase0b` 掛 ZIP

## 已知風險
- Jolt 對幾百個圓柱嘅堆疊穩定性未知；唔穩就改 `coin_thickness` 0.16 或改用 `ConvexPolygonShape3D`（八角柱）。
- 刮板／推板頂面落幣時機：推板後退時頂面全部喺刮板下面，發幣會直接跌落下層平台——屬正常。
- 跨 run 物理不確定（同 2D），測試只要求相近。
