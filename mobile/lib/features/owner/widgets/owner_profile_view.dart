import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data_provider.dart';
import '../../../theme.dart';
import '../../auth/auth_provider.dart';

/// The signed-in owner's own account page.
///
/// Every field comes from data already loaded: the `employees/{uid}` document
/// that lives in the AppData snapshot, with the auth session filling whatever
/// that document does not carry (or standing in entirely, for a salon whose
/// owner was provisioned without an employee record). Opening this page
/// therefore costs no Firestore read.
class OwnerProfileView extends ConsumerWidget {
  const OwnerProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(appDataProvider).valueOrNull;
    final me = state?.employeeById(auth.userId ?? '');

    final name = me?.name ?? auth.name ?? 'Owner';
    final email = me?.email.isNotEmpty == true ? me!.email : (auth.email ?? '-');
    final phone = me?.phone.isNotEmpty == true ? me!.phone : null;
    final role = me?.roleTitle.isNotEmpty == true ? me!.roleTitle : 'Owner';
    final branch = me?.branchName ??
        state?.branches.where((b) => b.id == me?.branchId).map((b) => b.name).firstOrNull;
    final salonName = state?.settings?.salonName ?? auth.salonName ?? 'Salon';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _identityCard(name: name, role: role, salonName: salonName),
          const SizedBox(height: 14),

          _section(
            title: 'Account',
            rows: [
              _Row(PhosphorIconsRegular.envelopeSimple, 'Email', email),
              if (phone != null) _Row(PhosphorIconsRegular.phone, 'Phone', phone),
              // The Firebase Auth uid. Worth showing because it is the id of
              // the owner's employees/{uid} document, which is what anyone
              // fixing a permissions problem in the Console needs.
              if (auth.userId != null)
                _Row(PhosphorIconsRegular.identificationCard, 'User ID', auth.userId!),
            ],
          ),
          const SizedBox(height: 14),

          _section(
            title: 'Salon',
            rows: [
              _Row(PhosphorIconsRegular.storefront, 'Salon', salonName),
              if (auth.salonId != null)
                _Row(PhosphorIconsRegular.hash, 'Salon ID', auth.salonId!),
              if (branch != null) _Row(PhosphorIconsRegular.buildings, 'Branch', branch),
              _Row(
                PhosphorIconsRegular.usersThree,
                'Team',
                '${state?.employees.length ?? 0} staff',
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (me == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'No staff record is linked to this login, so only the details '
                'from the sign-in session are shown here.',
                style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF92400E)),
              ),
            ),
          if (me == null) const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(PhosphorIconsRegular.signOut, color: AppTheme.accentRed),
              label: const Text(
                'Log Out',
                style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFECDCA)),
                backgroundColor: AppTheme.accentRedBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard({
    required String name,
    required String role,
    required String salonName,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1B4B),
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(name),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.slateDark),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            salonName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppTheme.slateLight),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required List<_Row> rows}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(rows[i].icon, size: 17, color: const Color(0xFF94A3B8)),
                  const SizedBox(width: 12),
                  Text(
                    rows[i].label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'OW';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _Row {
  final IconData icon;
  final String label;
  final String value;

  const _Row(this.icon, this.label, this.value);
}
