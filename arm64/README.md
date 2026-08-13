# 全志 H618 Android 64 位移植补丁包

这套补丁将官方 kickpi H618 Android 12 SDK（Apollo-P2 / K2C-tablet）
的用户空间从 32 位 `arm` 移植到 64 位 `arm64`。

## 已经完整跑通

- 在 K2C-tablet 上 `./build.sh` 编译干净通过（输出 `pack image ok!`）
- 烧写后能进 Android 12 桌面
- 系统设置里 Architecture 显示 `aarch64 (64-bit)`
- `ro.zygote=zygote64_32`，`ro.product.cpu.abi=arm64-v8a`
- 既支持 PhoenixSuit（USB）也支持 PhoenixCard（SD 启动卡）烧写

## 为什么是 32/64 混合架构

全志媒体 HAL 链路**只有 32 位 Android bionic 的预编译包**。
SDK 里那些 `aarch64` 的 blob（位于 `library/toolchain-sunxi-*-glibc/musl/`）
链接的是 glibc/musl，是给 Tina Linux 用的，**在 Android 上无法加载**。

所以最终的运行架构：

- **arm64** — zygote、system_server、framework、GPU 驱动、普通 App
- **arm** — mediaserver、codec2 HAL service、hwcomposer HAL、UVC
  external-camera provider、widevine HAL —— 所有需要 dlopen 全志
  32 位 blob 的进程

这正是 AOSP 上游对 mediaserver 的标准做法：
`compile_multilib: "prefer32"` 在混合设备上把 mediaserver 固定到 32 位。
64 位 framework 通过 Binder 跟 32 位 HAL 通信，不需要任何跨架构桥接。

## 目录内容

```
0001-feat-switch-to-64-bit-userspace-arm64-zygote64_32.patch
0002-feat-lock-cedarx-codec2-mediaplayerservice-widevine-.patch
0003-feat-lock-display-UVC-camera-HIDL-chain-to-32-bit.patch
0004-abi-regenerate-VNDK-64-bit-libstagefright_foundation.patch
0005-abi-regenerate-VNDK-32-bit-libstagefright_foundation.patch
apply.sh
README.md
```

- **patch 1–3** 是真正的移植工作，在官方 master 上永远 apply 干净。
- **patch 4–5** 是 VNDK ABI 基线 dump 文件。它们需要**在本地
  第一次 build 之后**重新生成，因为 `.lsdump` 内部的 SHA 编码了
  生成它的工具链版本，不同机器上 SHA 会不同。

## 在新 SDK 树上使用

```bash
cd /path/to/new/sdk
git status                                 # 应该是干净的
/path/to/h618-arm64-patch/apply.sh /path/to/new/sdk

./build.sh lunch                           # 选 BoardConfig-kickpi-k2c-tablet（或 -tv）
./build.sh                                 # build #1 — 会在 abidiff 步骤失败（预期）
/path/to/h618-arm64-patch/regenerate-abi.sh /path/to/new/sdk   # 把两份新 ABI dump 落地
./build.sh                                 # build #2 — 应该能一路通过到 "pack image ok!"
```

`regenerate-abi.sh` 把 `out/soong/.intermediates/.../libstagefright_foundation.so.lsdump`
复制到 `prebuilts/abi-dumps/...`，做 `git add` + `git commit`，幂等（再跑输出 "Nothing to commit."）。

如果你完全用本仓库里的 patch 文件（apply 4 + 5），不需要跑 `regenerate-abi.sh`——但如果你的工具链跟我们打包时不同，apply.sh 里嵌入的 0004/0005 会因 SHA 不匹配 apply 失败。**推荐用 `regenerate-abi.sh`，不依赖工具链版本**。

### 为什么 build #1 失败、build #2 通过

build #1 会重新生成 `out/soong/.intermediates/.../libstagefright_foundation.so.lsdump`（64 位和 32 位各一份），但 `prebuilts/abi-dumps/.../libstagefright_foundation.so.lsdump` 仍然是 SDK 原始的旧 dump（git HEAD 里的）。
abidiff 步骤拿新 dump 跟旧参考对比，发现 ABI 不一致，build 失败。
此时 `out/` 里的新 dump 已经生成好了——跑 `regenerate-abi.sh` 把它们覆盖到 `prebuilts/` 并 commit。

build #2 时 `prebuilts/` 已经是新 dump，abidiff 通过，pack ok。

`regenerate-abi.sh` 对两份 lsdump 独立处理（缺哪份就跳过哪份、提示哪份没生成），所以可以反复跑、幂等，不会因为某一份缺失就整个拒绝继续。

