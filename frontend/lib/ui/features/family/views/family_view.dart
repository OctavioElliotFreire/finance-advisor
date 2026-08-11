import 'package:flutter/material.dart';

import '../../../../data/models/household_member.dart';
import '../../../../data/models/pluggy_connection.dart';
import '../../../../data/repositories/connection_repository.dart';
import '../../../../data/repositories/household_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../core/formatting/role_label.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../../connections/view_models/connections_view_model.dart';
import '../../connections/views/connections_view.dart';
import '../../households/view_models/members_view_model.dart';
import '../../households/views/member_access_view.dart';
import '../../households/views/members_view.dart';
import '../widgets/connection_health_row.dart';

/// Família tab — per-member connection health, per `design.md`'s 6.7.
///
/// Known simplification: this merges the *read view* of members+connections
/// (reusing [MembersViewModel]/[ConnectionsViewModel] as-is, no backend
/// changes) into one grouped screen, but mutation flows (invite a member,
/// connect a new institution, edit access grants) still push the existing
/// standalone [MembersView]/[ConnectionsView]/[MemberAccessView] rather than
/// being rebuilt inline here — that's more UI work than a routing
/// restructure alone justifies. The renew/reconnect CTA copy from the
/// handoff ("Pedir para Ana renovar") and the 30/7-day expiry warnings are
/// NOT implemented — they need Pluggy consent-expiry data that was never
/// confirmed to exist (see `design.md`'s Open Questions; deliberately
/// parked, not an oversight).
class FamilyView extends StatefulWidget {
  const FamilyView({
    super.key,
    required this.householdRepository,
    required this.connectionRepository,
    required this.householdId,
    this.currentUserEmail,
  });

  final HouseholdRepository householdRepository;
  final ConnectionRepository connectionRepository;
  final String householdId;
  final String? currentUserEmail;

  @override
  State<FamilyView> createState() => _FamilyViewState();
}

class _FamilyViewState extends State<FamilyView> {
  late final _membersViewModel = MembersViewModel(
    householdRepository: widget.householdRepository,
    householdId: widget.householdId,
  )..load();

  late final _connectionsViewModel = ConnectionsViewModel(
    connectionRepository: widget.connectionRepository,
    householdId: widget.householdId,
  )..load();

  @override
  void dispose() {
    _membersViewModel.dispose();
    _connectionsViewModel.dispose();
    super.dispose();
  }

  (StatusTone, String) _connectionHealth(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => (StatusTone.neutral, 'Aguardando primeira sincronização'),
      'UPDATED' => (StatusTone.neutral, 'Ativo'),
      'UPDATING' => (StatusTone.info, 'Atualizando…'),
      'OUTDATED' => (StatusTone.warning, 'Desatualizado'),
      'WAITING_USER_INPUT' => (StatusTone.warning, 'Requer atenção'),
      'LOGIN_ERROR' => (StatusTone.negative, 'Erro de login'),
      'ERROR' => (StatusTone.negative, 'Erro'),
      _ => (StatusTone.neutral, status),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Família'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Gerenciar membros',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MembersView(
                  householdRepository: widget.householdRepository,
                  householdId: widget.householdId,
                  householdName: 'Família',
                  currentUserEmail: widget.currentUserEmail,
                  onManageAccess: (memberId, memberEmail) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MemberAccessView(
                        householdRepository: widget.householdRepository,
                        householdId: widget.householdId,
                        memberId: memberId,
                        memberEmail: memberEmail,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Conectar instituição',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConnectionsView(
                  connectionRepository: widget.connectionRepository,
                  householdId: widget.householdId,
                  householdName: 'Família',
                  currentUserEmail: widget.currentUserEmail,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_membersViewModel, _connectionsViewModel]),
        builder: (context, _) {
          final isLoading =
              (_membersViewModel.isLoading && _membersViewModel.members.isEmpty) ||
              (_connectionsViewModel.isLoading && _connectionsViewModel.connections.isEmpty);
          if (isLoading) {
            return const LoadingState();
          }

          final members = _membersViewModel.members;
          if (members.isEmpty) {
            return const AppEmptyState(icon: Icons.groups_outlined, title: 'Nenhum membro ainda');
          }

          final connectionsByEmail = <String, List<PluggyConnection>>{};
          for (final connection in _connectionsViewModel.connections) {
            final email = connection.createdByEmail;
            if (email != null) {
              connectionsByEmail.putIfAbsent(email, () => []).add(connection);
            }
          }

          return RefreshIndicator(
            onRefresh: () => Future.wait([_membersViewModel.load(), _connectionsViewModel.load()]),
            child: AppGridPage(
              children: [
                ErrorBanner(message: _membersViewModel.errorMessage),
                ErrorBanner(message: _connectionsViewModel.errorMessage),
                for (var i = 0; i < members.length; i++)
                  _MemberSection(
                    member: members[i],
                    color: AppMemberColors.forIndex(i),
                    connections: connectionsByEmail[members[i].email] ?? const [],
                    connectionHealth: _connectionHealth,
                  ),
                const SizedBox(height: 8),
                Text(
                  'Cada membro pode desconectar suas próprias contas quando quiser.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemberSection extends StatelessWidget {
  const _MemberSection({
    required this.member,
    required this.color,
    required this.connections,
    required this.connectionHealth,
  });

  final HouseholdMember member;
  final Color color;
  final List<PluggyConnection> connections;
  final (StatusTone, String) Function(String status) connectionHealth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: member.email,
              trailing: Text(roleLabel(member.role), style: Theme.of(context).textTheme.bodySmall),
            ),
            if (connections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Nenhuma conta conectada', style: Theme.of(context).textTheme.bodySmall),
              )
            else
              for (final connection in connections)
                Builder(
                  builder: (context) {
                    final (tone, statusText) = connectionHealth(connection.status);
                    return ConnectionHealthRow(
                      label: connection.pluggyItemId,
                      statusText: statusText,
                      tone: tone,
                      dotColor: tone == StatusTone.neutral ? color : null,
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}
