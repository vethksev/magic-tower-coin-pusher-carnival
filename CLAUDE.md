# 魔塔推幣機 — Claude 入口

@AGENTS.md

補充（只對 Claude）：

- 同 owner 以廣東話溝通，重點講結果；owner 想直接做完可驗證嘅改動，少問重複確認。
- 每次 git 操作前先 `git branch --show-current`；Codex 可能喺同一目錄切咗 branch。
- 程式分支 `feat/<topic>`，merge 前全部測試 `-- --qa` 綠 + smoke 截圖。
- deploy／打包用 `tools/build.ps1`，EXE 唔入 git。
