# FFmpeg for cocos2d-x (Win32 / MSVC) — 预编译产物说明

## 1. 产物信息

| 项 | 值 |
|---|---|
| 源码 | `cocos2d-x/external/ffmpeg-master`（FFmpeg 8.0.git，`av_version_info = git-2026-07-15-e6231ca`） |
| 编译器 | MSVC 19.44.35228（VS2022 17.14 / v143） |
| Windows SDK | 10.0.26100 |
| 目标架构 | **x86 (Win32)**，`dumpbin` 显示 `14C machine (x86)` |
| 链接方式 | 动态库（DLL + 导入库），LGPL v2.1+，未启用任何 GPL 组件 |
| 汇编 | NASM 2.16.03，`-f win32`（x86 汇编优化已开启） |
| 构建 shell | MSYS 1.0（`D:\Soft\MinGW\msys\1.0`）：只提供 `bash`/`make`，编译器始终是 `cl.exe` |

DLL 与版本号：

| 库 | DLL | 导入库 |
|---|---|---|
| libavutil | `avutil-61.dll` | `avutil.lib` |
| libavcodec | `avcodec-63.dll` | `avcodec.lib` |
| libavformat | `avformat-63.dll` | `avformat.lib` |
| libswscale | `swscale-10.dll` | `swscale.lib` |
| libswresample | `swresample-7.dll` | `swresample.lib` |

已启用的组件（`--disable-everything` 后按需打开，包体较小）：

- 解码器：`h264`、`hevc`、`aac`、`mp3`
- 解析器：`h264`、`hevc`、`aac`、`mpegaudio`
- 解封装：`mov`（含 mp4/m4v/mov）、`matroska`（mkv/webm）、`mpegts`、`flv`
- 协议：`file`（仅本地文件，无网络协议）
- 库：`avcodec`、`avformat`、`avutil`、`swscale`、`swresample`

> 需要更多格式（如 `mjpeg`、`vp9`、`opus`、`http` 协议）时，在 configure 的 `--enable-decoder=` / `--enable-demuxer=` / `--enable-protocol=` 里追加后重编即可，见第 4 节。

## 2. 目录结构与两套 CRT

```
external/ffmpeg/
├─ include/                              # 头文件（libav*/ 下）
└─ prebuilt/win32/
   ├─ lib/                               # 导入库（Release CRT, /MD）
   ├─ bin/                               # av*.dll + *.pdb（Release CRT, /MD）
   └─ debug/
      ├─ lib/                            # 导入库（Debug CRT, /MDd）
      └─ bin/                            # av*.dll + *.pdb（Debug CRT, /MDd）
```

`dumpbin /dependents` 实测：

- `prebuilt/win32/bin` → `VCRUNTIME140.dll` + `api-ms-win-crt-*`（Release CRT）
- `prebuilt/win32/debug/bin` → `VCRUNTIME140D.dll` + `ucrtbased.dll`（Debug CRT）

**Debug|Win32 配置该用哪套？**

推荐直接用 `prebuilt/win32`（Release CRT）。原因：cocos2d-x 的 Debug 配置是 `/MDd`，但 DLL 是独立模块，其 CRT 不会与 EXE 的 CRT 参与 `LNK2038` 检查——导入库只是跳转桩，不含 `/FAILIFMISMATCH` 指令。实测用 `cl /MDd` 链接 Release 导入库可以正常链接并运行。

只有在需要调试 FFmpeg 内部、或要统一调试堆时，才切到 `prebuilt/win32/debug`（要求运行机器装有 VS 调试运行时 `ucrtbased.dll` / `vcruntime140d.dll`，仅开发机适用）。

## 3. 在工程中使用

`runtime-src/proj.win32/ffmpeg.props` 已按上面的布局写好（默认用 Release CRT，可切 debug），在 `cocos2d-x_lua.vcxproj` 的 `ImportGroup` 里（`cocos2dx.props` 之后）加一行即可：

```xml
<Import Project="ffmpeg.props" />
```

props 会做三件事：

1. 追加 `$(FFmpegRoot)\include`；
2. 追加 `$(FFmpegDir)\lib` 并链接 5 个 `.lib`；
3. Build 后把对应 DLL 拷到 `simulator\win32`（Debug）或 `publish\win32`（Release）。

