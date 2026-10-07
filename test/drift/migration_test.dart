// Migration tests (ТЗ 9.2). For every new schema version:
//   1. bump `schemaVersion` and add a step to `onUpgrade`;
//   2. dart run drift_dev make-migrations  (writes drift_schemas/…/vN.json);
//   3. dart run drift_dev schema generate drift_schemas/tabiya test/drift/tabiya/generated
//   4. add a `migrateAndValidate(db, N)` case below.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';

import 'tabiya/generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('fresh database matches schema v1', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });

  test('current schema version is covered by a snapshot', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(GeneratedHelper.versions, contains(db.schemaVersion));
    db.close();
  });
}
