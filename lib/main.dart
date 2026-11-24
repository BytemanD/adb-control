import 'package:flutter/material.dart';

import 'adb_controller.dart';

/// 通过本地 adb 命令控制 Android 设备/模拟器的遥控器应用。
///
/// 适合在开发机（Linux/Windows/macOS）桌面上运行，用来给已连接的
/// Android 设备或模拟器发送遥控按键码（KeyEvent）。
///
/// 后端 adb 调用逻辑位于 `adb_controller.dart`，本文件仅负责 UI。
void main() {
  runApp(const AdbRemoteApp());
}

class AdbRemoteApp extends StatelessWidget {
  const AdbRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB 遥控器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: RemoteHomePage(controller: AdbController()),
    );
  }
}

/// 单个遥控按键及其对应的 Android KeyEvent keycode。
class AdbKey {
  final String label;
  final IconData icon;
  final int keycode;
  const AdbKey({
    required this.label,
    required this.icon,
    required this.keycode,
  });
}

/// 常用遥控按键（Android KeyEvent keycode）。
/// 参考：https://developer.android.com/reference/android/view/KeyEvent
const List<AdbKey> remoteKeys = [
  AdbKey(label: '电源', icon: Icons.power_settings_new, keycode: 26),
  AdbKey(label: 'HOME', icon: Icons.home, keycode: 3),
  AdbKey(label: 'BACK', icon: Icons.arrow_back, keycode: 4),
  AdbKey(label: '菜单', icon: Icons.menu, keycode: 82),
  AdbKey(label: '上', icon: Icons.keyboard_arrow_up, keycode: 19),
  AdbKey(label: '下', icon: Icons.keyboard_arrow_down, keycode: 20),
  AdbKey(label: '左', icon: Icons.keyboard_arrow_left, keycode: 21),
  AdbKey(label: '右', icon: Icons.keyboard_arrow_right, keycode: 22),
  AdbKey(label: '确定', icon: Icons.radio_button_checked, keycode: 23),
  AdbKey(label: '音量+', icon: Icons.volume_up, keycode: 24),
  AdbKey(label: '音量-', icon: Icons.volume_down, keycode: 25),
  AdbKey(label: '静音', icon: Icons.volume_off, keycode: 164),
  AdbKey(label: '播放/暂停', icon: Icons.play_circle, keycode: 85),
  AdbKey(label: '上一首', icon: Icons.skip_previous, keycode: 86),
  AdbKey(label: '下一首', icon: Icons.skip_next, keycode: 87),
  AdbKey(label: '唤醒', icon: Icons.wb_sunny, keycode: 224),
  AdbKey(label: '休眠', icon: Icons.bedtime, keycode: 223),
  AdbKey(label: '回车', icon: Icons.keyboard_arrow_down, keycode: 66),
  AdbKey(label: '删除', icon: Icons.backspace, keycode: 67),
  AdbKey(label: '相机', icon: Icons.camera_alt, keycode: 27),
  AdbKey(label: '搜索', icon: Icons.search, keycode: 84),
];

/// 遥控器主页面（纯 UI，不直接调用 adb）。
class RemoteHomePage extends StatefulWidget {
  final AdbController controller;

  const RemoteHomePage({super.key, required this.controller});

  @override
  State<RemoteHomePage> createState() => _RemoteHomePageState();
}

class _RemoteHomePageState extends State<RemoteHomePage> {
  List<AdbDevice> _devices = [];
  AdbDevice? _selected;
  bool _loading = false;
  String _status = '点击“刷新”查询设备';

