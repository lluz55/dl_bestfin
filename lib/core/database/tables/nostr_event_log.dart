import 'package:drift/drift.dart';

@TableIndex(name: 'nostr_event_log_published_idx', columns: {#published})
@DataClassName('NostrEventLogItem')
class NostrEventLog extends Table {
  /// SHA256 event id (64-char hex) — Nostr canonical id.
  TextColumn get eventId => text()();

  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// AES-256-GCM encrypted payload (base64url) — same format as SyncQueue.
  TextColumn get payload => text()();

  IntColumn get updatedAt => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Whether this event has been successfully published to at least one relay.
  BoolColumn get published => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {eventId};
}
