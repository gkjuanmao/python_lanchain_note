---
tags: [langchain, 消息, 对话历史, 示例代码]
description: LangChain 消息模型与对话历史管理：Message 基本单元、System/Human/AI 消息类型、content_blocks 多模态字段，以及手动维护消息列表实现多轮对话短期记忆。
---
# LangChain消息与对话历史

## 消息与提示词模板

### 认识消息

大模型没有记忆，它的输出只和输入模型的内容有关（上下文）。很多大模型API服务也没有在服务端维护会话历史，是“无状态”的。因此，如果应用需要“记住”对话历史，需要在程序中维护消息列表。
在LangChain中，Message是模型交互的最基本单元，它既代表模型接收到的输入（input），也代表模型生成的输出（output）

### 消息的类型

1. 系统消息
2. 用户消息
3. AI消息
4. 工具调用消息

#### SystemMessage参数列表

+ content：消息内容，字段名可以省略

#### HumanMessage参数列表

+ content
+ metadata：元数据字段，可以有很多，自定义
```python
HumanMessage(
	content="Hello!",
	name="alice",
	id="msg_123",
)
```

DeepSeek竟然不支持name字段

### 消息的content_blocks字段

在支持多模大模型的时候使用，给大模型发送除了文字之外的信息

```python
import os

from dotenv import load_dotenv
from langchain_deepseek import ChatDeepSeek
from rich import print as rprint

load_dotenv(override=True)

DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")
DEEPSEEK_API_BASE = os.getenv("DEEPSEEK_API_BASE")

model = ChatDeepSeek(
    api_key=DEEPSEEK_API_KEY, api_base=DEEPSEEK_API_BASE, model_name="deepseek-flash", extra_body={"thinking": {"type": "enabled"}}
)

response = model.invoke("你好")
rprint(response.content)
rprint(response.content_blocks[0]["reasoning"])

```

## 对话历史管理

```python
import os

from dotenv import load_dotenv
from langchain_core.messages import AIMessage, HumanMessage, SystemMessage
from langchain_deepseek import ChatDeepSeek
from rich import print as rprint

load_dotenv(override=True)

DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")
DEEPSEEK_API_BASE = os.getenv("DEEPSEEK_API_BASE")

model = ChatDeepSeek(
    api_key=DEEPSEEK_API_KEY, api_base=DEEPSEEK_API_BASE, model_name="deepseek-flash"
)
conversation = [
    SystemMessage(content="你是一个专业的聊天机器人，每次使用一句话简短的回答")
]


def control_conversation(conversation: list, max_len: int = 3) -> list:
    system_message = [m for m in conversation if isinstance(m, SystemMessage)]
    conversation_message = [m for m in conversation if not isinstance(m, SystemMessage)]
    resent_message = conversation_message[-(max_len * 2) :]
    return system_message + resent_message


def chat_with_deepseek(message: str) -> str:
    conversation.append(HumanMessage(content=message))
    response = model.stream(conversation)
    full_response = ""
    rprint("deepseek:", end="")
    for chunk in response:
        if chunk.content:
            full_response += chunk.content
            rprint(chunk.content, end="")
    rprint("\n")
    conversation.append(AIMessage(content=full_response))
    return response


if __name__ == "__main__":
    max_len = 3
    i = 1
    while True:
        message = input("you:")
        if message == "exit":
            break
        response = chat_with_deepseek(message)
        conversation = control_conversation(conversation, max_len)
        rprint(f"对话轮次：{i}")
        i += 1
```

## 参考信息

- [[2026-10-11-AI知识地图]] — 学习路径中的位置：知识地图「第五步：应用开发」
- [[2026-10-12-LangChain调用大模型API]] — 上游基础：模型初始化与 invoke/stream 用法在该篇
