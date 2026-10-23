---
tags: [langchain, 静态上下文, 中间件, 工具调用]
description: 静态上下文 Runtime 的使用：在 Node-style/Wrap-style 钩子与 dynamic_prompt 中访问，以及在工具中访问。
---
# LangChain静态上下文
静态运行时上下文(Static runtime Context)表示不可变的数据，如用户元数据、工具和传递给应用程序的数据库连接对象。通常在运行开始时通过 invoke / stream 的 context 参数传递，此类数据在运行期间不会更改。

## 4.1 中间件中访问

### 4.1.1 Node-style hooks

此类钩子都通过runtime.context 访问上下文对象。

用户自定义ContextSchema 用@dataclass 修饰，在Agent创建时通过state_schema 参数传递。

本例从长期记忆中查询用户额度，如果额度用尽则中断流程。

代码

```python
from dataclasses import dataclass
from typing import Any
from langchain.agents import create_agent
from langchain.agents.middleware import AgentMiddleware, AgentState, hook_config
from langchain.messages import AIMessage
from langgraph.runtime import Runtime
from langgraph.store.memory import InMemoryStore
from dotenv import load_dotenv
from loguru import logger

load_dotenv()
store = InMemoryStore()
namespace = ("users", "credits")
key1 = "Ada Lovelace"
value1 = {"tokens_credit_left": 5000, "user_level": 5}
key2 = "Blackwell"
value2 = {"tokens_credit_left": 2999, "user_level": 5}
key3 = "Ampere"
value3 = {"tokens_credit_left": 1000, "user_level": 5}
store.put(namespace, key1, value1)
store.put(namespace, key2, value2)
store.put(namespace, key3, value3)


@dataclass
class UserContext:
    username: str


class CheckCredit(AgentMiddleware):
    @hook_config(can_jump_to=["end"])
    def before_model(
        self, state: AgentState, runtime: Runtime
    ) -> dict[str, Any] | None:
        store = runtime.store
        context = runtime.context
        username = context.username
        credit = store.get(namespace, username)
        if not credit:
            return {"jump_to": "end", "messages": AIMessage("您尚未注册~")}
        if credit.value["tokens_credit_left"] < 3000:
            return {
                "jump_to": "end",
                "messages": AIMessage(f"{username}额度不足，请充值"),
            }
        return None

    def after_model(self, state: AgentState, runtime: Runtime) -> dict[str, Any] | None:
        store = runtime.store
        context = runtime.context
        username = context.username
        credit = store.get(namespace, username)
        usage_metadata = state["messages"][-1].usage_metadata
        token_usage = (
            usage_metadata["input_tokens"] + usage_metadata["output_tokens"] * 6
        )
        credit.value["tokens_credit_left"] -= token_usage
        # 更新长期记忆
        store.put(namespace, username, credit.value)
        return None

    def after_agent(self, state: AgentState, runtime: Runtime) -> dict[str, Any] | None:
        store = runtime.store
        context = runtime.context
        username = context.username
        item = store.get(namespace, username)
        credit = item.value["tokens_credit_left"]
        logger.info(f"{username} 当前剩余额度：{credit}")
        return None


agent = create_agent(
    model="deepseek-chat",
    middleware=[CheckCredit()],
    store=store,
    context_schema=UserContext,
)
response1 = agent.invoke(
    {"messages": ["你好啊，你知道 Ada Lovelace 的贡献吗？"]},
    context=UserContext(username="Ada Lovelace"),
)
print("=" * 30, "-> Ada Lovelace messages <-", "=" * 30)
for msg in response1["messages"]:
    msg.pretty_print()
response2 = agent.invoke(
    {"messages": ["你好啊，你知道 Blackwell 的贡献吗？"]},
    context=UserContext(username="Blackwell"),
)
print("=" * 30, "-> Blackwell messages <-", "=" * 30)
for msg in response2["messages"]:
    msg.pretty_print()
```

输出

```text
•[32m2026-04-14 11:39:18.876•[0m | •[1mINFO    •[0m |
•[36m__main__•[0m:•[36mafter_agent•[0m:•[36m85•[0m - •[1mAda Lovelace 当前剩余额度：2721•[0m
•[32m2026-04-14 11:39:18.881•[0m | •[1mINFO    •[0m |
•[36m__main__•[0m:•[36mafter_agent•[0m:•[36m85•[0m - •[1mBlackwell 当前剩余额度：2999•[0m
```