切 Debug CRT 只需在 vcxproj 里加 `<FFmpegCRT>debug</FFmpegCRT>`。

## 4. 重新构建（可复现）

环境：VS2022 x86 环境（`vcvars32.bat`）、MSYS 1.0 的 `bash`/`make`、NASM 2.16.03。

### 4.1 两处必须打的补丁

**(1) configure 的编译器识别**：FFmpeg 8 用 `VSLANG=1033 cl -nologo- | grep ^Microsoft` 判断 MSVC，但本机 VS 只装了中文资源（`bin\HostX86\x86\2052`，无 `1033`），`VSLANG` 切不出英文，会被误判成 gcc（随后用 `-o` 编译而失败）。解决：复制一份 `configure`，把 4 处 `^Microsoft` 改成 `Microsoft`，并把 `_ident` 固定为 ASCII：

```bash
sed -e 's/grep -q \^Microsoft/grep -q Microsoft/g' \
    -e 's/grep \^Microsoft/grep Microsoft/g' \
    configure > configure.localepatch
# 再把 _ident=$(VSLANG=1033 $_cc 2>&1 | grep Microsoft | head -n1 | tr -d '\r')
# 替换为 _ident="MSVC 19.44.35228"
```

**(2) config.h 的 `CC_IDENT`**：中文编译器标识是 UTF-8，`rc.exe` 按 ANSI(936) 解析时会把 `"` 吞掉，报 `RC2001: newline in constant`（卡在 `libavformat/avformatres.o`）。解决：configure 完成后把 `config.h` 里 `#define CC_IDENT ...` 改成 ASCII，例如 `#define CC_IDENT "MSVC 19.44.35228"`。

### 4.2 configure 命令

Release CRT（`/MD`）：

```bash
sh configure.localepatch \
  --toolchain=msvc --arch=x86 --target-os=win32 \
  --prefix=<build>/install \
  --enable-shared --disable-static \
  --disable-programs --disable-doc --disable-stripping \
  --disable-avdevice --disable-avfilter \
  --disable-network --disable-autodetect \
  --disable-everything \
  --enable-decoder=h264,hevc,aac,mp3 \
  --enable-parser=h264,hevc,aac,mpegaudio \
  --enable-demuxer=mov,matroska,mpegts,flv \
  --enable-protocol=file \
  --enable-swscale --enable-swresample \
  --optflags=-O2 \
  --extra-cflags="-MD -D_CRT_SECURE_NO_WARNINGS"
make -j16 && make install
```

Debug CRT（`/MDd`）：同上，仅 `--extra-cflags="-MDd -D_CRT_SECURE_NO_WARNINGS"`，并换独立 build 目录。

> 必须**源码外构建**（在单独 build 目录里执行 `sh <src>/configure.localepatch`），这样 `ffmpeg-master` 目录保持干净，只多一个 `configure.localepatch`（构建完可删）。

### 4.3 产物收集

`make install` 在 MSVC 下把 DLL 和导入库都装到 `<prefix>/bin`，头文件在 `<prefix>/include`；PDB 留在构建目录的 `libav*/` 下，需要一起拷到 `bin`。

## 5. 已知注意点

- **`-showIncludes` 依赖**：FFmpeg 用 `compat/windows/mscl` 把 cl 的 `Note: including file:` 转成 `.d`，该前缀是英文；中文 cl 输出“注意: 包含文件:”匹配不上，`.d` 依赖为空。只影响**增量重编**的依赖判断，不影响编译结果；要精确增量，可把 `mscl.c` 的 `INC_PREFIX` 改成中文前缀，或改英文版 MSVC 语言包。
- **`-options:strict`**：configure 探测通过后会进入 CFLAGS，未知编译选项会直接报错（这是 FFmpeg 8 有意为之），加自定义 `--extra-cflags` 时注意合法性。
- **运行期**：5 个 DLL 必须与 exe 同目录（或 PATH 中）；`avcodec-63.dll` 依赖 `avutil-61.dll`，不要只拷部分。
- **LGPL 合规**：动态链接 + 提供本说明即可，勿开启 `--enable-gpl`（x264 等）。