### 板级配置说明

SDK 的 git HEAD 把 `device/softwinner/.BoardConfig.mk` 指向
`BoardConfig-kickpi-k2b-tablet.mk`（k2c 的 commit 在 git 历史里
被 revert 过）。**K2C 板子的硬件跟 K2B 是兼容的**——DDR 时钟
有差异，但固件/DTB 校验两种都接受。从 stock master 编译出的
1.7 GB 镜像在 K2B-tablet 和 K2C-tablet 上都能开机。

`./build.sh lunch` 会重置这个 symlink。lunch 菜单里**选 k2b-tablet**
（默认是第 5 项），除非你有特殊理由换别的。

### 启动 panic 警告

如果你烧完镜像看到：

```
NOTICE:  BL3-1: v1.0(debug):54937d5
NOTICE:  hardware check error1
PANIC in EL3 at x30 = 0x0000000048001f54
```

说明镜像里的 boot0/u-boot/monitor 是旧的。**必须用 `./build.sh`**
（它会跑 `build_brandy` 重新生成 boot0），手动 `make + pack` 用
的是 `longan/out/` 里残留的旧 boot0，必然触发这个 panic。重新跑
一次 `./build.sh` 就能修。

## 每个 patch 改了什么

### 0001 — 切到 64 位用户空间

只动一行：`device/softwinner/apollo/common/system/config.mk` 把默认
`TARGET_ARCH` 从 `arm` 改成 `arm64`，让 SDK 里现成的 `apollo_64_bit.mk`
（之前一直闲置）生效。`ro.zygote` 自动变成 `zygote64_32`，默认 app ABI
变成 `arm64-v8a`。

### 0002 — 锁 cedarx/codec2/mediaplayerservice/widevine 到 32 位

- **`libcedarc/library/Android.bp`**：把 27 个 prebuilt blob（`libVE`、
  `libvideoengine`、`libvdecoder`、`libvencoder`、`libcdc_base`、
  `libOmxVdec`、`libOmxVenc`、`libscaledown`、`libvenc_*`、`libawh264/265`、
  `libawvp9` 等）塌缩成单一 `androideabi_32` src + `compile_multilib: "32"`。
  删掉指向不存在 `androideabi_64/` 目录的 `arm64:` 分支。
- **`libcedarc/config/Android.bp`**：根 defaults `libcdc_config_defaults`
  设 `compile_multilib: "32"`。整棵 cedararc 源码树（base、memory、ve、
  vdecoder、vencoder、openmax、demo）都继承这个。
