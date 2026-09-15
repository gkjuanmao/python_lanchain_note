Django Template Language（DTL）是一套**故意设计得简单、受限**的模板语法。它的核心哲学是：模板只负责展示，不写业务逻辑。下面按类别系统梳理。

---

## 一、四种基本语法符号

| 语法 | 名称 | 作用 |
|---|---|---|
| `{{ ... }}` | 变量 | 输出变量的值 |
| `{% ... %}` | 标签 | 控制逻辑（if、for、block 等） |
| `{{ x\|filter }}` | 过滤器 | 修改变量的输出 |
| `{# ... #}` | 注释 | 单行注释，不输出 |

```html
{{ username }}
{% if user.is_authenticated %}...{% endif %}
{{ name|upper }}
{# 这是注释 #}
```

多行注释用：

```html
{% comment "可选说明" %}
    这里可以写很多行
{% endcomment %}
```

---

## 二、变量 `{{ }}`

### 1. 基本用法

```html
{{ name }}
{{ user.username }}
{{ user.profile.bio }}
{{ items.0 }}          {# 列表索引，用点号 #}
{{ dict.key }}         {# 字典取值，也用点号 #}
```

DTL 查找变量时按顺序尝试：

1. 字典查找 `dict['key']`
2. 属性/方法查找 `obj.key`
3. 列表索引 `list[0]`

失败则返回 `string_if_invalid`（默认空字符串），**不报错**。

### 2. 方法调用

```html
{{ user.get_full_name }}   {# 自动调用无参方法，不加括号 #}
```

⚠️ DTL 不允许调用带参数的方法，这是它的安全限制。

### 3. 特殊变量

| 变量 | 说明 |
|---|---|
| `{{ request }}` | 当前请求（需开启上下文处理器） |
| `{{ user }}` | 当前登录用户 |
| `{{ messages }}` | flash 消息 |
| `{{ csrf_token }}` | CSRF token |
| `{{ STATIC_URL }}` | 静态文件前缀（旧方式） |
| `{{ MEDIA_URL }}` | 媒体文件前缀 |

---

## 三、过滤器 `|`

过滤器用管道符连接，可链式调用。

```html
{{ name|lower }}
{{ name|upper|truncatechars:10 }}
{{ value|default:"空" }}
```

### 常用内置过滤器

**字符串类**

| 过滤器 | 作用 | 示例 |
|---|---|---|
| `lower` / `upper` | 大小写 | `{{ "AbC"\|lower }}` → `abc` |
| `title` | 首字母大写 | `hello world` → `Hello World` |
| `capfirst` | 首字母大写 | `hello` → `Hello` |
| `truncatechars:n` | 截断 n 字符 | `{{ text\|truncatechars:20 }}` |
| `truncatewords:n` | 截断 n 词 | `{{ text\|truncatewords:10 }}` |
| `length` | 长度 | `{{ name\|length }}` |
| `slice:"0:5"` | 切片 | `{{ text\|slice:":5" }}` |
| `default:"x"` | 默认值（空时） | `{{ name\|default:"匿名" }}` |
| `default_if_none:"x"` | 仅 None 时默认 | |
| `escape` / `safe` | 转义 / 不转义 | `{{ html\|safe }}` |
| `linebreaks` | 换行转 `<p>`/`<br>` | |
| `linebreaksbr` | 换行转 `<br>` | |
| `striptags` | 去掉 HTML 标签 | |
| `wordcount` | 单词数 | |
| `join:", "` | 列表拼接 | `{{ list\|join:", " }}` |
| `add:"2"` | 加法/拼接 | `{{ num\|add:"2" }}` |
| `stringformat:"s"` | 格式化 | |

**数值类**

| 过滤器 | 作用 |
|---|---|
| `floatformat:2` | 保留 2 位小数 |
| `filesizeformat` | 转成 KB/MB |
| `pluralize` | 复数后缀 |

```html
{{ count }} 条消息{{ count|pluralize }}      {# 1 条 / 2 条 #}
{{ count }} {{ count|pluralize:"y,ies" }}     {# 自定义 #}
```

**日期时间类**

```html
{{ date|date:"Y-m-d H:i:s" }}
{{ date|date:"D d M Y" }}
{{ date|timesince }}     {# 距现在多久 #}
{{ date|timeuntil }}     {# 距将来多久 #}
```

**列表类**

