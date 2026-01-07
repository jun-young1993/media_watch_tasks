import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'drift_database.g.dart';

class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class MediaStates extends Table {
  TextColumn get assetId => text()();
  IntColumn get createdAtMsUtc => integer()();
  TextColumn get hash => text().nullable()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();
  IntColumn get firstSeenAtMsUtc => integer()();
  IntColumn get uploadedAtMsUtc => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {assetId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {hash},
      ];
}

class UploadTaskRows extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get assetId => text()();
  IntColumn get createdAtMsUtc => integer()();

  /// 'pending' | 'uploading' | 'success' | 'failed'
  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get nextRunAtMsUtc => integer().nullable()();

  IntColumn get lockedAtMsUtc => integer().nullable()();
  TextColumn get lockId => text().nullable()();

  TextColumn get lastError => text().nullable()();
  IntColumn get updatedAtMsUtc => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {assetId},
      ];
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'media_watch_tasks.sqlite'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(tables: [AppMeta, MediaStates, UploadTaskRows])
class MediaWatchDatabase extends _$MediaWatchDatabase {
  MediaWatchDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {},
      );
}
