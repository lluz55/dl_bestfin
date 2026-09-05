import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/sync/domain/models/household.dart';

/// Grupos familiares: criação, convite de membros, papéis e remoção.
class HouseholdsScreen extends Screen {
  HouseholdsScreen(super.ctx);

  @override
  String get title => 'Grupos familiares';

  static String _roleLabel(MemberRole role) => switch (role) {
    MemberRole.viewer => 'Leitura',
    MemberRole.editor => 'Edição',
    MemberRole.admin => 'Administrador',
  };

  @override
  Future<void> run() async {
    while (true) {
      final households = await ctx.households.watchAll().first;

      final items = households
          .map(
            (h) =>
                '${Term.pad(h.name, 28)} '
                '${Term.gray}${h.members.length} membro(s) • '
                'criado em ${Term.formatDate(h.createdAt)}${Term.reset}',
          )
          .toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle: 'Compartilhe os dados com quem divide as contas com você',
        emptyMessage: 'Nenhum grupo. "n" cria o primeiro.',
        actions: const [
          TermAction('n', 'novo grupo'),
          TermAction('d', 'excluir'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final household = i >= 0 && i < households.length ? households[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'd':
          if (household != null) await _delete(household);
        case '':
          if (household != null) await _members(household);
      }
    }
  }

  Future<void> _members(HouseholdModel household) async {
    while (true) {
      final fresh = (await ctx.households.watchAll().first)
          .where((h) => h.id == household.id)
          .firstOrNull;
      if (fresh == null) return;

      final items = fresh.members
          .map(
            (m) =>
                '${Term.pad(m.email, 32)} '
                '${Term.pad(_roleLabel(m.role), 16)} '
                '${m.accepted ? Term.c('aceito', Term.green) : Term.c('convite pendente', Term.yellow)}',
          )
          .toList();

      final choice = listMenu(
        'Membros — ${fresh.name}',
        items: items,
        subtitle: 'Criado por ${fresh.createdBy}',
        emptyMessage: 'Nenhum membro convidado. "i" envia um convite.',
        actions: const [
          TermAction('i', 'convidar'),
          TermAction('p', 'alterar papel'),
          TermAction('r', 'remover'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final member = i >= 0 && i < fresh.members.length
          ? fresh.members[i]
          : null;
      switch (key) {
        case 'i':
          await _invite(fresh);
        case 'p':
          if (member != null) await _changeRole(member);
        case 'r':
          if (member != null) await _removeMember(member);
      }
    }
  }

  Future<void> _create() async {
    Term.clear();
    Term.header('Novo grupo familiar');
    Term.writeln();

    final name = Term.input('Nome do grupo:', allowEmpty: false);
    if (name == null || name.trim().isEmpty) return;

    final createdBy = Term.input(
      'Seu e-mail/identificador:',
      allowEmpty: false,
    );
    if (createdBy == null || createdBy.trim().isEmpty) return;

    await guard(
      () => ctx.households.createHousehold(name.trim(), createdBy.trim()),
      successMessage: 'Grupo "${name.trim()}" criado.',
    );
  }

  Future<void> _invite(HouseholdModel household) async {
    Term.clear();
    Term.header('Convidar para ${household.name}');
    Term.writeln();

    final email = Term.input('E-mail do convidado:', allowEmpty: false);
    if (email == null || email.trim().isEmpty) return;

    final role = Term.pick<MemberRole>('Papel', MemberRole.values, _roleLabel);
    if (role == null) return;

    await guard(
      () => ctx.households.inviteMember(
        householdId: household.id,
        email: email.trim(),
        role: role,
      ),
      successMessage: 'Convite registrado para ${email.trim()}.',
    );
  }

  Future<void> _changeRole(HouseholdMemberModel member) async {
    final role = Term.pick<MemberRole>(
      'Novo papel de ${member.email}',
      MemberRole.values,
      _roleLabel,
      initialIndex: MemberRole.values.indexOf(member.role),
    );
    if (role == null) return;
    await guard(
      () => ctx.households.updateMemberRole(member.id, role),
      successMessage: 'Papel atualizado.',
    );
  }

  Future<void> _removeMember(HouseholdMemberModel member) async {
    if (!Term.confirm('Remover ${member.email} do grupo?')) return;
    await guard(
      () => ctx.households.removeMember(member.id),
      successMessage: 'Membro removido.',
    );
  }

  Future<void> _delete(HouseholdModel household) async {
    if (!Term.confirm('Excluir o grupo "${household.name}"?')) return;
    await guard(
      () => ctx.households.deleteHousehold(household.id),
      successMessage: 'Grupo excluído.',
    );
  }
}
