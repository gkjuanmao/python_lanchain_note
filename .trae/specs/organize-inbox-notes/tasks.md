# Tasks

- [x] Task 1: 拆分 inbox 长文并归档到 `20-areas/django/orm/`（4 个子任务互相独立，可并行）
  - [x] SubTask 1.1: 新建 `2026-09-19-Django-ORM的F对象与Q对象.md`，取源文件 `00-inbox/2026-09-19.md` 第 1–730 行
    - H1 用 `# Django-ORM的F对象与Q对象`，原 H1「Django ORM 中的 F 对象和 Q 对象」降为 H2，其余标题整体 +1 级
    - frontmatter：`tags: [python, django, orm, 条件查询, 查询优化]`；description 说明 F 对象（字段引用、原子更新、计数器）、Q 对象（OR/NOT、动态查询）与二者结合
    - 加 wikilink：F 原子更新处链到 `[[2026-09-18-Django-ORM更新数据]]`、Q 组合条件处链到 `[[2026-09-18-Django-ORM模糊查询]]`、基础查询处链到 `[[2026-09-18-Django-ORM查询数据]]`
    - 文末加 `## 参考信息`，列 3–4 条关联笔记与原因
  - [x] SubTask 1.2: 新建 `2026-09-19-Django-ORM排序.md`，取源第 732–1211 行
    - H1 用 `# Django-ORM排序`，原 H1「Django ORM 中的 `order_by()`」降为 H2，其余标题整体 +1 级
    - frontmatter：`tags: [python, django, orm, 排序, 性能优化]`
    - 加 wikilink：表达式排序处链到 `[[2026-09-19-Django-ORM的F对象与Q对象]]`，`Meta.ordering` 处链到 `[[2026-09-18-Django模型与数据库配置]]`，聚合排序处链到 `[[2026-09-19-Django-ORM聚合与分组]]`
    - 文末加 `## 参考信息`
  - [x] SubTask 1.3: 新建 `2026-09-19-Django-ORM惰性执行与缓存.md`，取源第 1213–1465 行
    - H1 用 `# Django-ORM惰性执行与缓存`，原 H1「QuerySet 的两大核心特性」降为 H2，其余标题整体 +1 级（含原文 H4 级小节降为 H5）
    - frontmatter：`tags: [python, django, orm, 查询优化, 缓存]`
    - 加 wikilink：惰性处链到 `[[2026-09-18-Django-ORM查询数据]]`，聚合相关处链到 `[[2026-09-19-Django-ORM聚合与分组]]`
    - 文末加 `## 参考信息`
  - [x] SubTask 1.4: 新建 `2026-09-19-Django-ORM聚合与分组.md`，取源第 1468–2193 行
    - H1 用 `# Django-ORM聚合与分组`，原 H1「Django ORM 聚合与分组详解」降为 H2，其余标题整体 +1 级
    - frontmatter：`tags: [python, django, orm, 聚合, 分组]`
    - 加 wikilink：条件聚合 `filter=Q(...)` 处链到 `[[2026-09-19-Django-ORM的F对象与Q对象]]`，分组后排序处链到 `[[2026-09-19-Django-ORM排序]]`，`Count` 跨表处链到 `[[2026-09-18-Django-ORM查询数据]]`
    - 文末加 `## 参考信息`

- [x] Task 2: 更新既有笔记的索引与反向链接（依赖 Task 1）
  - [x] SubTask 2.1: 更新 `20-areas/django/2026-09-18-Django知识地图.md` 第五节「数据库与 ORM」为 10 篇，按学习路径插入 4 条新笔记条目；文件开头 description 的篇数由 20 改为 24
  - [x] SubTask 2.2: 在 `20-areas/django/orm/` 下 5 篇既有 ORM 笔记的 `## 参考信息` 末尾各补 1–2 条指向相关新笔记的条目
  - [x] SubTask 2.3: 补 2 处内联 wikilink：`2026-09-18-Django-ORM更新数据.md`「解决方案二：`F()` 表达式（推荐）」、`2026-09-18-Django-ORM模糊查询.md`「十、`Q` 对象组合复杂条件」，均指向 `[[2026-09-19-Django-ORM的F对象与Q对象]]`

- [x] Task 3: 全库校验并清空 inbox（依赖 Task 1、Task 2）
  - [x] SubTask 3.1: 逐项校验：wikilink 目标文件全部存在；本次涉及文件的锚点均存在；4 篇新笔记 frontmatter 齐全；4 篇新笔记均被知识地图引用；无孤立笔记
  - [x] SubTask 3.2: 内容无损核对：4 篇新笔记重建比对差异均为 0 行；代码围栏数量（94/64/28/102）与表格分隔行数量（各 4）与源一致
  - [x] SubTask 3.3: 校验通过后删除 `00-inbox/2026-09-19.md`；`00-inbox/` 现为空目录

# Task Dependencies

- Task 2 依赖 Task 1（需先有目标笔记才能建链接）
- Task 3 依赖 Task 1、Task 2
- Task 1 的 SubTask 1.1–1.4 之间无依赖，可并行

# 遗留问题（超出本 spec 范围，未处理）

- `20-areas/python/2026-09-10-Python基础知识.md` 第 520 行存在历史失效锚点 `[[2026-09-10-Python常用代码示例合集#__new__()]]`，目标笔记实际标题为「### 重写__new__()方法」。该文件不在本次改动清单内，属于历史遗留，建议后续单独整理时修正。