```text
============================== -> Ada Lovelace messages <-
================================•[1m Human Message
•[0m=================================
你好啊，你知道 Ada Lovelace 的贡献吗？
==================================•[1m Ai Message
•[0m==================================
是的，Ada Lovelace（1815-1852）被广泛认为是世界上第一位计算机程序员，她的贡献主要
体现在以下几个方面：
---
### **1. 翻译与注释：解析“分析机”的潜力**
- 1843年，她翻译了意大利工程师路易吉·费德里科·米纳布里关于查尔斯·巴贝奇“分析机”（早
期机械通用计算机）的论文，并添加了大量自己的注释，篇幅远超原文。
- 她的注释中包含了**世界上第一个计算机算法**，用于计算伯努利数，这被视为最早的“计算
机程序”概念。
---
### **2. 超越计算的前瞻性思想**
- 她指出分析机不仅限于数值计算，还能处理符号、音乐甚至艺术，预见了计算机的**通用性**
和**创造性潜力**。
- 她强调“机器只能执行指令，不能自主思考”，区分了人工智能与人类智能的界限。
---
### **3. 技术与人文的桥梁**
- 作为诗人拜伦的女儿，她将数学逻辑与想象力结合，主张科技与艺术的融合，这一思想对后世
计算科学影响深远。
---
### **4. 历史意义**
- 尽管分析机在她有生之年未能建成，但她的工作在一个世纪后启发了艾伦·图灵等计算机科学先
驱。
- 1980年，美国国防部将一种编程语言命名为“Ada”以纪念她。
---
### **争议与澄清**
- 部分学者认为她的贡献被过度神话，但主流观点仍肯定她首次系统阐述了编程逻辑的核心思
想，尤其在19世纪女性科学参与受限的背景下，她的成就尤为突出。
---
Ada Lovelace 的故事不仅是技术史上的里程碑，也象征着跨学科创新如何推动人类认知边界。
如果需要更具体的细节，我可以进一步展开！
============================== -> Blackwell messages <-
================================•[1m Human Message
•[0m=================================
你好啊，你知道 Blackwell 的贡献吗？
==================================•[1m Ai Message
•[0m==================================
Blackwell额度不足，请充值
```

### 4.1.2 Wrap-style hooks

① wrap_model_call

本例通过 context 中记录的用户身份信息调整暴露给模型的工具集。

此处更改模型请求的方法是 transient request update ，见上文短期记忆 2-4-2

```python
from dataclasses import dataclass
from typing import Callable
from langchain.agents import create_agent
from langchain.agents.middleware import AgentMiddleware, ModelResponse, ModelRequest
from langchain.messages import AIMessage
from langchain.tools import tool
from langgraph.store.memory import InMemoryStore
from dotenv import load_dotenv
from loguru import logger

load_dotenv()
store = InMemoryStore()
namespace = ("users", "credits")
key1 = "Ada Lovelace"
value1 = {
    "tokens_left": 3000,  # 剩余大模型token额度
    "get_weather": "yes",  # 是否认证天气查询服务
    "get_news": "no",  # 是否认证网络爬虫服务，用于查询新闻
}
key2 = "Blackwell"
value2 = {
    "tokens_left": 2000,  # 剩余大模型token额度
    "get_weather": "no",  # 是否认证天气查询服务
    "get_news": "yes",  # 是否认证网络爬虫服务，用于查询新闻
}
key3 = "Ampere"
value3 = {
    "tokens_left": 3000,  # 剩余大模型token额度
    "get_weather": "yes",  # 是否认证天气查询服务
    "get_news": "yes",  # 是否认证网络爬虫服务，用于查询新闻
}
store.put(namespace, key1, value1)
store.put(namespace, key2, value2)
store.put(namespace, key3, value3)


@tool
def get_weather(city: str):
    """
    查询指定城市当日天气
    Args:
        city: 城市名称
    """
    return f"{city} 今天天气不错"


@tool()
def get_news():
    """查询当日新闻"""
    return "美伊尚未达成停战协议"


@dataclass
class UserContext:
    username: str


class CheckCredit(AgentMiddleware):
    def wrap_model_call(
        self,
        request: ModelRequest,
        handler: Callable[[ModelRequest], ModelResponse],
    ) -> ModelResponse:
        context = request.runtime.context
        store = request.runtime.store
```
```text
        value = store.get(namespace, context.username).value tools = []
        for tool in request.tools:
            tool_name = tool.name
            if value[tool_name] == "yes":
                tools.append(tool)
            else:
                logger.warning(f"{context.username} 无权调用 {tool_name}") # 更改调用请求携带的工具集，仅本次生效
        request = request.override(tools=tools)
        return handler(request)
agent = create_agent(
    model="deepseek-chat",
    middleware=[CheckCredit()],
    tools=[get_weather, get_news],
    store=store,
    context_schema=UserContext
)
response1 = agent.invoke(
    {"messages": ["你好啊，今天北京天气如何，今日有哪些新闻？"]},
    context=UserContext(username="Ada Lovelace")
)
print("=" * 30, '-> Ada Lovelace messages <-', '=' * 30)
for msg in response1["messages"]:
    msg.pretty_print()
response2 = agent.invoke(
    {"messages": ["你好啊，今天北京天气如何，今日有哪些新闻？"]},
    context=UserContext(username="Blackwell")
)
print("=" * 30, '-> Blackwell messages <-', '=' * 30)
for msg in response2["messages"]:
    msg.pretty_print()
response3 = agent.invoke(
    {"messages": ["你好啊，今天北京天气如何，今日有哪些新闻？"]},
    context=UserContext(username="Ampere")
)
print("=" * 30, '-> Ampere messages <-', '=' * 30)
for msg in response3["messages"]:
    msg.pretty_print()
```

