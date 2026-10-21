---
tags: [langchain, 结构化输出, pydantic, 示例代码]
description: LangChain 结构化输出四种模式：Pydantic（含别名、可选字段、默认值、枚举、列表、嵌套、限制条件）、TypedDict、JSON Schema、@dataclass，以及类型校验严格性对比。
---
# LangChain结构化输出


## 什么是结构化输出

> 要求模型最终返回一个符合预定义结构的数据对象，例如固定字段的JSON、Pydantic 模型、TypedDict，而不再是无格式的自然语言文本。

这样做的价值：
* **更容易被代码处理**：下游系统可以直接读字段，而不是再从自然语言里做解析。
* **结果更稳定**：减少“模型说法变了但意思差不多”导致的解析失败。
* **更适合工程化**：适用于表单抽取、分类、路由、调用工具参数生成、工作流状态传递等场景。

## 模式1：Pydantic

```python
from pydantic import BaseModel, Field


class Person(BaseModel):
    """
    任务信息
    """

    name: str = Field(description="人物姓名", alias="姓名")
    age: int = Field(description="人物年龄", alias="年龄")
    occupation: str = Field(description="人物职业", alias="职业")


structured_model = model.with_structured_output(Person, method="json_mode")
result = structured_model.invoke("""
张三是一名30岁的软件开发工程师, 请输出json格式
""")

rprint(result)
rprint(type(result))
"""
output:
Person(name='张三', age=30, occupation='软件开发工程师')
<class '__main__.Person'>
"""

```

当然，目前国内世面上的大模型都不太能支持Pydantic结构化输出，deepseek倒是可以支持json模式，只是需要修改一下模型，给模型字段加一个别名
或者直接使用deepseek-chat模型，没有思考模式，如果有思考模式是不能用 `function_calling`模式的

### 高级特性

#### 1. 可选字段
```python

from pydantic import BaseModel, Field


class Person(BaseModel):
    """
    人物信息
    """

    name: str = Field(description="人物姓名", alias="姓名")
    age: int | None = Field(default=20, description="人物年龄", alias="年龄")
    occupation: str = Field(description="人物职业", alias="职业")


structured_model = model.with_structured_output(Person)
result = structured_model.invoke("""
张三是一名软件开发工程师, 请输出json格式
""")

rprint(result)
rprint(type(result))
```

#### 2. 默认值
```python

from pydantic import BaseModel, Field


class Person(BaseModel):
    """
    人物信息
    """

    name: str = Field(description="人物姓名", alias="姓名")
    age: int | None = Field(20, description="人物年龄", alias="年龄") # 直接在字段中将默认值放进去就可以
    # age: OptionalInt = Field(default=20, description="人物年龄", alias="年龄")
    occupation: str = Field(description="人物职业", alias="职业")


structured_model = model.with_structured_output(Person)
result = structured_model.invoke("""
张三是一名软件开发工程师, 请输出json格式
""")

rprint(result)
rprint(type(result))
```

#### 3. 枚举类型
```python
from enum import Enum


class Priority(str, Enum):
    LOW = "低"
    MEDIUM = "中"
    HIGH = "高"


class CustomerInfo(BaseModel):
    """客户信息"""

    name: str = Field(description="客户姓名")
    phone: str = Field(description="电话号码")
    email: str | None = Field(description="邮箱")
    issue: str = Field(description="问题描述")
    urgency: Priority = Field(description="紧急程度") # 或者使用Literal["低", "中", "高"] 需要import typing包

structured_model = model.with_structured_output(CustomerInfo)
result = structured_model.invoke("""
客服：您好，请问有什么可以帮助您？
客户：我是王小明，电话 138-1234-5678，我的订单一直没发货，很着急！
客服：好的，我帮您查一下
json格式返回
""")
rprint(result)
"""
output:
CustomerInfo(
    name='王小明',
    phone='138-1234-5678',
    email=None,
    issue='订单一直未发货，客户很着急',
    urgency=<Priority.HIGH: '高'>
)
"""
```

#### 4. 列表提取
```python
class Person(BaseModel):
    """人物信息"""
    name : str = Field(description="姓名")
    age :int = Field(description="年龄")
    
class PersonList(BaseModel):
    """人物列表"""
    people :list[Person] # 多个Person的对象
    
structured_model = model.with_structured_output(PersonList)
result = structured_model.invoke("张三 30岁，李四 40岁")
rprint(result)
"""output
PersonList(people=[Person(name='张三', age=30), Person(name='李四', age=40)])
"""
```

#### 5. 嵌套结构
```python
class Address(BaseModel):
    """地点描述"""
    city : str = Field(description="城市")
    district : str = Field(description="区域")


class Company(BaseModel):
    """公司信息"""
    name : str = Field(description="公司名称")
    address : Address = Field(description="公司所在地")


structured_model = model.with_structured_output(Company)

result = structured_model.invoke("阿里巴巴在杭州的滨江区")
rprint(result)
"""output
Company(name='阿里巴巴', address=Address(city='杭州', district='滨江区'))
"""
```

**说明：** 嵌套深度不能超过3，复杂的嵌套格式可能会出错
#### 6. 限制条件