- **`libcedarx/config/Android.bp`**：同样的事，通过 `libcdx_config_defaults`
  影响所有 ~68 个 cedarx 模块（libcore/*、android_adapter/*、stream/*、
  parser/*、demo/*）。
- **`libcodec2/components/Android.bp`**（含 `libcodec2_hw-defaults`）：
  pinned 到 32 位——因为 codec2 组件链接 `libVE`/`libvideoengine`/
  `libcdc_base`，而且 defaults 里 `-mfpu=neon` 这个 flag 只对 32 位 ARM 有意义。
- **`libmediaplayerservice/Android.bp`** + 两个测试模块
  (`tests/Android.bp`、`tests/stagefrightRecorder/Android.bp`)：
  `MediaPlayerFactory.cpp` 硬编码引用 cedarx 的 `AwPlayer`/`AwMetadataRetriever`。
  mediaserver 进程本身在 AOSP 上游就是 `prefer32`。
- **`hardware/aw/widevine/Android.mk`**：删掉引用不存在 `lib64/` 的 64 位块。

**3 处源码兼容性修复**（64 位 build 才暴露 `-Werror=format`）：

- `hardware/aw/audio/homlet/h618/audio_hw.c:2140` — `%d` → `%zu`
  （参数是 `size_t`）
- `hardware/aw/display/pq/trans_info.c:181` — `%d` → `%ld`
  （指针差在 LP64 下变 8 字节）
- `hardware/sprd/wlan/wifi_hal/lowi/rtt.cpp:699` — `%lld` → `"%" PRId64 ""`
  加 `<inttypes.h>` 头（`int64_t` 在 32 位是 `long long`，64 位是 `long`）

### 0003 — 锁 display + UVC camera HIDL 链路到 32 位

这些 service 在运行时 dlopen 32 位的全志 HAL，所以自己也要跑 32 位：

- **`hardware/aw/display/hwc-hal/Android.mk`**：`hwcomposer.apollo`
  pinned 到 32 位。
- **`hardware/aw/display/hwc-hal/hdr10p/Android.bp`**：`libawhdr10p`
  原作者把同一个 `androideabi_32` 的 `.a` 在 `arm` 和 `arm64` 两个
  分支里都指向了它，导致 Soong 把 32 位 archive 链到 aarch64 ELF 时
  报 `ld.lld: ... is incompatible with aarch64linux`。塌缩成单
  `srcs` + `compile_multilib: "32"`。
- **`hardware/aw/camera/1_0/Android.mk`**：`camera.apollo` 锁 32 位
  （它的 `Libve_Decoder2.c` 调用 `libvdecoder`/`libvencoder`）。
- **`hardware/interfaces/graphics/composer/2.2/default/Android.mk`**：
  `composer@2.2-service` 是 AOSP passthrough 包装，运行时
  dlopen `hwcomposer.$(TARGET_BOARD_PLATFORM).so`。
- **`hardware/interfaces/graphics/allocator/2.0/default/Android.bp`**：
  同样，`allocator@2.0-service` dlopen `gralloc.apollo.so`。
- **`hardware/interfaces/camera/device/{3.4,3.5,3.6}/default/Android.bp`**：
  UVC external-camera 链路。Apollo-P2 的 `apollo_p2.mk` 设了
  `PRODUCT_HAS_UVC_CAMERA := true`，这是实际跑的链路。
- **`hardware/interfaces/camera/provider/2.4/default/Android.bp`** 和
  `2.5/default/Android.bp`**：provider 库，被
  `android.hardware.camera.provider@2.4-external-service`（已经是 32 位）调用。

`camera.provider@2.4-service`（非 external 那个）等其他变体保持
multi-lib——它们没有 32 位专属依赖；64 位的 service 变体通过
`-external-service` 这个 32 位变体间接访问 HAL。

### 0004 — VNDK 64 位 ABI 基线

64 位 build 会重新生成 source-based `libstagefright_foundation.so.lsdump`。
`-allow-unreferenced-changes` abidiff 标志接受 `EXTENDING CHANGES`
（同样的 C++ 源码编出来的 aarch64 ELF 略有不同）。

### 0005 — VNDK 32 位 ABI 基线

32 位版本同理。两个 dump 都编码了工具链版本，apply.sh 在 README
里说明了 SHA 不一致的应对方式。

## 当前 SDK（K2C-tablet）的实测

开机后系统设置页：

```
Operating System: Android 12 (Snow Cone)
API: 31
Architecture: aarch64 (64-bit)
Instruction sets: arm64-v8a / armeabi-v7a / armeabi
Fingerprint: Allwinner/apollo_p2/apollo-p2:12/SP1A.211105.004/20260810.234808:userdebug/test-keys
Kernel: Linux version 5.4.125 (Android clang 12.0.7)
```

最终镜像：`longan/out/update-h618-kickpi-k2c-android12-tablet-YYYYMMDDHH.img`
（约 1.7 GB）。

`vendor/lib64/` — 121 个模块，`vendor/lib/` — 165 个模块（多数是
全志 32 位媒体链）。`mediaserver` 是 32 位 ARM（符合 `ro.zygote=zygote64_32`）。

## 注意事项

### 1. ABI dump 的工具链漂移

如果你用的是不同版本的 `prebuilts/clang/host/`，patch 4/5 编出来的
`.lsdump` 字节会不同，`git am --3way` 会因为 SHA 冲突失败。
内容在功能上是等价的。直接 `git add` + `git commit` 落地即可。

### 2. 不要手动改 `.BoardConfig.mk`

`./build.sh lunch` 会重置这个 symlink。除非你有 k2b-tv 或别的
特殊板型，否则保持在 `BoardConfig-kickpi-k2b-tablet.mk`。

### 3. 不能跳过 `build_brandy`

这个步骤会重新生成 `boot0_sdcard_sun50iw9p1.bin` 等 secure boot
组件。手动 `make` 用的是旧的，会触发 BL3-1 的 hardware check panic。

### 4. 这是移植补丁集，不是上游改动

长期来看，正确做法是全志出 64 位 Android 版 cedarx blob。在那
之前，混合架构模式是 AOSP 标准的应对方式。

## 打包分发

```bash
cd /home/gao && tar czf h618-arm64-patch.tar.gz h618-arm64-patch/
```

约 476 KB，包含了 README、apply.sh 和 5 个 patch 文件。