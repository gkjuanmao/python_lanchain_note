---
tags: [langchain, agent, 中间件, 示例代码]
description: LangChain 1.x 自定义中间件之 Wrap-style hooks：wrap_model_call 与 wrap_tool_call 的装饰器、类两种写法、调用前后改写请求与响应的要点、写法选择与执行顺序。
---

# LangChainWrap-style钩子

## 一、概述

Wrap-style hooks 是 LangChain 自定义中间件的第二类钩子：包裹的是**模型调用**或**工具调用**本身，能在调用前后读取和改写请求与响应，适合控制流，例如重试、回退、缓存、参数修正。

包含两个钩子：

- `wrap_model_call`：包裹模型调用
- `wrap_tool_call`：包裹工具调用

另一类是 Node-style hooks，在流程的固定节点运行；两者的入口都在 AI 知识地图里。

支持两种写法（与 Node-style 一致）：

- **装饰器**：函数式挂载，一个装饰器包住一次调用。
- **类**：对象化中间件，重写对应方法。

## 二、基于装饰器的实现

### wrap_model_call

`request.messages` 是本次要发给模型的消息，`handler(request)` 才会真正触发模型调用；不调用 handler 就相当于把这次模型调用拦截掉了。

```python
from langchain.chat_models import init_chat_model
from dotenv import load_dotenv
import os

from typing import Callable
from langchain.agents import create_agent
from langchain.agents.middleware import wrap_model_call, ModelRequest, ModelResponse
from langchain_core.messages import HumanMessage

# 从 .env 文件中加载环境变量
load_dotenv(override=True)

model = init_chat_model(
    model="gpt-5.4-mini",
    model_provider="openai",
    api_key=os.getenv("CLOSEAI_API_KEY"),
    base_url=os.getenv("CLOSEAI_BASE_URL"),
)

@wrap_model_call
def wrap_model_call_middleware(
    request: ModelRequest,
    handler: Callable[[ModelRequest], ModelResponse],
) -> ModelResponse | None:
    request.messages[-1].content += "---> wrap_model_call_before <---"

    # 模型的调用
    response = handler(request)

    response.result[0].content += "---> wrap_model_call_after <---"

    return response

agent = create_agent(
    model=model,
    middleware=[wrap_model_call_middleware],
)

response = agent.invoke({"messages": [HumanMessage("你好")]})
for msg in response["messages"]:
    msg.pretty_print()
```

输出（截取关键部分，可以看到请求和响应分别被改写）：

```
Human Message: 你好---> wrap_model_call_before <---
Ai Message: 你好！...---> wrap_model_call_after <---
```

### wrap_tool_call

`wrap_tool_call` 包裹的是工具执行：`request.tool_call` 里存着工具名与参数，可以在调用前后读取和改写。先定义一个带 `is_forcast` 参数的天气工具：

```python
from typing import Any
from langchain_core.tools import tool
from langchain_core.messages import ToolMessage
from langgraph.types import Command
from langgraph.prebuilt.tool_node import ToolCallRequest
from langchain.agents.middleware import wrap_tool_call

@tool
def get_weather(city: str, is_forcast: bool) -> str:
    """
    获取当日特定城市的天气

    Args:
        city: 城市名称
        is_forcast: 是否包含明天的天气预报
    """
    res = f"{city}今天天气不错"
    if is_forcast:
        res += "\n明天天气也很好"
    return res
```

再包装工具调用。注意这里调用了两次 `handler`：第一次用模型给的参数，第二次把 `is_forcast` 强制改成 `True` 后重新执行：

```python
@wrap_tool_call
def wrap_tool_call_middleware(
    request: ToolCallRequest,
    handler: Callable[[ToolCallRequest], ToolMessage | Command[Any]],
) -> ToolMessage | Command[Any]:
    result = handler(request)
    print(f"原始参数：{request.tool_call['args']}")
    print(f"原始参数调用结果：{result}")

    request.tool_call["args"]["is_forcast"] = True
    result = handler(request)

    print(f"更新以后的参数：{request.tool_call['args']}")
    print(f"更新以后的参数调用结果：{result}")
    return result

agent = create_agent(
    model=model,
    tools=[get_weather],
    middleware=[wrap_tool_call_middleware],
)

response = agent.invoke({"messages": [HumanMessage("帮我查询北京今天的天气如何？")]})
```

