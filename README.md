# 魔塔推幣機 · Magic Tower Coin Pusher Carnival

推幣機物理 × 魔塔數值嘅肉鴿遊戲。Godot 4.7.1 standard / GDScript，Windows，目標 Steam。

- 設計規格：[docs/superpowers/specs/2026-10-16-magic-tower-coin-pusher-design.md](docs/superpowers/specs/2026-10-16-magic-tower-coin-pusher-design.md)
- AI 協作交接（Claude / Codex）：[AGENTS.md](AGENTS.md)
- 開發與 Git 流程：[CONTRIBUTING.md](CONTRIBUTING.md)
- 美術交件：[docs/ART_GUIDE.md](docs/ART_GUIDE.md)

圖片、音效、字體行 Git LFS。唔提交 `.godot/`、EXE／ZIP。

## Phase 0c 3D 手感 demo（v0.3.0）

解壓 ZIP 開 `MagicTowerCoinPusher.exe`。A／D 左右槽、Space 雙槽、W 或滑鼠左鍵上方落幣（滑鼠移動／←→ 瞄準）、R 補 20 幣、N 新 seed。
`[` `]` 推板週期、`;` `'` 行程、`-` `=` 摩擦、`9` `0` 彈性、`,` `.` 側槽初速，F1 收起面板。
試完請話我知邊組數字手感最好。

打包：`powershell -ExecutionPolicy Bypass -File tools\build.ps1 -Version 0.3.0`（第一次先跑 `tools\install_export_templates.ps1`）。