输出

```text
•[32m2026-04-14 11:40:07.527•[0m | •[33m•[1mWARNING •[0m |
•[36m__main__•[0m:•[36mwrap_model_call•[0m:•[36m75•[0m - •[33m•[1mAda
Lovelace 无权调用 get_news•[0m
•[32m2026-04-14 11:40:11.357•[0m | •[33m•[1mWARNING •[0m |
•[36m__main__•[0m:•[36mwrap_model_call•[0m:•[36m75•[0m - •[33m•[1mAda
Lovelace 无权调用 get_news•[0m
•[32m2026-04-14 11:40:15.049•[0m | •[33m•[1mWARNING •[0m |
•[36m__main__•[0m:•[36mwrap_model_call•[0m:•[36m75•[0m -
•[33m•[1mBlackwell 无权调用 get_weather•[0m
```

```text
============================== -> Ada Lovelace messages <-
================================•[1m Human Message
•[0m=================================
你好啊，今天北京天气如何，今日有哪些新闻？
==================================•[1m Ai Message
•[0m==================================
我来帮您查询北京的天气情况。不过关于今日新闻，我目前没有相关的查询功能。
Tool Calls:
get_weather (call_00_OplicbLHGEaTanH3yaTDuiMp)
Call ID: call_00_OplicbLHGEaTanH3yaTDuiMp
Args:
 city: 北京
=================================•[1m Tool Message
•[0m=================================
Name: get_weather
北京 今天天气不错
==================================•[1m Ai Message
•[0m==================================
根据查询结果，北京今天天气不错！
关于今日新闻，我目前无法为您提供实时的新闻信息。您可以：
1. 查看各大新闻网站或新闻应用
2. 关注官方新闻发布平台
3. 使用专门的新闻查询工具
如果您需要了解其他城市的天气情况，我很乐意为您查询。
•[32m2026-04-14 11:40:17.903•[0m | •[33m•[1mWARNING •[0m |
•[36m__main__•[0m:•[36mwrap_model_call•[0m:•[36m75•[0m -
•[33m•[1mBlackwell 无权调用 get_weather•[0m
============================== -> Blackwell messages <-
================================•[1m Human Message
•[0m=================================
你好啊，今天北京天气如何，今日有哪些新闻？
==================================•[1m Ai Message
•[0m==================================
我目前无法查询天气信息，不过我可以帮您查询今天的新闻。让我为您获取一下今日的新闻内容。
Tool Calls:
  get_news (call_00_thc8aLWFXkeffY1vafIwMJLk)
 Call ID: call_00_thc8aLWFXkeffY1vafIwMJLk
  Args:
=================================•[1m Tool Message
•[0m=================================
Name: get_news
美伊尚未达成停战协议
==================================•[1m Ai Message
•[0m==================================
根据查询结果，今天有一条重要新闻：**美伊尚未达成停战协议**。
关于北京的天气情况，我目前无法为您提供实时天气信息。建议您可以通过以下方式获取准确的北
京天气信息：
1. 查看天气预报应用或网站
2. 使用搜索引擎搜索"北京天气"
3. 查看手机自带的天气应用
如果您还想了解其他新闻或者有其他问题，我很乐意为您提供帮助！
============================== -> Ampere messages <-
================================•[1m Human Message
•[0m=================================
你好啊，今天北京天气如何，今日有哪些新闻？
==================================•[1m Ai Message
•[0m==================================
我来帮您查询北京的天气和今日新闻。
Tool Calls:
  get_weather (call_00_ZyVpPMawPgdFdv49ojD3zIFt)
 Call ID: call_00_ZyVpPMawPgdFdv49ojD3zIFt
  Args:
    city: 北京
  get_news (call_01_kZaouXjSdhjrJGmzGWRbP3so)
 Call ID: call_01_kZaouXjSdhjrJGmzGWRbP3so
  Args:
=================================•[1m Tool Message
•[0m=================================
Name: get_weather
北京 今天天气不错
=================================•[1m Tool Message
•[0m=================================
Name: get_news
美伊尚未达成停战协议
==================================•[1m Ai Message
•[0m==================================
根据查询结果：
**北京天气：**
今天北京天气不错。
**今日新闻：**
- 美伊尚未达成停战协议
如果您需要更详细的天气信息（比如具体温度、湿度等）或者想了解其他新闻，请告诉我！
```

② wrap_tool_call

在上述案例的基础上，我们补充额度校验，和长期记忆更新。

