---
tags: [langchain, langgraph, agent, 框架]
description: LangChain 开源框架的定位、五个主要模块与四大家族（LangChain、LangGraph、Deep Agent、LangSmith）的分工，以及大模型应用开发的特点与两大方向。
---
# LangChain框架

## LangChain是什么

LangChain是一个由大语言模型驱动的应用程序开发的开源框架

## LangChain的主要模块

+ langchain-core 轻量核心，包括核心抽象接口
+ langchain-community 第三方集成
+ langchain-openai 第三方集成
+ langgraph 深度整合LangGraph1.0，协调多个Chain，Agent，Tools完成更复杂的任务，并且还支持循环调用，是langchain图形化的增强版
+ langchain-classic 冗余代码或不推荐使用的经典API

官网链接：
[LangChain reference](https://reference.langchain.com/python/langchain/overview)
[langchain官网](https://www.langchain.com/)
[Github地址](https://github.com/langchain-ai)
[中文文档地址](https://docs.langchain.org.cn/oss/python/langchain/overview)
[英文文档地址](https://docs.langchain.com/oss/python/langchain/overview)
[API文档查询地址](https://reference.langchain.com/python/langchain/)

## LangChain四大家族
 + LangChain
 + LangGraph
 + Deep Agent
 + LangSmith

### LangChain
如果需要构建简单的智能体应用，无需复杂的编排需求，那就选择LangChain

### LangGraph
当智能体的任务从单一指令执行扩展为多步骤、有状态的复杂工作流时，LangGraph应运而生，其核心思想是**将智能体内部抽象为一张有向图**

+ 节点（Node）：代表独立的功能单元或决策点。
+ 边（Edge）：定义了节点之间的流转条件与路径。
+ 状态（State）：作为一个共享上下文，在节点间传递并持久化存储任务信息。

### Deep Agent
Deep Agent是新推出的全新组件，被定位为Agent Harness（智能体执行框架）。它构建于LangChain与LangGraph之上，增加了规划能力、文件系统、子Agent等高级功能。旨在让并发者无须从零构建复杂的控制逻辑，即可创建具备深度规划、长期记忆与多专家协作能力的智能体。

### LangSmith

LangSmith是LangChain官方推出的可视化监控与测试平台，用于跟踪、记录和分析智能体在运行过程中的完整调用链路，让智能体的内部运行过程变得透明和可评估。

LangSmith是LangChain生态中专门用于LLM应用调试、监控、评估和管理的平台

+ 追踪：记录每次LLM调用的详细信息
+ 监控：实时查看应用性能
+ 调试：排查问题和性能优化
+ 评估：系统化测试LLM应用

## 大模型应用场景介绍
大模型应用技术特点：门槛低，天花板高

基于大模型的两个主要开发方向：[[2026-10-11-RAG开发流程]]（接入外部知识）与 [[2026-10-11-Agent开发与架构]]（能规划、记忆和调用工具的智能体）。

## 参考信息

- [[2026-10-11-RAG开发流程]] — 应用方向一：用 LangChain 编排"检索 + 生成"链路，把外部知识接入大模型。
- [[2026-10-11-Agent开发与架构]] — 应用方向二：LangGraph 的有向图编排正对应 Agent 多步骤、有状态的复杂工作流。
- [[2026-10-11-提示词工程]] — 上游基础：框架中的 Chain 与提示模板本质上是在组织和管理提示词，模型参数与消息角色等概念在 LangChain 调用中同样适用。
