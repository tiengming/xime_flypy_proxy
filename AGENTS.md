# AGENTS.md（xime_theme_pack 分支）

本分支只放「xime 主题包」的交付产物：`xime.custom.yaml` / `themes/` / `fonts/` /
`README.md` / `NOTICE.md` / `VERSION`。仓库级规则（分支模型、发版流程、xime-index
上架规范、配色字段语义）以 `main` 分支为准，动手前先读：

```bash
git show main:AGENTS.md
```

分支内改动自查（对比度脚本在 main）：

```bash
git show main:tools/check_colors.py > "$TEMP/check_colors.py"
python "$TEMP/check_colors.py" xime.custom.yaml
```

- 改动后递增 `VERSION`，否则 CI 判定内容有变但版本未递增而跳过打包。
- 截图 URL 固定到 tag，不要用分支名。
- **不主动 push、不主动建 PR**，需用户明确同意。