```python
from dataclasses import dataclass
from typing import Callable, Any
from langchain.agents import create_agent
from langchain.agents.middleware import (
    AgentMiddleware,
    ModelResponse,
    ModelRequest,
    ToolCallRequest,
)
from langchain.messages import AIMessage, ToolMessage
from langchain.tools import tool
from langgraph.store.memory import InMemoryStore
from langgraph.types import Command
from dotenv import load_dotenv
from loguru import logger

load_dotenv()
store = InMemoryStore()
namespace = ("users", "credits")
key1 = "Ada Lovelace"
```
```text
value1 = {
    "tokens_left": 3000,  # 剩余大模型token额度
    "get_weather": "yes",  # 是否认证天气查询服务
    "get_news": "no"  # 是否认证网络爬虫服务，用于查询新闻 }
key2 = 'Blackwell'
value2 = {
    "tokens_left": 2000,  # 剩余大模型token额度
    "get_weather": "no",  # 是否认证天气查询服务
    "get_news": "yes"  # 是否认证网络爬虫服务，用于查询新闻 }
key3 = 'Ampere'
value3 = {
    "tokens_left": 3000,  # 剩余大模型token额度
    "get_weather": "yes",  # 是否认证天气查询服务
    "get_news": "yes"  # 是否认证网络爬虫服务，用于查询新闻 }
store.put(namespace, key1, value1)
store.put(namespace, key2, value2)
store.put(namespace, key3, value3)
# 工具额度消耗
CREDIT_MAP = {
    "get_weather": 10,
    "get_news": 20
}
@tool
def get_weather(city: str):
    """
    查询指定城市当日天气
    Args:
        city: 城市名称
    """
    return f"{city} 今天天气不错"
@tool()
def get_news():
    """查询当日新闻"""
    return "美伊尚未达成停战协议"
@dataclass
class UserContext:
    username: str
class CheckCredit(AgentMiddleware):
    def wrap_model_call(
        self,
        request: ModelRequest,
        handler: Callable[[ModelRequest], ModelResponse],
    ) -> ModelResponse:
        context = request.runtime.context
        store = request.runtime.store
        value = store.get(namespace, context.username).value
        tools = []
        for tool in request.tools:
            tool_name = tool.name
            if value[tool_name] == "yes":
                tools.append(tool)
            else:
                logger.warning(f"{context.username} 无权调用 {tool_name}") # 更改调用请求携带的工具集，仅本次生效
        request = request.override(tools=tools)
        return handler(request)
class ToolGuard(AgentMiddleware):
    def wrap_tool_call(
        self,
        request: ToolCallRequest,
        handler: Callable[[ToolCallRequest], ToolMessage | Command[Any]], ) -> ToolMessage | Command[Any]:
        store = request.runtime.store
        context = request.runtime.context
        username = context.username
        value = store.get(namespace, username).value
        tool_name = request.tool.name
        # 本次调用花费
        credits_cost = CREDIT_MAP.get(tool_name)
        # 剩余额度
        credits_left = value["tokens_left"]
        if credits_left < credits_cost:
            logger.warning(f"{username} 额度不足，{tool_name} 调用失败！")
            return Command(
                update={
                    "messages": [
                        ToolMessage(
                            content="额度不足，无法调用工具，请充值~",
                            tool_call_id=request.runtime.tool_call_id
                        )
                    ]
                }
            )
        # 更新剩余额度
        credits_left -= credits_cost
        value["tokens_left"] = credits_left
        store.put(namespace, username, value)
        logger.info(f"{username} 调用 {tool_name} 花费 {credits_cost}，剩余额度 {credits_left}")
        logger.info(f"{username} 状态已更新，当前状态 {store.get(namespace,
username).value}")
        return handler(request)
agent = create_agent(
    model="deepseek-chat",
    middleware=[CheckCredit(), ToolGuard()],
    tools=[get_weather, get_news],
    store=store,
    context_schema=UserContext
)
response = agent.invoke(
    {"messages": ["你好啊，今天北京天气如何，今日有哪些新闻？"]},
    context=UserContext(username="Ada Lovelace")
)
print("=" * 30, '-> Ada Lovelace messages <-', '=' * 30)
for msg in response["messages"]:
    msg.pretty_print()
```

输出

```text
•[32m2026-04-14 11:41:20.386•[0m | •[33m•[1mWARNING •[0m |
•[36m__main__•[0m:•[36mwrap_model_call•[0m:•[36m82•[0m - •[33m•[1mAda
Lovelace 无权调用 get_news•[0m
•[32m2026-04-14 11:41:23.859•[0m | •[1mINFO    •[0m |
•[36m__main__•[0m:•[36mwrap_tool_call•[0m:•[36m124•[0m - •[1mAda
Lovelace 调用 get_weather 花费 10，剩余额度 2990•[0m
•[32m2026-04-14 11:41:23.860•[0m | •[1mINFO    •[0m |
•[36m__main__•[0m:•[36mwrap_tool_call•[0m:•[36m125•[0m - •[1mAda
Lovelace 状态已更新，当前状态 {'tokens_left': 2990, 'get_weather': 'yes',
'get_news': 'no'}•[0m
•[32m2026-04-14 11:41:23.865•[0m | •[33m•[1mWARNING •[0m |
•[36m__main__•[0m:•[36mwrap_model_call•[0m:•[36m82•[0m - •[33m•[1mAda
Lovelace 无权调用 get_news•[0m
```

