import 'package:drift/drift.dart';
import 'transactions.dart';

@TableIndex(
  name: 'scheduled_reminders_transaction_idx',
  columns: {#transactionId},
)
@DataClassName('ScheduledReminder')
class ScheduledReminders extends Table {
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();

  /// Id estável usado para agendar/cancelar a notificação no SO.
  IntColumn get notificationId => integer()();

  /// Snapshot da data da transação no momento do agendamento (detecta edição).
  DateTimeColumn get transactionDate => dateTime()();

  /// Snapshot da antecedência (em minutos) usada para calcular [scheduledFor].
  IntColumn get leadTimeMinutes => integer()();

  /// Horário efetivo em que a notificação foi agendada para disparar.
  DateTimeColumn get scheduledFor => dateTime()();

  /// Preenchido quando a notificação já foi exibida (via checagem própria de
  /// "vencidos" — necessário pois o plugin não agenda nativamente no Linux).
  DateTimeColumn get firedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {transactionId};
}
