# adb-control

ADB 设备遥控器（Flutter 桌面应用）。

在开发机（Linux/Windows/macOS）上运行，通过本地 `adb` 命令查询已连接的 Android 设备/模拟器，并向选中设备发送遥控按键码（Android KeyEvent）。

## 功能

- 顶部设备选择器：运行 `adb devices -l` 列出所有设备，选择目标设备
- 常用遥控按键按钮：电源、HOME、BACK、菜单、方向键、确定、音量±、静音、播放/暂停、上一曲/下一曲、唤醒/休眠、回车、删除、相机、搜索等
- 点击按钮发送 `adb -s <序列号> shell input keyevent <按键码>` 到选中设备
- 底部实时显示操作状态

## 常用按键码对照

| 按键 | KeyEvent 码 |
|------|-------------|
| 电源 | 26 |
| HOME | 3 |
| BACK | 4 |
| 菜单 | 82 |
| 方向键上/下/左/右 | 19/20/21/22 |
| 确定 | 23 |
| 音量+ / 音量- | 24 / 25 |
| 静音 | 164 |
| 播放/暂停 | 85 |
| 上一曲 / 下一曲 | 86 / 87 |
| 唤醒 | 224 |
| 休眠 | 223 |
| 回车 | 66 |
| 删除 | 67 |

## 运行

### 前提

已安装 [Flutter](https://docs.flutter.dev/get-started/install) 与 Android SDK（`adb` 在 `PATH` 中，或通过 `ADB_PATH` 环境变量指定）。

```bash
# 进入项目
cd /home/byteman/code/adb-control

# 获取依赖
flutter pub get

# 运行（Linux 桌面示例）
flutter run -d linux
```

或直接构建：

```bash
flutter build linux
```

构建产物在 `build/linux/x64/release/bundle/`。

### 指定 adb 路径（可选）

若 `adb` 不在 `PATH` 中，可通过环境变量指定：

```bash
export ADB_PATH=/home/byteman/Android/Sdk/platform-tools/adb
flutter run -d linux
```

## 项目结构

```
lib/main.dart      # 主页面与 adb 调用逻辑（dart:io Process）
pubspec.yaml       # Flutter 项目配置
test/widget_test.dart  # 简单冒烟测试
android/           # Android 平台工程（如需打包为 APK）
linux/             # Linux 桌面平台工程
```

## 注意

- 本应用在开发机桌面运行，调用本机 `adb` 控制已连接的 Android 设备；它本身不是安装到手机上的 APK。
- 如需打包为 Android APK 并在手机上运行，需在手机内置 adb 环境（通常不可行），建议保持为桌面遥控器使用。