| 过滤器 | 作用 |
|---|---|
| `first` / `last` | 首/末元素 |
| `length` | 长度 |
| `random` | 随机一个 |
| `slice` | 切片 |
| `dictsort:"key"` | 按 key 排序 |
| `dictsortreversed:"key"` | 反向排序 |

**转义相关**

| 过滤器 | 作用 |
|---|---|
| `escape` | HTML 转义（默认已开启） |
| `safe` | 标记为安全，不转义 |
| `escapejs` | JS 上下文转义 |
| `urlencode` | URL 编码 |
| `iriencode` | IRI 编码 |
| `json_script` | 安全输出 JSON |

> ⚠️ `safe` 是 XSS 风险点，只对可信内容使用。

---

## 四、标签 `{% %}`

### 1. 条件判断

```html
{% if user.is_authenticated %}
    欢迎 {{ user.username }}
{% elif user.is_staff %}
    管理员
{% else %}
    请登录
{% endif %}
```

**支持的运算符**：

| 类型 | 运算符 |
|---|---|
| 比较 | `==` `!=` `<` `>` `<=` `>=` |
| 逻辑 | `and` `or` `not` |
| 成员 | `in` `not in` |
| 身份 | `is` `is not` |

```html
{% if a > 1 and b < 10 %}
{% if name in names %}
{% if x is None %}
{% if not user.is_active %}
```

⚠️ DTL **不支持** `{% if a > 1 and b < 10 or c == 3 %}` 这种复杂括号组合，需嵌套或拆分。

### 2. 循环

```html
{% for item in items %}
    {{ forloop.counter }}. {{ item }}
{% empty %}
    没有数据
{% endfor %}
```

**`forloop` 变量**

| 变量 | 说明 |
|---|---|
| `forloop.counter` | 从 1 开始计数 |
| `forloop.counter0` | 从 0 开始计数 |
| `forloop.revcounter` | 倒序，最后为 1 |
| `forloop.revcounter0` | 倒序，最后为 0 |
| `forloop.first` | 是否第一个 |
| `forloop.last` | 是否最后一个 |
| `forloop.parentloop` | 外层循环的 forloop |

**遍历字典**

```html
{% for key, value in data.items %}
    {{ key }}: {{ value }}
{% endfor %}
```

### 3. 模板继承

**父模板 `base.html`**

```html
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}默认标题{% endblock %}</title>
</head>
<body>
    {% block content %}{% endblock %}
    {% block footer %}
        <p>默认页脚</p>
    {% endblock %}
</body>
</html>
```

**子模板**

```html
{% extends "base.html" %}

{% block title %}首页{% endblock %}

{% block content %}
    <h1>欢迎</h1>
{% endblock %}
```

**要点**：
- `{% extends %}` 必须是子模板的**第一个标签**。
- 子模板只能覆盖 `block` 内容，不能直接写 HTML。
- 用 `{{ block.super }}` 调用父模板 block 内容。

```html
{% block footer %}
    {{ block.super }}
    <p>附加内容</p>
{% endblock %}
```

### 4. include

```html
{% include "header.html" %}
{% include "card.html" with title="标题" subtitle="副标题" %}
{% include "card.html" with title="标题" only %}   {# only 表示不继承当前上下文 #}
```

### 5. url 反向解析

```html
{% url 'blog:detail' post.id %}
{% url 'blog:detail' pk=post.id %}
{% url 'home' as home_url %}   {# 存到变量 #}
```

### 6. static 静态文件

```html
{% load static %}
<link rel="stylesheet" href="{% static 'css/style.css' %}">
<img src="{% static 'images/logo.png' %}">
```

### 7. csrf_token

```html
<form method="post">
    {% csrf_token %}
    ...
</form>
```

必须放在所有 POST 表单里，否则 403。

### 8. with（定义临时变量）

```html
{% with total=items|length %}
    {{ total }} 个商品
{% endwith %}

{% with name="Tom" age=18 %}
    {{ name }} - {{ age }}
{% endwith %}
```

### 9. 其他常用标签

| 标签 | 作用 |
|---|---|
| `{% autoescape off %}...{% endautoescape %}` | 关闭自动转义 |
| `{% filter upper %}...{% endfilter %}` | 对块内容应用过滤器 |
| `{% spaceless %}...{% endspaceless %}` | 去掉标签间空白 |
| `{% templatetag %}` | 输出模板符号本身 |
| `{% now "Y-m-d" %}` | 当前时间 |
| `{% cycle 'a' 'b' 'c' %}` | 循环输出 |
| `{% firstof a b c %}` | 输出第一个为真的变量 |
| `{% lorem %}` | 生成占位文本 |
| `{% verbatim %}...{% endverbatim %}` | 原样输出，不解析模板 |
| `{% load %}` | 加载自定义标签/过滤器库 |