```python
class User(BaseModel):
    name : str = Field(description="姓名", min_length=2, max_length=50)
    age : int = Field(description="年龄", le=150)
    email : str = Field(description="邮箱")
```

### 工作流程图解

![[images/structured-output-workflow.png]]


## 模式2：`TypedDict`

### 什么是`TypedDict`

`TypedDict`是Python 3.8+引入的一种类型提示工具，即带有类型声明的字典结构。适合需要快速定义字典结构且无需Pydantic重量级功能的场景。

### 基本使用

```python
from typing import Annotated

from rich import print as rprint
from typing_extensions import TypedDict


class MovieDict(TypedDict):
    """电影信息"""
    title :Annotated[str,"电影的名称"]
    year : Annotated[int,"电影的上映时间，四位数"]
    director : Annotated[str,"电影的导演"]
    rating :Annotated[float,"电影的评分，满分是10分，可以包含一位小数"]

structured_model = model.with_structured_output(MovieDict)
response = structured_model.invoke("给我介绍一下星际穿越电影")
rprint(response)
rprint(type(response))
"""output
{'title': '星际穿越', 'year': 2014, 'director': '克里斯托弗·诺兰', 'rating': 9.4}
<class 'dict'>
"""
```

### 嵌套结构使用
```python
from typing import Annotated

from rich import print as rprint
from typing_extensions import TypedDict


class Actor(TypedDict):
    """演员信息"""

    name: str = Annotated[str, "演员的名字"]
    role: str = Annotated[str, "电影中的角色"]


class MovieDict(TypedDict):
    """电影信息"""

    title: Annotated[str, "电影的名称"]
    year: Annotated[int, "电影的上映时间，四位数"]
    director: Annotated[str, "电影的导演"]
    rating: Annotated[float, "电影的评分，满分是10分，可以包含一位小数"]
    cast: Annotated[list[Actor], "演员的列表"]


structured_model = model.with_structured_output(MovieDict)
response = structured_model.invoke("给我介绍一下星际穿越电影")
rprint(response)
rprint(type(response))
"""output
{
    'title': '星际穿越',
    'year': 2014,
    'director': '克里斯托弗·诺兰',
    'rating': 9.4,
    'cast': [
        {'name': '马修·麦康纳', 'role': '库珀'},
        {'name': '安妮·海瑟薇', 'role': '布兰德'},
        {'name': '杰西卡·查斯坦', 'role': '墨菲'},
        {'name': '迈克尔·凯恩', 'role': '布兰德教授'},
        {'name': '马特·达蒙', 'role': '曼恩博士'}
    ]
}
"""
```

### ...的使用

必须要填充字段的意思，不同模型提供商的行为会有不同
```python
class MovieDict(TypedDict):
    """电影信息"""

    title: Annotated[str, ..., "电影的名称"]
    year: Annotated[int, ..., "电影的上映时间，四位数"]
    director: Annotated[str, ..., "电影的导演"]
    rating: Annotated[float, ..., "电影的评分，满分是10分，可以包含一位小数"]


structured_model = model.with_structured_output(MovieDict)
response = structured_model.invoke("根据这段话抽取盗梦空间的信息，不包含的信息可以留空：盗梦空间在2010年上映，导演是克里斯托弗·诺兰。")
rprint(response)
rprint(type(response))
"""output
{'title': '盗梦空间', 'year': 2010, 'director': '克里斯托弗·诺兰', 'rating': 0}
"""
```

## 模式3: `JSON Schema`

这种方式需要按照`JSON Schema`规范拼接JSON字符串，比较繁琐，并且缺少校验机制，不推荐

## 模式4：`@dataclass`

`@dataclass`是`Python`标准库`dataclasses`提供的类装饰器，用于简化“以字段为核心”的数据类定义
给类加上`@dataclass`后，python会根据字段声明自动生成常用方法，例如：
+ `__init__`
+ `__repr_`
+ `__eq__`
因此，从对象行为上看，`@dataclass`创建的类，常常近似于手写这些方法的普通类。
```python
from dataclasses import dataclass

@dataclass
class Movie:
    title: str
    year: int
    director: str
    rating: float
```

**注意：**

虽然 `@dataclass` 在行为上接近于手写 `__init__`、`__repr__`、`__eq__` 的普通类，但二者**并不完全等价**。`@dataclass` 修饰后的类仍然是普通的python类，但它会被标准库标记为**数据类**，并携带dataclass的字段元信息，手写 `__init__` 等方法的普通类不能替代@dataclass修饰的类。

前者可以作为Langchain的Schema，而后者不行。

## 关于类型校验

只有pydantic数据模型的校验是严格的，如果大模型返回的数据类型和定义的不一致，那么就会抛出异常，其他的结构化输出不会抛出异常

## 参考信息

- [[2026-10-11-AI知识地图]] — 学习路径中的位置：知识地图「第五步：应用开发」
- [[2026-10-14-LangChain工具调用]] — 机制配套：with_structured_output 与 bind_tools 共用 function_calling 通道，args_schema 的 Pydantic 定义与本篇 Schema 写法一致
