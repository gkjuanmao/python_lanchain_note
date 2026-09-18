---
tags: [python, django, elasticsearch, 全文搜索]
description: 使用 django-elasticsearch-dsl 为 Django 模型建立 ES 索引并实现模糊搜索的完整集成示例。
---

# Django集成Elasticsearch模糊搜索

当 Django ORM 的 `icontains` 查询随着数据量增长而变慢时，Elasticsearch (ES) 是一个专业的解决方案。在 Django 中集成 ES，最主流和高效的方式是使用 **`django-elasticsearch-dsl`** 这个库，它能让你用类似 Django ORM 的语法来定义索引和执行搜索。

下面是一个完整的集成示例。

### 📦 第一步：安装与配置

首先，你需要安装 Elasticsearch 服务并启动它。然后，在 Django 项目中安装必要的库。

```bash
# 安装 django-elasticsearch-dsl 以及对应你 ES 版本的客户端库
# 假设你的 Elasticsearch 是 8.x 版本
uv add django-elasticsearch-dsl elasticsearch==8.x
```
同时，你需要将 `django_elasticsearch_dsl` 添加到 `INSTALLED_APPS` 中，并在 `settings.py` 里配置 ES 连接信息。

```python
# settings.py

INSTALLED_APPS = [
    # ...
    'django_elasticsearch_dsl',
    # ...
]

ELASTICSEARCH_DSL = {
    'default': {
        'hosts': 'localhost:9200',  # 你的 ES 地址
        # 如果 ES 开启了安全认证，需要提供用户名和密码
        # 'http_auth': ('username', 'password'),
    },
}
```

### 📝 第二步：为模型定义搜索文档 (Document)

假设我们有一个 `Article` 模型，我们想对文章的标题和内容进行全文搜索。

```python
# models.py
from django.db import models

class Article(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField()
    author = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)
```

然后，在 `documents.py` 中定义 ES 索引的结构。`Document` 类就像 Django 的 `Model`，但它描述的是 ES 中的索引。

```python
# documents.py
from django_elasticsearch_dsl import Document, Index, fields
from django_elasticsearch_dsl.registries import registry
from .models import Article

# 定义一个索引，名字为 'articles'
articles = Index('articles')

# 可选：配置索引的分片和副本数
articles.settings(
    number_of_shards=1,
    number_of_replicas=0
)

@registry.register_document
@articles.document
class ArticleDocument(Document):
    # 定义需要索引的字段
    title = fields.TextField(
        analyzer='ik_max_word',  # 使用中文分词器（需安装IK插件）
        search_analyzer='ik_smart'
    )
    content = fields.TextField(
        analyzer='ik_max_word',
        search_analyzer='ik_smart'
    )
    author = fields.KeywordField()  # Keyword 类型不分词，适合精确匹配或聚合
    created_at = fields.DateField()

    class Django:
        model = Article  # 关联的 Django 模型
        # 当模型保存或删除时，自动同步到 ES
        related_models = []

    def get_queryset(self):
        # 可选：覆盖默认的查询集，比如只索引已发布的文章
        return super().get_queryset().filter(is_published=True)
```

### 🔄 第三步：创建索引并同步数据

定义好 `Document` 后，运行以下命令来创建 ES 索引并将现有数据从数据库同步过去。

```bash
# 创建索引（如果不存在）
python manage.py search_index --create

# 将数据库中的数据同步到 ES（会重建索引）
python manage.py search_index --rebuild
```

之后，每当 `Article` 模型对象被保存或删除，`django-elasticsearch-dsl` 的信号机制会自动同步更新 ES 中的文档。

### 🔍 第四步：执行搜索查询

现在可以在视图或任何地方使用 `ArticleDocument.search()` 来执行搜索了。它的语法和 Django ORM 非常相似。

```python
# views.py
from documents import ArticleDocument

# 1. 简单全文搜索：搜索包含 'Django' 的文章
search = ArticleDocument.search().query("match", title="Django")

# 2. 多字段搜索：在 title 和 content 中搜索 'Elasticsearch'
search = ArticleDocument.search().query(
    "multi_match",
    query="Elasticsearch",
    fields=["title", "content"]
)

# 3. 过滤 + 搜索：搜索标题含 'Django'，且作者为 'John' 的文章
search = ArticleDocument.search().query("match", title="Django").filter("term", author="John")

# 执行查询并获取结果
response = search.execute()

# 遍历结果
for hit in response:
    # hit 是一个类字典对象，可以直接访问其字段
    print(hit.title, hit.author)

# 获取总匹配数
print(f"Total matches: {response.hits.total.value}")
```

### 🚀 第五步：集成 Django REST Framework (可选)

如果你使用 DRF 构建 API，可以安装 `django-elasticsearch-dsl-drf` 来快速创建搜索视图，它能自动处理分页、过滤和排序，代码量极少。

```python
# serializers.py
from django_elasticsearch_dsl_drf.serializers import DocumentSerializer
from .documents import ArticleDocument

class ArticleDocumentSerializer(DocumentSerializer):
    class Meta:
        document = ArticleDocument
        fields = ('id', 'title', 'content', 'author', 'created_at')

# views.py
from django_elasticsearch_dsl_drf.viewsets import DocumentViewSet
from .serializers import ArticleDocumentSerializer
from .documents import ArticleDocument

class ArticleSearchViewSet(DocumentViewSet):
    document = ArticleDocument
    serializer_class = ArticleDocumentSerializer
    # ... 可以配置更多过滤后端等
```

### 💡 其他方案与总结

除了 `django-elasticsearch-dsl`，社区还有几个值得关注的方案：

*   **`django-haystack`**: 一个历史悠久的搜索抽象层，它允许你通过一套统一的 API 在 Solr、Elasticsearch、Whoosh 等多个后端之间切换。如果你的项目可能更换搜索引擎，它是一个考虑选项。
*   **`modelsearch`**: 一个相对较新的库，它的目标是让你**继续使用 Django ORM 来查询**，但底层实际是在 Elasticsearch 上执行。这大大降低了学习成本，对于熟悉 ORM 的开发者非常友好。

**总结一下**，对于大多数需要高性能搜索的 Django 项目，`django-elasticsearch-dsl` 是目前最直接、最灵活的选择。它保留了 ES 强大的查询能力，同时通过 `Document` 类的设计提供了良好的 Django 集成体验。如果你希望尽可能减少代码改动，`modelsearch` 也是一个值得探索的方案。

## 参考信息

- [[2026-09-18-Django-ORM模糊查询]] — ORM `icontains` 的性能瓶颈正是引入 ES 的起因
- [[2026-09-18-Django-ORM查询数据]] — ES 查询语法与 ORM 查询写法的对照
- [[2026-09-18-Django模型与数据库配置]] — SearchDocument 与 Django 模型类的对应关系
- [[2026-09-18-Django入门配置与部署]] — `INSTALLED_APPS` 与 settings 配置方式