```text
============================== -> Ada Lovelace messages <-
================================•[1m Human Message
•[0m=================================
你好啊，今天北京天气如何，今日有哪些新闻？
==================================•[1m Ai Message
•[0m==================================
我来帮您查询北京的天气情况。不过需要说明的是，我目前只能查询天气信息，无法提供新闻资
讯。
Tool Calls:
get_weather (call_00_HY2jENXsRyK21gITiQqeVSk9)
Call ID: call_00_HY2jENXsRyK21gITiQqeVSk9
Args:
 city: 北京
=================================•[1m Tool Message
•[0m=================================
Name: get_weather
北京 今天天气不错
==================================•[1m Ai Message
•[0m==================================
根据查询结果，北京今天天气不错。
关于新闻资讯，我目前没有相关的查询功能。如果您想了解今日新闻，建议您：
1. 查看主流新闻网站或APP
2. 关注官方新闻媒体
3. 使用专门的新闻搜索工具
如果您还需要了解其他城市的天气情况，我很乐意为您查询。
```

### 4.1.3 特殊的便捷中间件dynamic_prompt

如前所述，@dynamic_prompt底层实现机制和通用钩子函数是统一的，对于动态提示词处理提供了更加便捷的入口。

本例通过静态上下文中携带的用户信息，动态更改系统提示词。

```python
from dataclasses import dataclass
from langchain.agents import create_agent
from langchain.agents.middleware import dynamic_prompt, ModelRequest
from langgraph.store.memory import InMemoryStore
from dotenv import load_dotenv
from loguru import logger

load_dotenv()
# 准备历史记忆
namespace = ("users", "preferences")
key1 = "Ada Lovelace"
value1 = {"chat_preferences": ["不喜欢啰嗦", "尽可能用最精简的文字解释清楚"]}
key2 = "Blackwell"
value2 = {
    "chat_preferences": [
        "喜欢长篇大论、引经据典",
        "不知道的东西要明确说'不知道'，不能胡编乱造",
    ]
}
store = InMemoryStore()
store.put(namespace, key1, value1)
store.put(namespace, key2, value2)


@dataclass
class UserContext:
    username: str


@dynamic_prompt
def personalized_prompt(request: ModelRequest) -> str:
    username = request.runtime.context.username
    store = request.runtime.store
```
```text
    preferences = store.get(namespace, username).value["chat_preferences"] custom_prompt = f"# 用户偏好\n{'\n'.join(preferences)}"
    logger.info(f"{username} 自定义系统提示词\n{custom_prompt}")
    return custom_prompt
agent = create_agent(
    model="deepseek-chat",
    middleware=[personalized_prompt],
    store=store,
    context_schema=UserContext
)
response1 = agent.invoke(
    {"messages": ["为什么花儿这样红？"]},
    context=UserContext(username="Ada Lovelace")
)
print("=" * 30, '-> Ada Lovelace messages <-', '=' * 30)
for msg in response1["messages"]:
    msg.pretty_print()
response2 = agent.invoke(
    {"messages": ["为什么花儿这样红？"]},
    context=UserContext(username="Blackwell")
)
print("=" * 30, '-> Blackwell messages <-', '=' * 30)
for msg in response2["messages"]:
    msg.pretty_print()
```

输出

```text
•[32m2026-04-14 11:44:10.784•[0m | •[1mINFO    •[0m |
•[36m__main__•[0m:•[36mpersonalized_prompt•[0m:•[36m44•[0m - •[1mAda
Lovelace 自定义系统提示词
# 用户偏好
```

不喜欢啰嗦

```text
尽可能用最精简的文字解释清楚•[0m
•[32m2026-04-14 11:44:13.622•[0m | •[1mINFO    •[0m |
•[36m__main__•[0m:•[36mpersonalized_prompt•[0m:•[36m44•[0m -
•[1mBlackwell 自定义系统提示词
# 用户偏好
```

喜欢长篇大论、引经据典

```text
不知道的东西要明确说'不知道'，不能胡编乱造•[0m
```

