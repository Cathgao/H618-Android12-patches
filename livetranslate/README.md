# LiveTranslate 特权系统应用预装补丁

本补丁将 `LiveTranslate.apk` 预装为全志 H618 系统的特权系统应用（`/system/priv-app/LiveTranslate/`）。

## 目录结构

```
livetranslate/
├── apply.sh                                                 # 单独应用此补丁的脚本
├── reset.sh                                                 # 单独撤销此补丁的脚本
├── README.md                                                # 本文档
├── binaries/
│   └── LiveTranslate.apk                                    # 预装的 APK 二进制文件
├── diff/
│   └── 01-livetranslate-homlet.diff                         # homlet.mk 的标准 diff 参考
└── source/
    └── vendor/aw/homlet/prebuild/LiveTranslate/
        └── Android.mk                                       # 模块编译配置 (含 LOCAL_PRIVILEGED_MODULE := true)
```

## 快速使用

```bash
# 方式 1：单独应用本补丁
~/H618-Android12-patches/livetranslate/apply.sh
# 或通过顶层脚本指定
~/H618-Android12-patches/apply.sh --only=livetranslate

# 方式 2：单独撤销本补丁
~/H618-Android12-patches/livetranslate/reset.sh
# 或通过顶层脚本指定
~/H618-Android12-patches/reset.sh --only=livetranslate
```

## 如何更新 APK？

**直接替换补丁目录中的 APK 即可！**

1. 将最新的 APK 文件覆盖替换到：
   `~/H618-Android12-patches/livetranslate/binaries/LiveTranslate.apk`
2. 重新执行应用脚本：
   ```bash
   ~/H618-Android12-patches/apply.sh --only=livetranslate
   # 或者执行总的 ~/H618-Android12-patches/apply.sh
   ```
3. 脚本会自动将最新的 APK 同步覆盖到 SDK 源码树中（`vendor/aw/homlet/prebuild/LiveTranslate/LiveTranslate.apk`），随后重新编译镜像即可生效。
