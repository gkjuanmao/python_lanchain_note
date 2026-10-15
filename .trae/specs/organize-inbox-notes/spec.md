# 整理 00-inbox 笔记 Spec

## Why

`00-inbox/2026-09-19.md` 是一份 2193 行的混合长文，包含 4 个互相独立的 Django ORM 主题，缺少 frontmatter、没有 wikilink、也未归入技术目录，无法按主题检索，也不符合 skill `obsidian-organizer` 的目录、命名、元数据与链接规范。

## What Changes

- 按主题拆分为 4 篇笔记，归档到 `20-areas/django/orm/`（该目录现有 6 篇，拆分后 10 篇，未超过 15 篇的分层阈值）：

  | 新笔记文件名 | 源行范围 | 主题 |
  |---|---|---|
  | `2026-09-19-Django-ORM的F对象与Q对象.md` | 1–730 | F 对象与 Q 对象 |
  | `2026-09-19-Django-ORM排序.md` | 732–1211 | `order_by()` |
  | `2026-09-19-Django-ORM惰性执行与缓存.md` | 1213–1465 | QuerySet 惰性执行与缓存 |
  | `2026-09-19-Django-ORM聚合与分组.md` | 1468–2193 | `aggregate()` / `annotate()` |

- 每篇补齐 YAML frontmatter（`tags` + `description`），标题层级统一为：新 H1 = 文件名的描述，原文档内所有标题层级整体 +1（原 H1 → H2，`一、` → `###`，`1.` → `####`），只调层级不改标题文字。
- 正文内容不改写、不删减，只做层级调整、加 wikilink、加 `## 参考信息`。
- 4 篇新笔记中添加指向既有 ORM 笔记的 `[[wikilinks]]`（含小节锚点）。
- 更新 Django 领域索引笔记 [2026-09-18-Django知识地图.md](file:///d:/Note/Python/20-areas/django/2026-09-18-Django知识地图.md) 第五节「数据库与 ORM」，由 6 篇改为 10 篇，按学习路径插入 4 条新条目。
- 在既有 5 篇 ORM 笔记（查询数据 / 新增数据 / 更新数据 / 删除数据 / 模糊查询）的 `## 参考信息` 中补充指向新笔记的关联条目，并在概念对应的小节补 1 处内联 wikilink（共 2 处：更新数据的 `F()` 表达式小节、模糊查询的 `Q` 对象小节）。
- 删除已清空的 `00-inbox/2026-09-19.md`（**BREAKING**：源文件移除，内容已全部迁移）。

已确认的决策：拆分粒度 4 篇、日期前缀 `2026-09-19`、校验通过后删除 inbox 源文件、同时改动既有笔记与索引笔记。

## Impact

- Affected specs: obsidian-organizer — 目录与命名、元数据、标题层级、长文拆分、链接与引用、执行与校验
- Affected code（笔记库文件）：
  - 新增 4 个 md：`20-areas/django/orm/2026-09-19-*.md`
  - 修改 6 个 md：`20-areas/django/2026-09-18-Django知识地图.md`、`20-areas/django/orm/` 下 5 篇既有 ORM 笔记
  - 删除 1 个 md：`00-inbox/2026-09-19.md`
- 不涉及 git 提交（是否提交由用户另行决定）

## ADDED Requirements

### Requirement: inbox 素材按主题拆分归档

笔记库 SHALL 将 `00-inbox/` 中的素材按主题拆分为独立笔记并归入对应领域目录，拆分后正文不得丢失任何原内容。

#### Scenario: 拆分多主题长文
- **WHEN** inbox 文件包含多个互相独立的主题
- **THEN** 每个主题生成一篇 `YYYY-MM-DD-简短描述.md`，放在该技术主题目录下，文件名不含括号与空格
- **AND** 每篇 H1 与文件名的描述一致，原文所有标题层级整体下移一级，标题文字不修改

#### Scenario: 内容完整性
- **WHEN** 4 篇新笔记写完后
- **THEN** 逐段核对源行范围，除 frontmatter 与新增的 `## 参考信息` 外，正文无缺失、无改写

### Requirement: 新笔记符合 skill 规范

每篇新笔记 SHALL 在文件开头包含 `tags` 与 `description` 两个 frontmatter 字段，并在文末提供唯一的 `## 参考信息` 章节。

#### Scenario: 元数据与标签
- **WHEN** 生成新笔记
- **THEN** `tags` 为 2–5 个，技术专名小写英文（`python`、`django`、`orm`），概念用中文（`排序`、`聚合`、`查询优化`），首个标签为主题技术
- **AND** `description` 为一句中文，说明「讲什么 + 覆盖哪些内容」，不以「本文」开头，不重复标题

#### Scenario: 参考信息格式
- **WHEN** 每篇写完后
- **THEN** 文末 `## 参考信息` 采用 `- [[笔记名]] — 关联原因` 格式，记录隐含联系（上下游、共用概念、替代方案），不只罗列同目录笔记

### Requirement: 链接与索引闭环

新笔记 SHALL 通过 `[[wikilinks]]` 与既有笔记双向关联，并出现在领域索引笔记中，整理后库内不得出现无人引用的孤立笔记。

#### Scenario: 链接可解析
- **WHEN** 整理完成
- **THEN** 所有 `[[wikilink]]` 目标文件存在；带锚点的链接，锚点在目标笔记中确实存在（锚点文字去掉转义反斜杠）

#### Scenario: 索引笔记覆盖新笔记
- **WHEN** 更新领域索引
- **THEN** 4 篇新笔记均出现在 [2026-09-18-Django知识地图.md](file:///d:/Note/Python/20-areas/django/2026-09-18-Django知识地图.md) 的 ORM 章节，每条附一句话说明

## MODIFIED Requirements

### Requirement: Django 领域知识地图

索引笔记 [2026-09-18-Django知识地图.md](file:///d:/Note/Python/20-areas/django/2026-09-18-Django知识地图.md) 第五节「数据库与 ORM」的篇数与条目改为 10 篇：保留原 6 条，新增 F/Q 条件对象、`order_by()` 排序、QuerySet 惰性执行与缓存、聚合与分组 4 条；按学习路径排列（查询 → 条件对象 → 排序 → 惰性缓存 → 聚合）。索引笔记自身不加 `## 参考信息` 章节。

## REMOVED Requirements

### Requirement: 00-inbox 中的原始素材文件

**Reason**: 内容已全部拆分归档，保留会造成重复内容与孤立文件，inbox 应保持清空状态。

**Migration**: 无内容迁移动作；该文件未被 git 跟踪（`git status` 显示为未跟踪目录），删除后无法通过 git 恢复，因此必须在 4 篇新笔记正文核对无误后才执行删除。