输出（关键部分）：

```
原始参数：{'city': '北京', 'is_forcast': False}
原始参数调用结果：content='北京今天天气不错'
更新以后的参数：{'city': '北京', 'is_forcast': True}
更新以后的参数调用结果：content='北京今天天气不错\n明天天气也很好'
Tool Calls: get_weather
  Args: city: 北京, is_forcast: True
Tool Message: 北京今天天气不错
明天天气也很好
```

## 三、基于类的实现

> 类写法复用装饰器示例中的 `model`、`get_weather` 等上下文。

### wrap_model_call

把同样的逻辑放进 `AgentMiddleware` 的子类并重写 `wrap_model_call`，实例化后放进 `middleware` 列表即可。

```python
from langchain.agents.middleware import AgentMiddleware

class WrapModelCallMiddleware(AgentMiddleware):
    def wrap_model_call(
        self,
        request: ModelRequest,
        handler: Callable[[ModelRequest], ModelResponse],
    ) -> ModelResponse | None:
        request.messages[-1].content += "---> wrap_model_call_before <---"

        # 模型的调用
        response = handler(request)

        response.result[0].content += "---> wrap_model_call_after <---"

        return response

agent = create_agent(
    model=model,
    middleware=[WrapModelCallMiddleware()],
)
```

执行效果与装饰器写法一致。

### wrap_tool_call

```python
class WrapToolCallMiddleware(AgentMiddleware):
    def wrap_tool_call(
        self,
        request: ToolCallRequest,
        handler: Callable[[ToolCallRequest], ToolMessage | Command[Any]],
    ) -> ToolMessage | Command[Any]:
        result = handler(request)
        print(f"原始参数：{request.tool_call['args']}")
        print(f"原始参数调用结果：{result}")

        request.tool_call["args"]["is_forcast"] = True
        result = handler(request)

        print(f"更新以后的参数：{request.tool_call['args']}")
        print(f"更新以后的参数调用结果：{result}")
        return result

agent = create_agent(
    model=model,
    tools=[get_weather],
    middleware=[WrapToolCallMiddleware()],
)
```

## 四、使用要点

- **必须调用 `handler`**：它是真正的模型/工具调用入口，不调用就等于拦截并中断本次调用。
- **改请求在调用前**：`wrap_model_call` 改 `request.messages`，`wrap_tool_call` 改 `request.tool_call["args"]`。
- **改响应在调用后**：`wrap_model_call` 改 `response.result[0].content`。
- **可以多次调用 `handler`**：例如改写参数后重跑、失败重试，这正是 Wrap-style 适合控制流的原因。
- 与 Node-style 的分工：Node-style 在固定节点插入逻辑，Wrap-style 包住调用本身，能拿到「调用前 / 调用后」两个时机。

## 五、两种写法怎么选

- 中间件只用一个钩子函数，推荐用装饰器；需要多个钩子函数推荐类写法
- 复杂配置推荐用类实现
- 跨项目复用推荐用类写法

## 六、执行顺序

`wrap_*` 钩子是**洋葱结构**：排在前面的包裹后面的；进入时先执行外层的前置逻辑，返回时先执行内层的后置逻辑。

```python
agent = create_agent(
    model=model,
    middleware=[
        wrap_model_middleware2,
        wrap_model_middleware3,
        wrap_model_middleware1,
    ]
)

"""
进入：w2 -> w3 -> w1 -> 模型调用
返回：w1 -> w3 -> w2
"""
```

## 参考信息

- [[2026-10-11-AI知识地图]] — 学习路径中的位置：知识地图「第五步：应用开发」
- [[2026-10-19-LangChainNode-style钩子]] — 上游：Node-style 钩子的分类与用法在该篇
