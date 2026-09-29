import 'package:sqflite/sqflite.dart';

import 'seed.dart';

/// docs/db/schema.sql を唯一のスキーマ定義として使い、DB を開く。
class AppDatabase {
  static const fileName = 'subsc_management.db';
  static const schemaAsset = 'docs/db/schema.sql';
  static const version = 7;

  static Future<Database> open({
    required DatabaseFactory factory,
    required String path,
    required String schemaSql,
  }) {
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        // 外部キーは接続ごとに有効化が必要
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          final batch = db.batch();
          for (final statement in splitSqlStatements(schemaSql)) {
            batch.execute(statement);
          }
          seedMasterData(batch);
          await batch.commit(noResult: true);
          await seedMasterDataV2(db);
          await seedMasterDataV3(db);
          await seedMasterDataV4(db);
          await seedMasterDataV5(db);
          await seedMasterDataV6(db);
          await seedMasterDataV7(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await seedMasterDataV2(db);
          if (oldVersion < 3) await seedMasterDataV3(db);
          if (oldVersion < 4) await seedMasterDataV4(db);
          if (oldVersion < 5) await seedMasterDataV5(db);
          if (oldVersion < 6) await seedMasterDataV6(db);
          if (oldVersion < 7) await seedMasterDataV7(db);
        },
      ),
    );
  }
}

/// SQL スクリプトを 1 文ずつに分割する（sqflite の execute は 1 文ずつしか実行できないため）。
/// `--` コメントを除去し、トリガーは `END;` までを 1 文として扱う。PRAGMA は onConfigure で行うので除外。
List<String> splitSqlStatements(String script) {
  final statements = <String>[];
  final buffer = StringBuffer();
  var inTrigger = false;

  for (final rawLine in script.split('\n')) {
    final commentAt = rawLine.indexOf('--');
    final line = (commentAt >= 0 ? rawLine.substring(0, commentAt) : rawLine).trimRight();
    if (line.trim().isEmpty) continue;

    if (buffer.isEmpty && line.trimLeft().toUpperCase().startsWith('CREATE TRIGGER')) {
      inTrigger = true;
    }
    buffer.writeln(line);

    final ended = inTrigger ? line.trim().toUpperCase() == 'END;' : line.endsWith(';');
    if (ended) {
      final statement = buffer.toString().trim();
      if (!statement.toUpperCase().startsWith('PRAGMA')) statements.add(statement);
      buffer.clear();
      inTrigger = false;
    }
  }
  return statements;
}