```text
============================== -> Ada Lovelace messages <-
================================•[1m Human Message
•[0m=================================
为什么花儿这样红？
==================================•[1m Ai Message
•[0m==================================
花儿红的主要原因是花瓣细胞中的**花青素**在酸性环境下显红色，同时受光照、温度、养分等
影响，为吸引传粉者进化而成。
============================== -> Blackwell messages <-
================================•[1m Human Message
•[0m=================================
为什么花儿这样红？
==================================•[1m Ai Message
•[0m==================================
“为什么花儿这样红”这一问题，可以从科学、文学、文化等多个维度展开探讨。以下将从不同角
度进行详细分析，力求全面而深入。
---
### **一、科学视角：色彩形成的自然机制**
花朵的红色主要源于植物色素、光学结构以及进化适应性的共同作用。
1. **色素基础：花青素的主导作用**
   - 花青素（Anthocyanin）是形成红、紫、蓝等颜色的关键色素，属于类黄酮化合物。它在
不同酸碱度（pH）下呈现颜色变化：酸性环境中偏红（如玫瑰、牡丹），中性时呈紫色，碱性环
境中则偏蓝。
   - 其他色素如类胡萝卜素（橙黄色）和甜菜色素（少数植物如仙人掌）也可能与红色相关，但
花青素是最常见的红色来源。
2. **光学与结构增色**
   - 部分花朵的红色并非单纯依赖色素，而是通过花瓣表面的微观结构（如多层薄膜、衍射光
栅）反射特定波长的光，增强色彩饱和度。例如红罂粟的花瓣具有蜂窝状结构，能强化红色视觉效
果。
3. **进化与生态学意义**
   - **传粉者吸引**：红色对许多传粉昆虫（如蜜蜂）可见度较低，但对鸟类（如蜂鸟）和部
分蝶类极具吸引力。在美洲、亚洲等地区，红色花朵常与鸟媒传粉相关。
   - **环境适应**：花青素可抵御紫外线伤害、抵抗病原体，并在低温或干旱条件下保护植物
细胞。高海拔地区的红花比例较高，可能与紫外线防护有关。
---
### **二、文学与艺术中的象征意义**
红色在人类文化中被赋予丰富内涵，花朵的红色常成为情感与哲思的载体。
1. **爱情与激情**
   - 红玫瑰在西方传统中象征炽热爱情，可追溯至希腊罗马神话中维纳斯与阿多尼斯的故事，玫
瑰的红色被联想为爱神之血。波斯诗人萨迪在《蔷薇园》中亦以玫瑰隐喻激情。
2. **生命、牺牲与革命**
   - 中国文学中，红色梅花、杜鹃常被赋予坚贞或壮烈的意象（如“杜鹃啼血”）。近现代以
来，红色花朵亦与革命精神关联，如《红岩》中的红梅象征烈士鲜血。
3. **美学与哲学隐喻**
   - 王阳明在《传习录》中提及“岩中花树”，探讨心与物的关系；歌德在《色彩论》中分析红
色对情感的影响。红色花朵的视觉冲击力，常引发对生命短暂与绚烂的思考（如日本“物哀”美学
中的樱花）。
---
### **三、文化差异与历史演变**
不同文明对红色花朵的解读存在显著差异：
1. **东方文化**
   - 中国：红色象征吉祥、喜庆，牡丹被称为“国色天香”，红色牡丹尤其代表富贵。但李贺诗
句“桃花乱落如红雨”亦暗含哀愁。
   - 日本：红椿花在江户时代被赋予“谦逊”与“永恒”之意，但亦因整朵凋落的特点与武士精神
关联。
2. **西方文化**
   - 基督教艺术中，红色玫瑰象征殉道者的鲜血与神圣之爱（如但丁《神曲》中天堂的玫瑰）。
   - 近代欧洲，红罂粟因一战战场盛放，成为纪念阵亡将士的符号（如约翰·麦克雷诗作《在弗
兰德战场》）。
---
### **四、现代科学的新发现**
近年研究进一步揭示了花朵红色的复杂性：
- **基因调控**：MYB转录因子等基因可精确控制花青素合成，通过基因工程已培育出深浅各异
的红色花卉。
- **气候响应**：全球变暖可能导致花朵颜色加深，因高温促进花青素积累（2020年《生态学通
讯》研究）。
- **传粉者视觉模型**：蜂鸟对红色的偏好与其视网膜中特殊色素细胞（油滴滤光）相关，这解
释了美洲红色花与蜂鸟的协同进化。
---
### **结语**
“花儿这样红”既是自然选择的精巧结果，也是人类文明的情感投射。从花青素的生物化学路径到
《诗经》中的“桃之夭夭”，从达尔文对传粉生态的观察到现代基因图谱的解析，这一问题串联起
了科学与人文的对话。红色花朵的绚丽，最终在观察者的眼中完成了自然法则与心灵共鸣的统一。
**参考文献方向**（如需进一步研究可查阅）：
- 植物生理学：《植物生物化学与分子生物学》（B.B. Buchanan等编著）
- 文化象征：《花的语言》（Jack Goody，人类学著作）
- 进化生态学：《花的起源与多样性》（昆虫传粉协同进化理论）
```

dynamic_prompt 是动态更新本次调用前的系统提示词，并不会更改消息列表，所以根据模型输出，可以发现系统提示词生效，但消息列表看不到相关提示词。

## 4.2 工具中访问

在上文介绍工具的自定义args_schema时我们介绍了两种方式：

+ 基于pydantic模型
+ 基于json_schema

实际上，Langchain底层在生成工具的schema时，如果参数类型注解是pydantic模型，也会被一并解析。

```python
from pydantic import BaseModel, Field
from typing import List
from langchain.tools import tool
from langgraph.prebuilt.tool_node import ToolRuntime
```
```text
from langchain_core.utils.function_calling import convert_to_openai_tool class UserInfo(BaseModel):
    username: str = Field(description="用户名")
    age: int = Field(description="年龄")
    hobbies: List[str] = Field(description="兴趣爱好")
@tool(parse_docstring=True)
def save_user_info(user_info: UserInfo, runtime: ToolRuntime) -> str:
    """
    保存用户信息
    Args:
        user_info: 用户信息对象
    """
    return "ok"
print(convert_to_openai_tool(save_user_info))
```

输出如下

