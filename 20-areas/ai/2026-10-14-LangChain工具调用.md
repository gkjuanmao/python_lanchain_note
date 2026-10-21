---
tags: [langchain, 工具调用, agent, 示例代码]
description: LangChain 工具调用（Tool Calling）：@tool 定义工具、invoke 直接调用、bind_tools 交给 AI 决定调用、convert_to_openai_tool 查看解析后的工具描述，以及 docstring 规范、参数类型与默认值、parse_docstring 与自定义 args_schema（Pydantic / JSON Schema）。
---
# LangChain工具调用


在LangChain中，工具(Tools)实际上是指明确定义了输入和输出的`可调用函数`。因此，工具调用(Tool Calling)也被称为函数调用(Function Calling)
具体有两种调用方式

## 方式1：直接调用

```python
from langchain_core.tools import tool


@tool
def get_weather(city: str) -> str:
    """根据城市名称获取该城市的天气情况。""" 
    return city + " 函数调用成功"

get_weather.invoke({"city":"nanjing"})
```

## 方式2： AI进行调用

```python
from langchain_core.messages import AIMessage, HumanMessage

model_with_tools = model.bind_tools([get_weather])
messages = [
    HumanMessage("北京天气如何？")
]
response = model_with_tools.invoke(messages)
print(response)
if response.tool_calls:
    print("AI 需要调用工具 ", response.tool_calls)
    messages.append(response)
    for tool_call in response.tool_calls:
        if tool_call["name"] == "get_weather":
            tool_response = get_weather.invoke(tool_call)
            messages.append(tool_response)
else:
    print("AI 直接回答 ", response.content)

for i, msg in enumerate(messages):
    print(i, type(msg), repr(msg)[:100])

for msg in messages:
    msg.pretty_print()

final_response = model_with_tools.invoke(messages)

print(f"最终结果：{final_response.content}")
```

## 工具描述的各部分详解

### 了解：convert_to_openai_tool

执行model.bind_tools(get_weather)]，底层最终会调用convert_to_openai_tool生成工具描述，所以我们可以直接调用后者查看解析后的工具描述

```python
from langchain_core.utils.function_calling import convert_to_openai_tool
from rich import print


def get_weather(city : str):
    return f"{city}天气晴朗"

print(convert_to_openai_tool(get_weather))

"""
output:
{
    'type': 'function',
    'function': {
        'name': 'get_weather',
        'description': '',
        'parameters': {'properties': {'city': {'type': 'string'}}, 'required': ['city'], 'type': 'object'}
    }
}
"""
```


### 问题：为什么不使用@tool装饰器修饰的函数，也可以理解为工具呢？

查看`convert_to_openai_tool`底层代码

```python
    elif isinstance(function, BaseTool):
        oai_function = cast("dict[str, Any]", _format_tool_to_openai_function(function))
    elif callable(function):
        oai_function = cast(
            "dict[str, Any]", _convert_python_function_to_openai_function(function)
        )
```

不使用@tool装饰器，也会调用_convert_python_function_to_openai_function转换为openai方法

### description说明

```python
from langchain_core.utils.function_calling import convert_to_openai_tool
from rich import print


def get_weather(city : str):
    """
    查询城市的天气
    """
    return f"{city}天气晴朗"

print(convert_to_openai_tool(get_weather))
```

方法中一定要加描述，否则大模型没法识别tool

### 参数说明

convert_to_openai_tool会从docstring加载参数说明，这里的docstring必须遵循 Google 风格。

