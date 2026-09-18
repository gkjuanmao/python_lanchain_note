启动示例（ASGI，Django 6 自带 ASGI_APPLICATION）：
`uv add uvicorn`
`uv run uvicorn config.asgi:application --host 0.0.0.0 --port 8000`

>**注意：** windows上不能加worker参数，不支持

uvicorn 的 --workers N 通过 multiprocessing 生成子进程，并把同一个监听 socket 传给多个 worker。在 Windows + Python 3.12+（你的 3.14）下，Proactor 事件循环对"继承来的 socket + 复用地址标志"调用 listen() 会抛 WinError 10022。

+ 你也看到了它"部分能跑"：日志里 worker 28276 成功监听并返回 200，而 SpawnProcess-2 / 10456 崩溃——正是多 worker 竞争同一 socket 的竞态表现。
+ uvicorn 官方文档也明确：--workers 多进程模式在 Windows 上不受支持。 ASGI 'lifespan' protocol appears unsupported 是无害提示（Django 默认不实现 lifespan 协议），可忽略。