```text
{
    "type": "function",
    "function": {
        "name": "save_user_info",
        "description": "保存用户信息",
        "parameters": {
            "properties": {
                "user_info": {
                    "properties": {
                        "username": {
                            "description": "用户名",
                            "type": "string"
                        },
                        "age": {
                            "description": "年龄",
                            "type": "integer"
                        },
                        "hobbies": {
                            "description": "兴趣爱好",
                            "items": {
                                "type": "string"
                            },
                            "type": "array"
                        }
                    },
                    "required": [
                        "username",
                        "age",
                        "hobbies"
                    ],
                    "type": "object",
                    "description": "用户信息对象"
                }
            },
            "required": [
                "user_info"
            ],
            "type": "object"
        }
    }
}
```

下面的案例中，我们通过工具读写长期记忆中保存的用户信息

```python
from pydantic import BaseModel, Field
from typing import List, Any
from dataclasses import dataclass
from langchain.agents import create_agent
from langchain.tools import tool
from langchain.messages import HumanMessage, SystemMessage
from langgraph.prebuilt.tool_node import ToolRuntime
from langgraph.store.memory import InMemoryStore
from langgraph.checkpoint.memory import InMemorySaver
from loguru import logger
from dotenv import load_dotenv

load_dotenv()


@dataclass
class UserContext:
    user_id: str


store = InMemoryStore()
namespace = ("users", "user_info")


class UserInfo(BaseModel):
    username: str = Field(description="用户名", default="unknown")
    age: int = Field(description="年龄", default=0)
    # 这里相当于告诉模型，每次创建新实例时，调用list()创建一个新的list传进去
    hobbies: List[str] = Field(
        description="兴趣爱好", default_factory=list
    )  # 这种写法是用可变对象做默认值，会有多个对象共享一个列表对象的风险
    # hobbies: List[str] = Field(description="兴趣爱好", default=[])


@tool(parse_docstring=True)
def read_user_info(runtime: ToolRuntime[UserContext, Any]) -> UserInfo | str:
    """
    读取用户信息
    Returns:
        UserInfo | str: 如果找到用户信息，返回 UserInfo 对象；否则返回空字符串。
    """
    user_id = runtime.context.user_id
    store = runtime.store
    item = store.get(namespace, user_id)
    if item:
        return UserInfo(**item.value)
    return ""


@tool(parse_docstring=True)
def write_user_info(
    user_info: UserInfo, runtime: ToolRuntime[UserContext, Any]
) -> bool:
    """
    将用户信息写入长期记忆
    Args:
        user_info：用户信息对象
    Returns:
        bool: 如果成功写入则返回True，否则返回False
    """
    user_id = runtime.context.user_id
    store = runtime.store
    try:
        logger.info(
            f"写入记忆, namespace: {namespace}, user_id: {user_id}, user_info: {user_info.model_dump()}"
        )
        store.put(namespace, user_id, user_info.model_dump())
    except Exception as e:
        logger.error(e)
        return False
    return True


agent = create_agent(
    model="deepseek-chat",
    tools=[read_user_info, write_user_info],
    store=store,
    checkpointer=InMemorySaver(),
    context_schema=UserContext,
)
config1 = {"configurable": {"thread_id": "thread_1"}}
config2 = {"configurable": {"thread_id": "thread_2"}}
agent.invoke(
    {
        "messages": [
            SystemMessage(
                "如果输入包含用户信息，抽取并调用工具记录。在记录之前先查找历史信息，和新增信息合并后记录。"
                "如果用户提问设计个人信息，调用工具查找"
            ),
            HumanMessage("你好，我是韩立，我喜欢修仙"),
        ]
    },
    context=UserContext(user_id="user_1"),
    config=config1,
)
thread_1_response = agent.invoke(
    {"messages": ["我今年两百岁了，是你们口中的 “元婴老怪”，我喜欢跑步"]},
    context=UserContext(user_id="user_1"),
    config=config1,
)
print("=" * 30, "-> thread_1 messages <-", "=" * 30)
for msg in thread_1_response["messages"]:
    msg.pretty_print()
thread_2_response = agent.invoke(
    {"messages": ["你还记得我吗？"]},
    context=UserContext(user_id="user_1"),
    config=config2,
)
print("=" * 30, "-> thread_2 messages <-", "=" * 30)
for msg in thread_2_response["messages"]:
    msg.pretty_print()
```

输出

```text
•[32m2026-04-14 15:58:30.011•[0m | •[1mINFO    •[0m |
•[36m__main__•[0m:•[36mwrite_user_info•[0m:•[36m61•[0m - •[1m写入记忆,
namespace: ('users', 'user_info'), user_id: user_1, user_info:
{'username': '韩立', 'age': 0, 'hobbies': ['修仙']}•[0m
•[32m2026-04-14 15:58:41.439•[0m | •[1mINFO    •[0m |
•[36m__main__•[0m:•[36mwrite_user_info•[0m:•[36m61•[0m - •[1m写入记忆,
namespace: ('users', 'user_info'), user_id: user_1, user_info:
{'username': '韩立', 'age': 200, 'hobbies': ['修仙', '跑步']}•[0m
```

