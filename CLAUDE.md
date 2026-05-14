# Langua 项目开发规则

## 版本号管理（必须执行）

每次修改代码后，**必须同步更新以下两个文件的版本号**，缺一不可：

- `langua-plugin/manifest.json` → `"version"` 字段
- `langua-darwin/build-dmg.sh` → `VERSION=` 变量

### 版本号规则（SemVer）

| 改动类型 | 版本变化 | 示例 |
|---------|---------|------|
| 新增功能（用户可感知） | MINOR +1，PATCH 归零 | 1.1.0 → 1.2.0 |
| Bug 修复、性能优化、UI 微调 | PATCH +1 | 1.1.0 → 1.1.1 |
| 重大重构或破坏性变更 | MAJOR +1，其余归零 | 1.1.0 → 2.0.0 |

### 判断示例

- 修复崩溃 → PATCH
- 修复显示 bug → PATCH
- 新增划词气泡功能 → MINOR
- 新增注音阈值配置 → MINOR
- 重写核心引擎 → MAJOR

## 项目结构

```
langua/
├── langua-plugin/      # Chrome 扩展
├── langua-darwin/      # macOS 原生应用（Swift）
├── packages/core/      # 跨平台共享核心（JS 字典、分词）
└── README.md
```

## 共享文件同步

`packages/core/` 下的文件是两端共享的，修改后需要同步：

```bash
bash langua-darwin/build-dmg.sh   # build 时会自动 sync
# 或手动
bash langua-darwin/setup.sh
```