- Google风格 docstring 说明： [https://google.github.io/styleguide/pyguide.html](https://google.github.io/styleguide/pyguide.html)
- Google风格 docstring 示例： [https://www.sphinx-doc.org/en/master/usage/extensions/example_google.html](https://www.sphinx-doc.org/en/master/usage/extensions/example_google.html)
- Python docstring 通用约定： [https://peps.python.org/pep-0257/](https://peps.python.org/pep-0257/)

```python
from langchain_core.utils.function_calling import convert_to_openai_tool
from rich import print


def get_weather(city : str):
    """
    查询城市的天气
    
    Args:
	    city:具体的城市
	    
	Returns:
		返回尝试天气
    """
    return f"{city}天气晴朗"

print(convert_to_openai_tool(get_weather))
```

### 参数类型的说明

要求：如果在docstring中声明了参数的描述，则必须在函数声明处指明参数的类型
如下的代码会报错
```python
from langchain_core.utils.function_calling import convert_to_openai_tool
from rich import print


def get_weather(city):
    """
    查询城市的天气
    
    Args:
	    city:具体的城市
	    
	Returns:
		返回尝试天气
    """
    return f"{city}天气晴朗"

print(convert_to_openai_tool(get_weather))

"""
ValueError: Arg city in docstring not found in function signature.
"""
```

### 参数的默认值

```python
from langchain_core.utils.function_calling import convert_to_openai_tool
from rich import print


def get_weather(city: str = default):
    """
    查询城市的天气
    
    Args:
	    city:具体的城市
	    
	Returns:
		返回尝试天气
    """
    return f"{city}天气晴朗"

print(convert_to_openai_tool(get_weather))

"""
ValueError: Arg city in docstring not found in function signature.
"""
```

一旦给参数设置了默认值，则打印结果中的required中就不再包含该字段

## 使用@tool装饰器定义工具

### 自定义工具描述：description

```python
from langchain_core.tools import tool
from langchain_core.utils.function_calling import convert_to_openai_tool
from rich import print


@tool(description="获取具体城市的天气")
def get_weather(city: str):
    """
    查询城市的天气

    Args:
        city : 具体的城市
    """
    return f"{city}天气晴朗"


print(convert_to_openai_tool(get_weather))
```

在同时使用的docstring和装饰器中的description时，description优先级更高

### parse_docstring

如果装饰器不使用`parse_docstring`参数，则无法显示参数的信息，需要在装饰器中定义`parse_docstring`，并且赋值`True`，工具参数的信息才会被打印出来，相当于给docstring加了一层校验，不符合规范的描述会报错

```python
from langchain_core.tools import tool
from langchain_core.utils.function_calling import convert_to_openai_tool
from rich import print


@tool(parse_docstring=True)
def get_weather(city: str):
    """
    查询城市的天气

    Args:
        city : 具体的城市
    """
    return f"{city}天气晴朗"


print(convert_to_openai_tool(get_weather))
"""
output:
{
    'type': 'function',
    'function': {
        'name': 'get_weather',
        'description': '查询城市的天气',
        'parameters': {
            'properties': {'city': {'description': '具体的城市', 'type': 'string'}},
            'required': ['city'],
            'type': 'object'
        }
    }
}
"""
```

### 更改工具名称

`name_or_callable`

不推荐！

## 自定义args_schema

### 方式1 使用Pydantic模型定义

当工具的参数变得复杂，需要枚举值、范围限制或更复杂的业务逻辑验证时，`Pydantic`模型是理想的选择，提供强大的类型检查和数据验证。
使用`Pydantic`的主要优势在于能够精确控制工具参数的格式和验证规则，让大模型更准确地理解如何调用工具。

```python
from typing import Literal

from langchain_core.tools import tool
from langchain_core.utils.function_calling import convert_to_openai_tool
from pydantic import BaseModel, Field
from rich import print


class WeatherInput(BaseModel):
    city:str = Field(
        description="具体的城市",
        default="北京"
    )
    unit:Literal["celsius","fahrenheit"] = Field(
        description="温度单位",
        default="celsius"
    )


@tool(args_schema=WeatherInput)
def get_weather(city: str, unit: str):
    """
    查询城市的天气
    """
    return f"{city}天气晴朗"


print(convert_to_openai_tool(get_weather))

"""
output:
{
    'type': 'function',
    'function': {
        'name': 'get_weather',
        'description': '查询城市的天气',
        'parameters': {
            'properties': {
                'city': {'default': '北京', 'description': '具体的城市', 'type': 'string'},
                'unit': {
                    'default': 'celsius',
                    'description': '温度单位',
                    'enum': ['celsius', 'fahrenheit'],
                    'type': 'string'
                }
            },
            'type': 'object'
        }
    }
}
"""
```

### 方式2 Json Schema定义

在LangChain中，还可以直接使用JSONSchema字典来定义工具的参数模式。这种方式提供了极大的灵活性。
因为工具参数模式可以基于数据库配置或用户输入在运行时动态生成，所以这种方式特别适合参数结构需要动态生成的场景。

```python
from typing import Literal

from langchain_core.tools import tool
from langchain_core.utils.function_calling import convert_to_openai_tool
from pydantic import BaseModel, Field
from rich import print

json_schema = {
    "parameters": {
        "properties": {
            "city": {
                "default": "北京",
                "description": "具体的城市",
                "type": "string",
            },
            "unit": {
                "default": "celsius",
                "description": "温度单位",
                "enum": ["celsius", "fahrenheit"],
                "type": "string",
            },
        },
        "type": "object",
    },
}


@tool(args_schema=json_schema)
def get_weather(city: str, unit: str):
    """获取城市天气"""
    return f"{city}天气晴朗"


print(convert_to_openai_tool(get_weather))
"""
output
{
    'type': 'function',
    'function': {
        'name': 'get_weather',
        'description': '获取城市天气',
        'parameters': {
            'parameters': {
                'properties': {
                    'city': {'default': '北京', 'description': '具体的城市', 'type': 'string'},
                    'unit': {
                        'default': 'celsius',
                        'description': '温度单位',
                        'enum': ['celsius', 'fahrenheit'],
                        'type': 'string'
                    }
                },
                'type': 'object'
            }
        }
    }
}
"""
```


## 多工具的调用

```python
from langchain_core.messages import HumanMessage
from langchain_core.tools import tool
from rich import print as rprint


@tool(parse_docstring=True)
def get_weather(city: str):
    """
    查询城市天气

    Args:
        city:具体的城市

    Returns:
        城市的天气
    """
    return f"{city}天气晴朗"


@tool(parse_docstring=True)
def get_news(company: str):
    """
    查询公司新闻

    Args:
        company:具体的公司名称

    Returns:
        公司的新闻
    """
    return f"{company}今天无新闻"


model_with_tool = model.bind_tools([get_weather, get_news])

messages_list = [HumanMessage("北京天气怎么样？小米公司有什么新闻？")]

while True:
    response = model_with_tool.invoke(messages_list)
    messages_list.append(response)
    if not response.tool_calls:
        break

    for tool_call in response.tool_calls:
        if tool_call["name"] == "get_weather":
            stock_result = get_weather.invoke(tool_call)
            rprint(stock_result)
            messages_list.append(stock_result)
        if tool_call["name"] == "get_news":
            news_result = get_news.invoke(tool_call)
            rprint(news_result)
            messages_list.append(news_result)


    for msg in messages_list:
        msg.pretty_print()

rprint(response.content)
```

##  强制使用工具

### tool_choice参数说明

tool_choice取值有：none,auto,required,工具名
+ 不允许调用任何工具
+ auto:自行判断是否需要调用工具
+ required:强制调用工具，不论是否需要调用
+ 工具名:强制调用指定的工具

```python
from langchain_core.messages import HumanMessage
from langchain_core.tools import tool
from rich import print as rprint


@tool(parse_docstring=True)
def get_weather(city: str):
    """
    查询城市天气

    Args:
        city:具体的城市

    Returns:
        城市的天气
    """
    return f"{city}天气晴朗"

model_with_tool = model.bind_tools([get_weather],tool_choice="none")

response = model_with_tool.invoke("今天天气怎么样？")

rprint(response)
rprint(f"当前对话没有调用任何工具 {response.tool_calls}")

"""
output
当前对话没有调用任何工具 []
"""
```


## 实践经验总结
### 1. 清晰的描述
### 2. 功能单一
### 3. 如何处理工具执行失败？

三层防护
#### 1. 工具内部处理
```python
@tool
def divide(a: float, b: float) -> str:
    """
    除法计算

    Args:
        a: 被除数
        b: 除数
    """
    try:
        if b == 0:
            return "错误：除数不能为零"
        result = a / b
        return f"{a} / {b} = {result}"
    except Exception as e:
        return f"计算错误: {e}"
```
####  2. Agent级重试（使用prompt）

```python
agent = create_agent(
    model=model,
    tools=[...],
    prompt="如果工具失败，尝试使用其他方法解决问题。"
)
```
#### 3. 调用级重试

在大模型应用中，网络请求和外部工具调用是最容易掉链子的地方，@retry就像是一个容错保险

```python
from tenacity import retry, stop_after_attempt

# 1. 配置重试规则：如果失败，最多尝试 3 次（即第 1 次正常调用 + 2 次重试）
@retry(stop=stop_after_attempt(3))
def call_agent(question):
    # 2. 核心业务逻辑：调用 LangChain 的 Agent
    return agent.invoke({"messages": [{"role": "user", "content": question}]})
```

工作流程：
1. 调用`call_agent('你好')`
2. 程序进入函数，执行`agent.invoke(...)`
3. 如果执行成功：正常返回结果，`@retry`什么都不做
4. 如果执行失败(报错)：`@retry`会拦截这个错误，不让程序直接崩溃，它会默默地帮你再次触发`agent.invoke(...)`
5. 如果连续3次都报错：它终于放弃了，把第3次的报错真正抛出来，程序此时才会报错终止
#### 4. 返回字符串

```python
# ✅ 好：返回字符串
@tool
def get_user_info(user_id: str) -> str:
    """获取用户信息"""
    user = {"id": user_id, "name": "张三"}
    return json.dumps(user, ensure_ascii=False)  # 转成 JSON 字符串


# ❌ 不好：返回字典（某些情况可能有问题）
@tool
def get_user_info(user_id: str) -> dict:
    """获取用户信息"""
    return {"id": user_id, "name": "张三"}
```

#### 5. 选择同步vs异步

+ 同步工具：简单场景，CPU密集型任务
+ 异步工具：IO密集型（API调用、数据库、文件操作）

```python
# 同步
@tool
def sync_tool(x: str) -> str:
    return process(x)

# 异步
@tool
async def async_tool(x: str) -> str:
    return await async_process(x)
```

## 参考信息

- [[2026-10-11-AI知识地图]] — 学习路径中的位置：知识地图「第五步：应用开发」
- [[2026-10-14-LangChain消息与对话历史]] — 机制配套：tool_calls 与工具执行结果都要追加进消息列表再回传模型
