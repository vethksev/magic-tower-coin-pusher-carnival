# 魔塔推幣機 — AI 協作交接（Claude / Codex 共用）

更新：2026-10-16（香港時間）

## 先讀

1. 設計規格：`docs/superpowers/specs/2026-10-16-magic-tower-coin-pusher-design.md`（玩法、數值、架構、測試、分期）
2. 協作流程：`CONTRIBUTING.md`
3. 美術規格：`docs/ART_GUIDE.md`

## 分工（owner 已定）

| 角色 | 負責 | 碰邊啲檔 |
|---|---|---|
| **Claude** | 設計、實作計劃、程式、測試、打包 | `game/`、`tests/`、`tools/`、`project.godot`、`main.*`、`docs/superpowers/` |
| **Codex** | 美術（像素圖、音效）、交件 QA、registry 註冊 | `assets/`、`docs/ART_GUIDE.md`（補充實例） |
| **Owner** | 美術確認、試玩驗收、玩法大方向 | — |

- 程式唔碰 `assets/` 入面嘅真圖；美術唔碰 `game/`。要跨界就喺 PR 講明，由另一方接手。
- 美術接入遊戲一律經 registry JSON（`assets/**/*.json`），程式只讀 registry，唔 hardcode 圖檔路徑。

## 環境

- Godot 4.7.1 standard：`D:/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe`（唔用 Mono）
- 專案：`D:/magic-tower-coin-pusher-carnival`
- 測試一律加 `-- --qa`：

```powershell
$Godot = 'D:/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe'
$Root  = 'D:/magic-tower-coin-pusher-carnival'
& $Godot --editor --path $Root                                   # 開編輯器
& $Godot --headless --path $Root --editor --import               # 匯入新素材
& $Godot --headless --path $Root --script res://tests/combat_tests.gd -- --qa
```

## 每項完成後更新本檔

每完成一項功能、修正、素材或環境變更，即時更新下方「進度」段：完成內容、相關檔案、驗證方法與結果、未完成項。唔好等整輪先補。

## 進度

### 2026-10-16 Phase 0b 3D 機台手感 demo ✅（分支 feat/phase0b-machine3d，v0.2.0）

- Owner 試完 2D 頂視版：「2D 體驗感極差，推幣機 3D，魔塔部分 2D」。即日改做真 3D（Godot 3D + Jolt），`game/machine/` 五檔原地換成 3D 版，對外信號不變。
- 結構：下層平台、側牆、後牆、固定刮板（前面 z=−3）、推板（20×1.2×8，行程 6）、床幣六角密鋪＋前段（z≥2.5）第二層、發幣喺推板頂面橫滑直至被阻。詳見 spec 1.6。
- Demo：Node3D + Camera3D (0,28,23)→(0,0,−1) fov 30 h_offset 5、DirectionalLight、WorldEnvironment、CanvasLayer HUD；鍵位同 Phase 0（`- =` 改為調摩擦）。
- 驗證：machine_layout 27／coin_pusher 27／machine_sim 14／smoke 11 全過；`.godot/qa/phase0.png` 見整部機；EXE `windows-v0.2.0/MagicTowerCoinPusher.exe`、ZIP `D:\MagicTowerCoinPusher-Windows-v0.2.0.zip`。
- 實測教訓：行程 4 ＋摩擦 0.35 ＋一層床 → 零跌落（幣寧願爬上鄰幣都唔推前排）；要行程 6、摩擦 0.2、前段兩層、前排貼前緣先有 20 枚跌 3–13。邊坑段由 z=3 起會流失 > 跌落，縮到 z>5。刮板前面同推板後退位齊會令頂面幣卡喺邊緣，前移 1 單位解決。
- Jolt 跨 run 唔確定：同 seed 跌落數可以 13 vs 1，測試只驗「有跌落」；平衡要用多 run 平均。
- 偶發：一枚幣卡喺推板頂面近牆位（seed 8），未修。
- 下一步：owner 試 3D 手感 → 定數值 → Phase 1 plan。

### 2026-10-16 Phase 0 2D 機台手感 demo（已棄用，分支 feat/phase0-machine，v0.1.0）

- 完成：`game/machine/`（MachineLayout／MachineTuning／Coin／Pusher／Machine）、`game/demo/phase0_demo.gd`、五個測試腳本、`tools/build.ps1`、`tools/install_export_templates.ps1`、`export_presets.cfg`。EXE `windows-v0.1.0/MagicTowerCoinPusher.exe`（110 MB），ZIP `D:\MagicTowerCoinPusher-Windows-v0.1.0.zip`。
- 驗證：machine_layout 27／coin_pusher 26／machine_sim 13／smoke 10 checks 全過；`tests/demo_capture.gd` 截圖 `.godot/qa/phase0.png` 目視正常；EXE 開 4 秒無 crash。
- 操作：A／D／Space 發幣，R 補幣，N 新 seed，`[ ]` 推板週期、`; '` 行程、`- =` 摩擦、`, .` 滑速，F1 收起 HUD。
- **實作同 spec 第 1 節嘅差異（已反映入 spec）**：
  1. 床幣用六角密鋪（中心距 14.2、行距 12.3、約 410 枚），後台行鋪到牆邊、前台行只鋪到邊坑線。稀疏方格床會吸收晒推力，零跌落。
  2. 發幣改為 RACCOIN 式「橫向滑行直至撞幣／撞牆先落地」，滑行中 y 貼住推板前沿；唔係固定 0.3 秒飛行。
  3. 邊坑只喺最前 50 像素（y 230–280），唔係成個前台；否則流失比跌落仲多。
  4. 靜止判定改為「彈匣空後連續 2 個推板週期無幣跌落／流失」，唔用速度閾值（等待行每週期都被推板推動，永遠唔會速度為零）。
  5. 唔用 CCD（`continuous_cd`）：400 枚相貼幣開 CCD 會爆炸飛走。
- 已知待調：幾百枚幣受壓時左右牆有 ~7px 穿透（solver_iterations 已加到 32 仍有）；20 枚約跌 18–25、流失 2–3，比例由 owner 試完再定。
- 掃參數用 `tests/tuning_sweep.gd`（`--fixed-fps 60` 一秒跑 20 秒模擬），例：`--bed-spacing=14.2 --stroke=36 --fire=40 --ticks=1800`。
- Godot 物理跨 run 唔逐位元確定（同 seed 跌落數 ±1），測試只要求 ±3；床幣初始位置同 seed 完全可重現。
- 下一步：owner 試手感 → 寫入 `machine_tuning.tres` → Phase 1 plan（魔塔數值、幣效果、商店、UI 流程）。
