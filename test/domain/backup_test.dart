import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/backup.dart';

BackupSnapshot _fullSnapshot() => BackupSnapshot(
  categories: [const BackupCategory(id: 'cat-1', name: '生活', sortOrder: 0)],
  items: [
    BackupItem(
      id: 'item-1',
      name: '歯ブラシ交換',
      icon: 'brush',
      categoryId: 'cat-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 9, 30),
      sortOrder: 0,
    ),
    BackupItem(
      id: 'item-2',
      name: '未分類・未実施の項目',
      icon: null,
      categoryId: null,
      createdAt: DateTime.utc(2026, 2, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
      sortOrder: 1,
    ),
  ],
  doneLogs: [
    BackupDoneLog(
      id: 'log-1',
      itemId: 'item-1',
      doneAt: DateTime.utc(2026, 9, 20),
    ),
  ],
);

Map<String, dynamic> _decodeJson(String json) =>
    jsonDecode(json) as Map<String, dynamic>;

List<int> _bytesOf(Map<String, dynamic> map) => utf8.encode(jsonEncode(map));

Map<String, dynamic> _validTop() => {
  'format': backupFormatId,
  'version': backupFormatVersion,
  'exportedAt': 1790000000000,
  'categories': <Map<String, dynamic>>[],
  'items': <Map<String, dynamic>>[],
  'doneLogs': <Map<String, dynamic>>[],
};

void main() {
  group('encodeBackup / decodeBackup の往復', () {
    test('全フィールドが一致する(null の icon / categoryId・記録 0 件の項目を含む)', () {
      final snapshot = _fullSnapshot();
      final json = encodeBackup(
        snapshot,
        exportedAt: DateTime.utc(2026, 9, 30, 12),
      );
      final decoded = decodeBackup(utf8.encode(json));

      expect(decoded.categories, snapshot.categories);
      expect(decoded.items, snapshot.items);
      expect(decoded.doneLogs, snapshot.doneLogs);
    });

    test('format と version が入り、日時は UTC ミリ秒の整数になる', () {
      // ローカル時刻の DateTime を渡しても UTC の値になる。
      final localExportedAt = DateTime.utc(2026, 9, 30, 12).toLocal();
      final snapshot = _fullSnapshot();
      final json = encodeBackup(snapshot, exportedAt: localExportedAt);
      final map = _decodeJson(json);

      expect(map['format'], 'lastwhen-backup');
      expect(map['version'], 1);
      expect(map['exportedAt'], localExportedAt.toUtc().millisecondsSinceEpoch);
      final item = (map['items'] as List)[0] as Map<String, dynamic>;
      expect(
        item['createdAt'],
        snapshot.items[0].createdAt.millisecondsSinceEpoch,
      );
      expect(
        item['updatedAt'],
        snapshot.items[0].updatedAt.millisecondsSinceEpoch,
      );
      final log = (map['doneLogs'] as List)[0] as Map<String, dynamic>;
      expect(log['doneAt'], snapshot.doneLogs[0].doneAt.millisecondsSinceEpoch);
    });

    test('null の icon / categoryId はキーを省かず null で書く', () {
      final snapshot = _fullSnapshot();
      final json = encodeBackup(
        snapshot,
        exportedAt: DateTime.utc(2026, 9, 30),
      );
      final map = _decodeJson(json);
      final item = (map['items'] as List)[1] as Map<String, dynamic>;
      expect(item.containsKey('icon'), isTrue);
      expect(item['icon'], isNull);
      expect(item.containsKey('categoryId'), isTrue);
      expect(item['categoryId'], isNull);
    });
  });

  group('backupFileNameOf', () {
    test('ローカル日付でゼロ埋めされたファイル名になる', () {
      expect(
        backupFileNameOf(DateTime(2026, 1, 5, 23, 59)),
        'lastwhen-backup-20260105.json',
      );
    });
  });

  group('decodeBackup: notBackupFile', () {
    test('UTF-8 でないバイト列', () {
      expect(
        () => decodeBackup([0xFF, 0xFE, 0xFD]),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.notBackupFile,
          ),
        ),
      );
    });

    test('JSON でない', () {
      expect(
        () => decodeBackup(utf8.encode('これは json ではない')),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.notBackupFile,
          ),
        ),
      );
    });

    test('トップが配列', () {
      expect(
        () => decodeBackup(utf8.encode(jsonEncode([1, 2, 3]))),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.notBackupFile,
          ),
        ),
      );
    });

    test('format 違い', () {
      final top = _validTop()..['format'] = 'other-format';
      expect(
        () => decodeBackup(_bytesOf(top)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.notBackupFile,
          ),
        ),
      );
    });

    test('version が文字列', () {
      final top = _validTop()..['version'] = '1';
      expect(
        () => decodeBackup(_bytesOf(top)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.notBackupFile,
          ),
        ),
      );
    });

    test('version が 0', () {
      final top = _validTop()..['version'] = 0;
      expect(
        () => decodeBackup(_bytesOf(top)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.notBackupFile,
          ),
        ),
      );
    });

    test('上限 + 1 バイト', () {
      final oversized = List<int>.filled(maxBackupFileBytes + 1, 0x20);
      expect(
        () => decodeBackup(oversized),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.notBackupFile,
          ),
        ),
      );
    });
  });

  group('decodeBackup: newerVersion', () {
    test('version が現在のバージョンより大きい', () {
      final top = _validTop()..['version'] = backupFormatVersion + 1;
      expect(
        () => decodeBackup(_bytesOf(top)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.newerVersion,
          ),
        ),
      );
    });
  });

  group('decodeBackup: invalidContent', () {
    void expectInvalid(Map<String, dynamic> top) {
      expect(
        () => decodeBackup(_bytesOf(top)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.invalidContent,
          ),
        ),
        reason: jsonEncode(top),
      );
    }

    Map<String, dynamic> validItem({String? categoryId}) => {
      'id': 'item-1',
      'name': '項目',
      'icon': null,
      'categoryId': categoryId,
      'createdAt': 100,
      'updatedAt': 100,
      'sortOrder': 0,
    };

    test('項目に icon キーが無い', () {
      final item = validItem()..remove('icon');
      final top = _validTop()..['items'] = [item];
      expectInvalid(top);
    });

    test('日時が 1.0(double)', () {
      final item = validItem()..['createdAt'] = 1.0;
      final top = _validTop()..['items'] = [item];
      expectInvalid(top);
    });

    test('日時が負', () {
      final item = validItem()..['createdAt'] = -1;
      final top = _validTop()..['items'] = [item];
      expectInvalid(top);
    });

    test('id が空文字', () {
      final item = validItem()..['id'] = '';
      final top = _validTop()..['items'] = [item];
      expectInvalid(top);
    });

    test('id が重複', () {
      final top = _validTop()..['items'] = [validItem(), validItem()];
      expectInvalid(top);
    });

    test('存在しない categoryId', () {
      final item = validItem(categoryId: 'missing-category');
      final top = _validTop()..['items'] = [item];
      expectInvalid(top);
    });

    test('存在しない itemId(記録)', () {
      final top = _validTop()
        ..['doneLogs'] = [
          {'id': 'log-1', 'itemId': 'missing-item', 'doneAt': 100},
        ];
      expectInvalid(top);
    });

    test('空の項目名', () {
      final item = validItem()..['name'] = '';
      final top = _validTop()..['items'] = [item];
      expectInvalid(top);
    });

    test('51 文字の項目名', () {
      final item = validItem()..['name'] = 'あ' * 51;
      final top = _validTop()..['items'] = [item];
      expectInvalid(top);
    });

    test('重複したカテゴリ名', () {
      final top = _validTop()
        ..['categories'] = [
          {'id': 'cat-1', 'name': '生活', 'sortOrder': 0},
          {'id': 'cat-2', 'name': '生活', 'sortOrder': 1},
        ];
      expectInvalid(top);
    });

    test('配列の要素が文字列', () {
      final top = _validTop()..['items'] = ['not-a-map'];
      expectInvalid(top);
    });
  });

  test('どの不正入力でも BackupFormatException 以外が出ない', () {
    final inputs = <List<int>>[
      [0xFF, 0xFE],
      utf8.encode('not json'),
      utf8.encode(jsonEncode([1, 2, 3])),
      utf8.encode(jsonEncode({'format': 'x'})),
      _bytesOf(_validTop()..['items'] = [1, 2, 3]),
      _bytesOf(
        _validTop()
          ..['items'] = [
            {
              'id': 'a',
              'name': 1,
              'icon': null,
              'categoryId': null,
              'createdAt': 1,
              'updatedAt': 1,
              'sortOrder': 0,
            },
          ],
      ),
    ];
    for (final input in inputs) {
      expect(() => decodeBackup(input), throwsA(isA<BackupFormatException>()));
    }
  });
}
