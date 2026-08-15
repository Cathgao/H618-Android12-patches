# GPIO Button (Pin 14 & 16) Patch Set

## 功能概述
为 KickPI K2C / K2B (全志 H618) 开发板添加扩展排针 **14脚（模拟地）** 与 **16脚（PI11 按键输入）** 的硬件按键支持：
* **Pin 16 (`PI11`)**：配置为 `gpio-keys` 输入中断脚，启用芯片内部上拉（3.3V）与 100ms 内核级定时器消抖，映射为标准 Linux 键码 `KEY_F1`（59）。
* **Pin 14 (`PI12`)**：配置为 `gpio-leds` 输出低电平（0V），充当模拟接地端。
* **APK 接入**：Android 系统自动将键值识别为 `KeyEvent.KEYCODE_F1`，应用可在 `Activity.onKeyDown` 中直接捕获，无需任何 JNI 或 Root 权限。

## 涉及文件与修改
1. `longan/kernel/linux-5.4/drivers/pinctrl/sunxi/pinctrl-sun50iw9.c`:
   * 增加 `.disable_strict_mode = true`，解除 pinctrl 上拉与 GPIO 中断请求之间的严格互斥锁。
2. `longan/device/config/chips/h618/configs/p2/linux-5.4/board-k2c.dts` & `board-k2b.dts`:
   * 释放占用了 PI11/PI12 的 `gpio_para` 和 `pwm1`/`pwm2`。
   * 在 `gpio-keys` 主节点绑定 `btn_pi11_pullup`（`function = "gpio_in"`, `bias-pull-up`），配置 100ms 消抖。
   * 在 `gpio-leds` 下配置 `btn_gnd`（`PI12` 默认输出低电平）。

## 使用方法
### 应用补丁
```bash
~/H618-Android12-patches/gpio_button/apply.sh
```

### 撤销补丁
```bash
~/H618-Android12-patches/gpio_button/reset.sh
```

### 编译
```bash
cd ~/h618-android12.0/longan
./build.sh kernel
```