  // 按钮尺寸（遥控器风格：更小、更紧凑）
  static const double _btnWidth = 64;
  static const double _btnHeight = 48;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _loading = true;
      _status = '正在查询设备（adb devices -l）...';
    });

    try {
      final devices = await widget.controller.queryDevices();
      setState(() {
        _devices = devices;
        _loading = false;
        if (_selected != null &&
            !_devices.any((d) => d.serial == _selected!.serial)) {
          _selected = null;
        }
        _status = '共发现 ${devices.length} 台设备';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = '查询失败：$e';
      });
    }
  }

  Future<void> _sendKeyEvent(int keycode) async {
    if (_selected == null) {
      setState(() => _status = '请先在顶部选择一台设备');
      return;
    }

    setState(() {
      _loading = true;
      _status = '正在向 ${_selected!.serial} 发送 keycode=$keycode ...';
    });

    try {
      await widget.controller.sendKeyEvent(_selected!.serial, keycode);
      setState(() {
        _loading = false;
        _status = '已发送 keycode=$keycode 到 ${_selected!.serial}';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = '发送失败：$e';
      });
    }
  }

  Widget _keyButton(AdbKey key) {
    final disabled = _selected == null || _loading;
    return SizedBox(
      width: _btnWidth,
      height: _btnHeight,
      child: FilledButton(
        onPressed: disabled ? null : () => _sendKeyEvent(key.keycode),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size.zero,
          backgroundColor: disabled ? Colors.grey.shade300 : null,
          foregroundColor: disabled ? Colors.grey.shade600 : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(key.icon, size: 16),
            const SizedBox(height: 3),
            Text(
              key.label,
              style: const TextStyle(fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _spacer() {
    return SizedBox(width: _btnWidth, height: _btnHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ADB 遥控器'), centerTitle: true),
      body: Column(
        children: [
          // 顶部：设备选择器与刷新
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'adb 路径：',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.controller.adbPath,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButton<AdbDevice>(
                            value: _selected,
                            hint: const Text('选择设备'),
                            isExpanded: true,
                            items: _devices
                                .map(
                                  (d) => DropdownMenuItem<AdbDevice>(
                                    value: d,
                                    child: Text(d.serial),
                                  ),
                                )
                                .toList(),
                            onChanged: (d) {
                              setState(() => _selected = d);
                              if (d != null) {
                                setState(() => _status = '已选择设备：${d.serial}');
                              }
                            },
                            underline: const SizedBox(),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                            onPressed: _loading ? null : _refreshDevices,
                            tooltip: '刷新设备列表',
                          ),
                          const Text('刷新', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _loading
                              ? Colors.orange.withValues(alpha: 26)
                              : Colors.green.withValues(alpha: 26),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _loading
                                ? Colors.orange
                                : Colors.green.withValues(alpha: 76),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_loading)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            if (_loading) const SizedBox(width: 6),
                            Text(
                              _status,
                              style: TextStyle(
                                fontSize: 12,
                                color: _loading
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 遥控器按键区域：模拟真实遥控器布局
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第 1 行：电源 | HOME | BACK | 菜单
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _keyButton(remoteKeys[0]), // 电源
                      const SizedBox(width: 10),
                      _keyButton(remoteKeys[1]), // HOME
                      const SizedBox(width: 10),
                      _keyButton(remoteKeys[2]), // BACK
                      const SizedBox(width: 10),
                      _keyButton(remoteKeys[3]), // 菜单
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 第 2 行：       上
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _spacer(),
                      _keyButton(remoteKeys[4]), // 上
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第 3 行：左 | 确定 | 右
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _keyButton(remoteKeys[6]), // 左
                      const SizedBox(width: 6),
                      _keyButton(remoteKeys[8]), // 确定（居中）
                      const SizedBox(width: 6),
                      _keyButton(remoteKeys[7]), // 右
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第 4 行：       下
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _spacer(),
                      _keyButton(remoteKeys[5]), // 下
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 第 5 行：音量- | 音量+ | 静音
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _keyButton(remoteKeys[10]), // 音量-
                      const SizedBox(width: 8),
                      _keyButton(remoteKeys[9]), // 音量+
                      const SizedBox(width: 8),
                      _keyButton(remoteKeys[11]), // 静音
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 第 6 行：播放/暂停 | 上一首 | 下一首
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _keyButton(remoteKeys[12]), // 播放/暂停
                      const SizedBox(width: 8),
                      _keyButton(remoteKeys[13]), // 上一首
                      const SizedBox(width: 8),
                      _keyButton(remoteKeys[14]), // 下一首
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 第 7 行：唤醒 | 休眠
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _keyButton(remoteKeys[16]), // 休眠
                      const SizedBox(width: 8),
                      _keyButton(remoteKeys[15]), // 唤醒
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 第 8 行：回车 | 删除 | 相机 | 搜索
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _keyButton(remoteKeys[17]), // 回车
                      const SizedBox(width: 8),
                      _keyButton(remoteKeys[18]), // 删除
                      const SizedBox(width: 8),
                      _keyButton(remoteKeys[19]), // 相机
                      const SizedBox(width: 8),
                      _keyButton(remoteKeys[20]), // 搜索
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
