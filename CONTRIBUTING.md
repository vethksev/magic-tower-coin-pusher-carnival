# 一齊開發《魔塔推幣機》

Claude（程式）、Codex（美術）同 owner 靠同一個 GitHub repo 同步：
https://github.com/vethksev/magic-tower-coin-pusher-carnival

三方共用 `vethksev` GitHub 帳號，所以**每個 agent 一定要設定自己嘅 git 名**，分得出邊個改咗乜：

```powershell
git config user.name  "vethksev (Claude)"   # 或 "vethksev (Codex)"
git config user.email "vethksev@gmail.com"
```

## 第一次設定

1. Git for Windows（已包 Git LFS）＋ GitHub CLI，`gh auth login` 用 vethksev。
2. Godot 4.7.1 **standard**（唔好用 .NET／Mono）：`D:/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe`。打包另需同版本 Windows export templates。
3. `git lfs install`，然後 `gh repo clone vethksev/magic-tower-coin-pusher-carnival D:\magic-tower-coin-pusher-carnival`。
4. Godot 專案管理器匯入 `project.godot`（`.godot/` 唔上 git）。

## 每日流程

```powershell
git switch main; git pull
git switch -c feat/<topic>        # Claude 程式
git switch -c art/<item>          # Codex 美術，一件一分支
# ……改、試、跑測試（Claude：全部 -- --qa 綠；Codex：ART_GUIDE QA 全過）
git add -A; git commit -m "一句講清楚做咗乜"
git push -u origin HEAD
gh pr create --fill
```

Merge 規則：
- `feat/*`：測試全綠 + smoke 截圖附喺 PR，Claude 自己 merge；涉及玩法方向改動先問 owner。
- `art/*`：Codex 開 PR 附並排預覽圖；**owner 確認後**先 merge（Codex 或 Claude 按 owner 指示執行）。
- 唔直接 push `main`。

## 檔案責任（避免互相冚）

| 路徑 | 負責 |
|---|---|
| `game/`、`tests/`、`tools/`、`project.godot`、`main.*` | Claude |
| `assets/`（圖、音、registry JSON）、`docs/ART_GUIDE.md` 實例 | Codex |
| `AGENTS.md` 進度段 | 誰做完誰更新自己段落 |
| `docs/superpowers/` | Claude |

- 美術接入靠 registry JSON（例如 `assets/coins/coins.json` 記每款幣嘅圖檔路徑、幀數、pivot）。程式讀 registry，唔 hardcode 路徑；美術未到就用佔位圖。
- 打包出嚟嘅 `windows-v*/`、`*.zip`、`*.exe` 唔上 git；試玩版開 GitHub Release 或傳 ZIP。
- `.png / .wav / .ogg / .ttf / .otf` 自動行 LFS。
- 有 conflict 唔好亂揀，叫另一方睇。
