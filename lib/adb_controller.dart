import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 表示一台 adb 可见的设备。
class AdbDevice {
  final String serial;
  AdbDevice({required this.serial});
  @override
  String toString() => serial;
}

/// ADB 后端控制器：负责调用本地 adb 命令查询设备与发送按键码。
///
/// UI 层不直接调用 `dart:io`，全部通过本类完成，便于单独测试与维护。
class AdbController {
  /// adb 可执行文件路径。优先使用 [adbPath] 构造参数，其次读取
  /// 环境变量 `ADB_PATH`，最后回退到 `PATH` 中的 `adb`。
  final String _adbPath;

  AdbController({String? adbPath})
      : _adbPath = adbPath ?? Platform.environment['ADB_PATH'] ?? 'adb';

  /// 当前实际使用的 adb 可执行文件路径。
  String get adbPath => _adbPath;

  /// 兼容不同 Dart 版本中 Process 返回的 stdout/stderr 类型（整数列表或字符串）。
  static String _decode(dynamic data) {
    if (data is List<int>) {
      return utf8.decode(data);
    }
    return data.toString();
  }

  /// 运行 `adb devices -l` 并解析出状态为 `device` 的设备列表。
  ///
  /// 失败时抛出 [Exception]，携带原始错误信息。
  Future<List<AdbDevice>> queryDevices() async {
    try {
      final result = await Process.run(
        _adbPath,
        ['devices', '-l'],
      ).timeout(const Duration(seconds: 10));

      final stdout = _decode(result.stdout);
      final stderr = _decode(result.stderr);

      // adb 命令本身退出非零，视为失败。
      if (result.exitCode != 0) {
        throw Exception('adb devices -l 退出码 ${result.exitCode}: '
            '${stderr.isNotEmpty ? stderr : stdout}');
      }

      final found = <AdbDevice>[];
      for (final line in stdout.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('List of devices')) {
          continue;
        }
        final parts = trimmed.split(RegExp(r'\s+'));
        // 格式示例：
        //   <serial>\tdevice product:... model:... device:... transport_id:...
        // mDNS 发现的设备可能形如：
        //   adb-xxxx._adb-tls-connect._tcp device ...
        if (parts.length >= 2 && parts[1] == 'device') {
          found.add(AdbDevice(serial: parts[0]));
        }
      }

      return found;
    } on TimeoutException {
      throw Exception('查询设备超时：请确认 adb 已就绪且未被占用');
    } on ProcessException catch (e) {
      throw Exception('无法执行 adb 命令（$_adbPath）：$e');
    } catch (e) {
      throw Exception('查询设备失败：$e');
    }
  }

  /// 向指定设备发送 keyevent：`adb -s <serial> shell input keyevent <code>`
  ///
  /// 成功返回 `true`，失败抛出 [Exception]。
  Future<void> sendKeyEvent(String serial, int keycode) async {
    try {
      final result = await Process.run(
        _adbPath,
        [
          '-s',
          serial,
          'shell',
          'input',
          'keyevent',
          keycode.toString(),
        ],
      ).timeout(const Duration(seconds: 10));

      final stdout = _decode(result.stdout).trim();
      final stderr = _decode(result.stderr).trim();

      if (result.exitCode != 0) {
        throw Exception(
          '发送 keycode=$keycode 失败（退出码 ${result.exitCode}）: '
          '${stderr.isNotEmpty ? stderr : stdout}',
        );
      }
    } on TimeoutException {
      throw Exception('发送按键超时：设备可能未响应');
    } on ProcessException catch (e) {
      throw Exception('无法执行 adb 命令（$_adbPath）：$e');
    } catch (e) {
      rethrow;
    }
  }
}