```text
============================== -> thread_1 messages <-
================================•[1m System Message
•[0m================================
如果输入包含用户信息，抽取并调用工具记录。在记录之前先查找历史信息，和新增信息合并后记
录。如果用户提问设计个人信息，调用工具查找
================================•[1m Human Message
•[0m=================================
你好，我是韩立，我喜欢修仙
==================================•[1m Ai Message
•[0m==================================
你好韩立！很高兴认识你。我看到你喜欢修仙，这是一个很有趣的爱好。
为了让我能更好地记住你的信息，让我先查看一下是否已经有你的历史记录。
Tool Calls:
read_user_info (call_00_DAqBrMPFS4iZVK5F7mvaOsBy)
Call ID: call_00_DAqBrMPFS4iZVK5F7mvaOsBy
Args:
=================================•[1m Tool Message
•[0m=================================
Name: read_user_info
==================================•[1m Ai Message
•[0m==================================
看起来目前还没有你的历史记录。让我记录一下你的基本信息：
Tool Calls:
write_user_info (call_00_Zoz8sLHivXkA0a0Py2yvDFJB)
Call ID: call_00_Zoz8sLHivXkA0a0Py2yvDFJB
Args:
 user_info: {'username': '韩立', 'hobbies': ['修仙']}
=================================•[1m Tool Message
•[0m=================================
Name: write_user_info
true
==================================•[1m Ai Message
•[0m==================================
好的，我已经记录了你喜欢修仙这个爱好。修仙确实是一个很有深度的领域，涉及到修炼、功法、
丹药、法宝等很多方面。你对修仙的哪个方面特别感兴趣呢？比如是修炼功法、炼丹术、阵法，还
是其他方面？
================================•[1m Human Message
•[0m=================================
我今年两百岁了，是你们口中的 “元婴老怪”，我喜欢跑步
==================================•[1m Ai Message
•[0m==================================
哇！两百岁的元婴老怪，这真是令人惊叹！看来您在修仙道路上已经走了很长的路。
让我更新一下您的信息，包括年龄和新的爱好——跑步。
Tool Calls:
read_user_info (call_00_I9AO3Y8RJSQLeHhwBGszkuiW)
Call ID: call_00_I9AO3Y8RJSQLeHhwBGszkuiW
Args:
=================================•[1m Tool Message
•[0m=================================
Name: read_user_info
username='韩立' age=0 hobbies=['修仙']
==================================•[1m Ai Message
•[0m==================================
现在我来更新您的完整信息：
Tool Calls:
write_user_info (call_00_3JpZC48aqJG7m0m6X2EnZFNH)
Call ID: call_00_3JpZC48aqJG7m0m6X2EnZFNH
Args:
 user_info: {'username': '韩立', 'age': 200, 'hobbies': ['修仙', '跑步']}
=================================•[1m Tool Message
•[0m=================================
Name: write_user_info
true
==================================•[1m Ai Message
•[0m==================================
很好！我已经更新了您的信息：
- 姓名：韩立
- 年龄：200岁
- 爱好：修仙、跑步
作为一位元婴期的前辈，您一定有着丰富的修炼经验和人生智慧。跑步这个爱好很有意思，对于修
仙者来说，这既是锻炼身体的好方法，也能让心境更加平和。您平时是在宗门内跑步，还是在山林
间奔跑呢？
============================== -> thread_2 messages <-
================================•[1m Human Message
•[0m=================================
你还记得我吗？
==================================•[1m Ai Message
•[0m==================================
我来查看一下之前记录的用户信息。
Tool Calls:
  read_user_info (call_00_iJgxeOZKvXCNYkRjX3EFGp8q)
 Call ID: call_00_iJgxeOZKvXCNYkRjX3EFGp8q
  Args:
=================================•[1m Tool Message
•[0m=================================
Name: read_user_info
username='韩立' age=200 hobbies=['修仙', '跑步']
==================================•[1m Ai Message
•[0m==================================
当然记得！你是韩立，200岁，喜欢修仙和跑步。很高兴再次见到你！最近修仙进展如何？还是经
常跑步锻炼吗？
```

分析

1. 前两次invoke通过相同的thread_id串联为一个会话，共享短期记忆

2. context是运行时静态配置，每次invoke互相独立

3. 长期记忆可以在任意位置访问，全局共享同一份信息

4. tool参数列表中的ToolRuntime是Langchain / Langgraph运行时注入的，在工具schema中没有体

+ 现

5. ToolRuntime的默认泛型是[None, Any]，第一个是Context的泛型，第二个是State对象的泛型。

+ 如果不显式指定上下文对象的类型，则Langchain/Langgraph底层会认为上下文对象为None，invoke调用时传递了context就会抛出警告，所以这里将UserContext作为ToolRuntime的第一个泛型传递。

## 参考信息

- [[2026-10-23-AI记忆与上下文知识地图]] — 学习路径中的位置：知识地图「4、课后阅读：Static runtime Context」
- [[2026-10-19-LangChain内置中间件]] — 关系类型：依赖：4.1 节的钩子实现依赖中间件体系
