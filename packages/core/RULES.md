# langua core — 通用规则

## 字典结构

### pinyin-data.js
- 导出全局对象 `CHAR_DICT`：`{ 汉字: "pīnyīn" }`
- 覆盖最常用汉字（约 6,500 字）
- 带声调的完整拼音，如 `"中": "zhōng"`

### pinyin-ext.json
- 格式：JSON 数组，索引对应 Unicode 码位 `U+4E00` 开始的偏移
- `arr[i]` = `String.fromCharCode(0x4E00 + i)` 的拼音，空字符串或 null 表示无拼音
- 覆盖 U+4E00–U+9FFF 全量 CJK 字符（约 20,902 字）
- 加载方式：将 arr[i] 补充进 CHAR_DICT（不覆盖已有值，pinyin-data 优先）

### units-data.js
- 导出全局对象 `UNITS_DICT`：`{ 缩写/符号: "释义" }`

### segmenter.js
- 依赖 `CHAR_DICT`（需先加载 pinyin-data.js 和 pinyin-ext.json）
- 导出 `Segmenter.segment(text)` → `[{ word, pinyin[] }]`
- 多音字由分词上下文决定

## 拼音标注规则

### 显示阈值
- 连续 6 个以上 CJK 字符才在全文模式下显示拼音（避免标签/按钮干扰）
- 少于 6 个连续 CJK → 标记为 `hr-short`，全文模式下隐藏

### 多音字处理
- 依赖 segmenter.js 的分词结果，按词语上下文选择读音
- 单字无上下文时取第一个读音

### 字典优先级
1. `pinyin-data.js`（人工校对，精度高）
2. `pinyin-ext.json`（全量覆盖，自动生成）
3. segmenter 内部词典（多音字消歧）

## 文件依赖顺序
加载时必须按以下顺序：
1. `pinyin-data.js`   → 定义 CHAR_DICT
2. `pinyin-ext.json`  → 补全 CHAR_DICT
3. `units-data.js`    → 定义 UNITS_DICT
4. `segmenter.js`     → 依赖以上三个
