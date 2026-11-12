# cc.VideoNode — UI 层内视频播放（FFmpeg 软解 → 纹理）

用 FFmpeg 解码到 `Texture2D`，作为普通场景节点参与 UI 层渲染，可以被遮挡、裁剪、跟随 UI 做转场；不使用系统播放器覆盖层。

## 模块

| 文件 | 职责 |
|---|---|
| `VideoPlayerImpl.*` | 解封装、视频/音频解码、帧队列、主时钟、seek/loop |
| `AudioSinkWin32.*` | `waveOut` 播放 PCM（44.1k/16bit/stereo），提供已播时长 |
| `VideoNode.*` | `cocos2d::Node` 子类，主线程每帧上传 RGBA 到 `Texture2D` |
| `lua_video_binding.*` | 注册 `cc.VideoNode` 到 Lua |

线程模型：一个解码线程（demux + 解码 + 音频阻塞写）；GL 线程只做 `Texture2D::updateWithData`，不触碰 FFmpeg 上下文。时钟以音频设备已播采样为准，无音轨时退回 `steady_clock`。

## 依赖

`cocos2d-x/external/ffmpeg`（见该目录 `BUILDING.md`），由 `proj.win32/ffmpeg.props` 引入；`AppDelegate.cpp` 里 `register_all_video(L)` 完成注册。

## Lua API

```lua
local video = cc.VideoNode:create("video/intro.mp4")   -- 相对 res 搜索路径
if not video then return end

video:setPosition(display.cx, display.cy)
video:setScale(0.5)
video:setLoop(true)
video:setVolume(1.0)

-- event: 0=PLAYING 1=PAUSED 2=STOPPED 3=COMPLETED 4=ERROR
video:addEventListener(function(sender, event)
    if event == 3 then
        sender:removeFromParent()
    end
end)

self:addChild(video)     -- 必须 addChild：节点由父节点持有
video:play()
```

| 方法 | 说明 |
|---|---|
| `create(path)` | 打开视频，失败返回 `nil`；`path` 走 `FileUtils` 搜索路径（如 `res/video/x.mp4` 写 `"video/x.mp4"`） |
| `play()` / `pause()` / `resume()` / `stop()` | 控制播放；`stop()` 会结束解码线程，再次 `play()` 从头开始 |
| `seek(seconds)` | 跳转（按关键帧回退后再丢帧到目标位置） |
| `setLoop(bool)` | 循环播放（EOF 后 seek 到 0） |
| `isPlaying()` | 是否正在播放 |
| `getDuration()` | 时长（秒），未知返回 0 |
| `getVideoWidth()` / `getVideoHeight()` | 视频像素尺寸；节点 contentSize 同值 |
| `setPosition()` | **节点原点是视频中心**，所以 `setPosition(display.cx, display.cy)` 就是画面居中 |
| `setVolume(0~1)` | 音量（CPU 侧按采样缩放） |
| `addEventListener(fn)` | `fn(sender, event)`，回调在主线程 |

节点本身是 `cc.Node`，`setPosition/setScale/setRotation/setOpacity`、被 `ClippingNode` 裁剪、做 `FadeIn/Out` 等都可用。

## 注意点

- **源码编码必须是 UTF-8 with BOM**：本机 MSVC 默认按 CP936 读源文件，UTF-8 中文注释若没有 BOM，会被 GBK 解码规则吃掉行尾换行，把下一行代码并进注释（表现为 `cc.VideoNode` 为 nil、栈错乱等诡异问题）。用 VS 保存会自动保留 BOM；用其它编辑器改这些文件时务必确认 BOM 还在。同理，**没有 BOM 的工程文件（如 `AppDelegate.cpp`）里不要写中文注释**——之前 `register_all_video(L);` 就是被上一行的中文注释吞掉，导致函数根本没被调用。
- **同一时刻只创建一个 `VideoNode` 实例**：每个实例都有独立的解码线程、`Texture2D` 和一块全屏绘制，两个实例会让帧率直接腰斩（这个坑实际踩过）。切视频时请先 `stop()` 再销毁旧节点，或复用同一个节点；也不要在场景 `ctor` 里重复创建。
- **必须 `addChild`**：`create` 返回的对象是 autorelease 的，只有挂到场景里才会被持有；Lua 侧单独持有不会延长生命周期。
- **尺寸与性能**：RGBA 上传是 8MB/帧（1080p），30fps 约 240MB/s 的 `glTexSubImage2D` 带宽，桌面无压力；4K 建议改 NV12 双纹理 + shader，或换硬解。
- **纹理约束**：视频尺寸通常不是 2 的幂，已设为 `GL_CLAMP_TO_EDGE` + `GL_LINEAR`，不能开 mipmap/REPEAT。
- **线程安全**：解码线程不碰 GL；主线程不碰 FFmpeg 上下文。`pause/seek/stop` 都可在主线程直接调用。
- **音频**：`waveOut` 有约 20~90ms 缓冲延迟，音画同步以设备实际播放位置为准；如果机器没有可用音频设备，会自动退回系统时钟继续播视频。
- **格式**：当前构建只启用了 H.264/HEVC/AAC/MP3 + mov/mkv/ts/flv + file 协议；其它格式需要在 FFmpeg 侧加 `--enable-decoder/--enable-demuxer` 重编（见 `external/ffmpeg/BUILDING.md`）。
- **仅 Windows**：`AudioSinkWin32.cpp` 里非 Windows 分支是空实现；上 Android/iOS 时需要换成 OpenSL ES / AAudio / AudioUnit，其余逻辑可复用。
