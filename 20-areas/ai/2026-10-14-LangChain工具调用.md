---
tags: [langchain, 工具调用, agent, 示例代码]
description: LangChain 工具调用（Tool Calling）：@tool 定义工具、invoke 直接调用、bind_tools 绑定后由 AI 决定调用，以及 convert_to_openai_tool 查看解析后的工具描述。
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

## 参考信息

- [[2026-10-11-Agent开发与架构]] — 下游应用：工具调用是 Agent 五大核心要素中"工具使用（Tool Use）"的基础机制，LangGraph/Deep Agent 在其上构建更复杂编排。
- [[2026-10-14-LangChain消息与对话历史]] — 配套机制：AI 返回的 tool_calls 与工具执行结果都需追加进消息列表再回传模型。
- [[2026-10-11-LangChain框架]] — 框架概览：本篇属于 langchain-core 中 tools 模块的展开。
