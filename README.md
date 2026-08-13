# H618 Android 12 补丁集

本仓库为 **全志 H618 / Apollo-P2 / K2C 平板电脑** Android 12 SDK提供三套相互独立的补丁集,各补丁集以同级子目录的形式组织,可针对一份刚刚执行过 `git reset --hard` 的源码树单独或一并应用。

```
h618-patches/
├── arm64/         # 64 位用户空间移植(kickpi 32 位 -> AOSP arm64 zygote64_32)
├── egtouch/       # eGalax 电阻触摸屏:eGTouchD 守护进程 + eGalaxCalibrator
│                  # + SELinux 放行策略 + 面向 untrusted_app 的 UART/GPIO 调试权限
└── audio_policy/  # audio_policy_configuration.xml 覆盖:新增 USB Audio HAL
                   # 模块(kickpi HEAD 仅声明 primary + A2DP + Remote Submix)
```

三套补丁作用于 **互不相交的文件集合**(已验证:路径级零重叠),可按任意顺序、单独或一起应用,彼此之间不会产生交互影响。

| 补丁集 | 修改文件数 | 应用机制 |
|---|---|---|
| `arm64/` | 约 5 个文件(mediaplayerservice、codec2、cedarx、hwcomposer、camera、widevine、sepolicy) | `git am` 应用 5 个提交式补丁 |
| `egtouch/` | 约 20 个受跟踪文件(sepolicy、init、vendor mk、file_contexts)+ 未跟踪的 eGTouchD 目录 + eGalaxCalibrator 预编译产物 | `git apply` 应用 5 个 diff + 从 `source/` 执行 `cp -r` + 二进制拷贝 |
| `audio_policy/` | 1 个受跟踪文件:`device/softwinner/apollo/common/media/audio/audio_policy_configuration.xml` | `git apply` 应用 1 个 diff(与 `source/` 进行 sha256 一致性校验) |

## 快速开始

```bash
# 应用全部三套补丁:
cd h618-android12.0
~/h618-patches/apply.sh

# 仅应用其中一套:
~/h618-patches/apply.sh --only=arm64
~/h618-patches/apply.sh --only=egtouch
~/h618-patches/apply.sh --only=audio_policy

# 撤销 eGTouch 与 audio_policy 的修改(arm64 的修改是 git 提交,
# 需要通过 git reset / revert 撤销 — 详见 reset.sh 输出):
~/h618-patches/reset.sh

# 仅撤销其中一套:
~/h618-patches/reset.sh --only=egtouch
~/h618-patches/reset.sh --only=audio_policy
```

执行 `apply.sh` 之后,源码树就进入构建流程。**首次构建一定会失败**——因为
arm64 VNDK ABI 基线尚未针对新的 32/64 位布局重新生成,`abidiff` 阶段会报错,
这是预期行为。按以下三步走完整个流程即可:

```bash
cd ~/h618-android12.0
./build.sh lunch              # 选择 BoardConfig-kickpi-k2c-tablet
./build.sh                    # 第 1 次构建 —— abidiff 失败,属预期
~/h618-patches/arm64/regenerate-abi.sh ~/h618-android12.0
./build.sh                    # 第 2 次构建 —— 应该走到 "pack image ok!"
```

完整的构建流程说明详见 `arm64/README.md`。

## 各目录内容说明

### `arm64/` —— 64 位用户空间移植

五个 `git am` 补丁,将 kickpi H618 SDK 从出厂的 32 位用户空间切换到符合 AOSP 风格的 `arm64` 用户空间,并设置 `ro.zygote=zygote64_32`。
cedarx / codec2 / mediaserver / hwcomposer / UVC 摄像头 / widevine 栈被固定到 32 位,因为全志的媒体 HAL 仅以 32 位 Android bionic 预编译库的形式提供。

完整的设计原理与构建流程请参阅 `arm64/README.md`。

### `egtouch/` —— eGalax 电阻触摸屏

五个 `git apply` 补丁,加上 `source/` 目录(构建粘合代码)与 `binaries/` 目录
(eGTouchD 守护进程、eGalaxCalibrator APK 以及重命名的 libstdc++/liblog 垫片),
完成以下接线工作:

- 由 `init.sun50iw9p1.rc` 以 root 身份启动 eGTouchD,并为其设立独立的
  SELinux 域(`egtouchd`)。
- 将 eGalaxCalibrator 预装为系统应用,并使用平台密钥重新签名(eGTouchD
  二进制会拒绝 untrusted_app 的连接,重新签名是厂商认可的解决方案)。
- 为新增的域以及供 `untrusted_app` 调试 APK 使用的串口访问,
  开设 SELinux 放行策略。
- 通过 `ueventd` 规则将 `/dev/ttyS*`、`/dev/ttyAS*`、`/dev/gpiochip*`
  以及 `/sys/class/gpio/...` 节点设为 0666 权限,使调试 APK 能够在不获取
  root 权限的情况下操作板载 UART 与 GPIO。

完整修改清单与验证步骤请参阅 `egtouch/README.md`。

### `audio_policy/` —— USB Audio HAL 枚举

单个 `git apply` 补丁,将
`device/softwinner/apollo/common/media/audio/audio_policy_configuration.xml`
替换为声明了 **USB Audio HAL** 模块的版本(kickpi HEAD 出厂仅包含
`primary` 模块 + A2DP + Remote Submix)。若不声明该模块,即使 USB 音频 HAL
已经加载,AudioFlinger 也不会枚举 USB 音频设备 —— 插入板载 USB Type-A 端口
的设备对 `lsusb` 可见,但对 `dumpsys media.audio_policy` 与任何音频应用
都不可见。

验证命令请参阅 `audio_policy/README.md`。

## 撤销语义

不带任何参数运行 `reset.sh` 会撤销 eGTouch 与 audio_policy 的修改——
它对相关受跟踪文件执行 `git checkout --`,并删除 `egtouch/apply.sh` 所
添加的未跟踪目录。执行后,源码树回到"已应用 arm64 补丁 + eGTouch 干净
+ audio_policy 干净"的状态。

对于 arm64 补丁,`reset.sh` 不会改动 git 历史,而是会打印出五个 arm64
提交的 SHA 列表,供你自行执行 `git reset --hard <parent>` 或
`git revert <shas...>`。

## 源码树假设

两套补丁均基于以下前提:

- SDK 位于 `~/h618-android12.0`(`~/h618-patches/` 的同级目录)。
  `egtouch/apply.sh` 与 `egtouch/reset.sh` 会通过从脚本位置向上回溯、
  查找名为 `h618-android12.0` 且包含 `.git` 目录的祖先或同级目录来自动
  发现 SDK 位置。
- 目标为 **K2C 平板电脑** lunch 组合(kickpi SDK 的默认项;
  `./build.sh lunch` 会重置板级符号链接)。
- 构建命令为 `./build.sh`(会调用 `build_brandy` 重新生成
  `boot0_sdcard_sun50iw9p1.bin`);若使用陈旧的 `longan/out/*` 手工执行
  `make + pack`,会触发 BL3-1 的 "hardware check error1" 崩溃。

若 SDK 位于其他位置,请显式传入路径:

```bash
~/h618-patches/arm64/apply.sh /opt/sdks/h618-android12.0
```

arm64 子脚本以 `$1` 接收 SDK 路径;egtouch 子脚本自行发现 SDK 路径,
因此顶层 `apply.sh` 不会向其转发 SDK 参数(路径发现逻辑已覆盖常见情形)。
