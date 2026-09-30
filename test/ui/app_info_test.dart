import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/ui/app_info.dart';

void main() {
  test('アプリ情報のバージョンが pubspec.yaml と一致する', () {
    final source = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(source);
    expect(match, isNotNull);
    expect(AppInfo.version, match!.group(1));
  });

  test('表示するバージョンはビルド番号を含まない', () {
    expect(AppInfo.versionName, AppInfo.version.split('+').first);
    expect(AppInfo.versionName, '1.0.0');
  });
}
