---
tags: [python, django, orm, moc, 索引]
description: Django ORM 知识地图，按模型与数据建模、写入、查询、结果处理、性能优化五组串联 13 篇笔记。
---

# Django-ORM知识地图

Django ORM 主线的 13 篇，建议按组顺序阅读；基础主线 14 篇的入口见文末「相关领域入口」。

## 一、模型与数据建模（3 篇）

- [[2026-09-18-Django模型与数据库配置]] — ORM 概述、PostgreSQL 配置、模型定义、Faker 测试数据
- [[2026-09-19-Django关联模型与范式]] — 范式理论与一对一/一对多/多对多、on_delete 取值、related_name 与自关联
- [[2026-09-19-Django虚拟外键与通用外键]] — 只存 ID 的虚拟外键、GenericForeignKey 与 GenericRelation 反向查询

## 二、写入与更新（3 篇）

- [[2026-09-18-Django-ORM新增数据]] — create/save/bulk_create、get_or_create、五种方法对比
- [[2026-09-18-Django-ORM更新数据]] — save() 与 update() 区别、auto_now 陷阱、并发与 bulk_update
- [[2026-09-18-Django-ORM删除数据]] — delete()、级联删除 on_delete、软删除、事务包裹

## 三、查询（3 篇）

- [[2026-09-18-Django-ORM查询数据]] — all/filter/exclude/get 及衍生方法
- [[2026-09-18-Django-ORM模糊查询]] — contains/regex/in/range、跨表查询、Q 与 F 表达式、性能优化
- [[2026-09-19-Django-ORM的F对象与Q对象]] — F 对象引用字段与原子更新、Q 对象组合 OR/NOT 与动态条件

## 四、结果处理（3 篇）

- [[2026-09-19-Django-ORM排序]] — order_by 升序降序、多字段、跨表与表达式排序、NULL 位置控制与性能优化
- [[2026-09-19-Django-ORM聚合与分组]] — aggregate 与 annotate 的区别、条件聚合、values 与 annotate 顺序及 WHERE/HAVING 判定
- [[2026-09-19-Django-ORM惰性执行与缓存]] — QuerySet 惰性求值时机、结果缓存机制与缓存失效的常见坑

## 五、性能优化（1 篇）

- [[2026-09-19-Django查询优化]] — N+1 成因、select_related 与 prefetch_related 预加载、批量操作与索引优化

---

## 相关领域入口

- [[2026-09-18-Django知识地图]] — 兄弟地图：Django 基础主线 14 篇（入门配置、路由与请求响应、模板与静态文件、中间件与安全、部署与生态）
- [[2026-09-15-SQLite命令行速查表]] — 命令行验证 SQL 与索引行为