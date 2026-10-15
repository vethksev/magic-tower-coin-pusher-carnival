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

### 2026-10-16

- 開 repo、寫設計規格 v1（Phase 0 + 1）、`CONTRIBUTING.md`、`docs/ART_GUIDE.md`。等 owner 審閱 spec，之後 Claude 出 implementation plan 並開始 Phase 0。
- 未做：任何程式、任何素材。