### 10. `{% cycle %}` 示例

```html
{% for item in items %}
    <tr class="{% cycle 'odd' 'even' %}">
        {{ item }}
    </tr>
{% endfor %}
```

---

## 五、模板加载与配置

```python
# settings.py
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
            'string_if_invalid': '',   # 变量不存在时的输出
            'libraries': {              # 自定义标签库
                'my_filters': 'myapp.templatetags.my_filters',
            },
        },
    },
]
```

---

## 六、自定义过滤器与标签

### 1. 创建目录结构

```
myapp/
    templatetags/
        __init__.py
        my_filters.py
```

### 2. 自定义过滤器

```python
# myapp/templatetags/my_filters.py
from django import template

register = template.Library()

@register.filter
def multiply(value, arg):
    return value * arg

@register.filter(name='reverse_str')
def reverse_str(value):
    return value[::-1]
```

使用：

```html
{% load my_filters %}
{{ num|multiply:3 }}
{{ name|reverse_str }}
```

### 3. 自定义简单标签

```python
@register.simple_tag
def current_time(fmt):
    from django.utils import timezone
    return timezone.now().strftime(fmt)
```

使用：

```html
{% current_time "%Y-%m-%d" %}
```

### 4. 包含标签

```python
@register.inclusion_tag('user_card.html')
def user_card(user):
    return {'user': user}
```

---

## 七、自动转义（重要）

DTL 默认对变量输出做 HTML 转义，防止 XSS：

```html
{{ user_input }}   {# <script> 会变成 &lt;script&gt; #}
```

关闭方式：

```html
{{ html|safe }}
{% autoescape off %}{{ html }}{% endautoescape %}
```

⚠️ 只在内容可信时使用 `safe`，否则有 XSS 风险。

---

## 八、DTL 的限制

DTL 故意不支持以下功能：

| 不支持 | 说明 |
|---|---|
| 复杂表达式 | `{{ a + b * c }}` 不行，要用过滤器 |
| 函数调用带参 | `{{ func(x) }}` 不行 |
| 赋值语句 | 变量只能通过 `with` 或视图传 |
| 列表推导 / lambda | 不支持 |
| 任意 Python 代码 | 出于安全考虑禁止 |
| 括号分组逻辑 | `{% if (a or b) and c %}` 不支持 |

需要复杂逻辑时，应在**视图层**处理，模板只做展示。

---

## 九、DTL vs Jinja2

| 特性 | DTL | Jinja2 |
|---|---|---|
| 函数调用带参 | ❌ | ✅ |
| 复杂表达式 | ❌ | ✅ |
| 赋值 | 有限 | ✅ |
| 宏 | ❌ | ✅ |
| 性能 | 较慢 | 较快 |
| 学习曲线 | 简单 | 稍复杂 |
| 安全默认 | 自动转义 | 自动转义 |
| Django 集成 | 原生 | 需配置 |

Django 可同时使用 DTL 和 Jinja2，通过 `TEMPLATES` 配置多个引擎。

---

## 十、速查表

```html
{# 变量 #}
{{ var }}  {{ obj.attr }}  {{ list.0 }}  {{ dict.key }}

{# 过滤器 #}
{{ var|filter }}  {{ var|f1|f2:"arg" }}

{# 标签 #}
{% if %}...{% elif %}...{% else %}...{% endif %}
{% for x in list %}...{% empty %}...{% endfor %}
{% extends "base.html" %}
{% block name %}...{% endblock %}
{% include "partial.html" with x=1 only %}
{% url 'name' arg %}
{% load static %}
{% csrf_token %}
{% with a=1 %}...{% endwith %}
{% comment %}...{% endcomment %}

{# 注释 #}
{# 单行 #}
```

---

## 总结

DTL 的语法就四类符号：`{{ }}` 变量、`{% %}` 标签、`|` 过滤器、`{# #}` 注释。核心标签是 `if`、`for`、`extends`、`block`、`include`、`url`、`static`、`csrf_token`。它的设计目标是**简单、安全、只做展示**，复杂逻辑必须放在视图层。掌握这些，日常开发就够用了；需要更强表达力时，再考虑 Jinja2。