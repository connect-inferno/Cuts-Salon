import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../theme.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/async_state_views.dart';

/// The archived-client list, as a section of Client Settings.
///
/// Archiving is reversible and the documents are never deleted (see the
/// comment on [Customer.archived] and the customer-delete rule in
/// firestore.rules), so the only thing missing was somewhere to see what
/// had been archived and put it back. The main directory used to carry an
/// "Archived" filter chip mixed in with All/VIP/Recent, which put a rarely
/// used recovery tool next to the everyday filters.
class OwnerArchivedClientsView extends ConsumerWidget {
  const OwnerArchivedClientsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appDataProvider);

    return asyncData.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(
        error: err,
        onRetry: () => ref.read(appDataProvider.notifier).refresh(),
      ),
      data: (state) {
        final archived = state.archivedCustomers;
        if (archived.isEmpty) {
          return const _EmptyArchive();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: archived.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ArchivedRow(customer: archived[i]),
        );
      },
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsRegular.archive, size: 30, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nothing archived',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.slateDark,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Archiving a client hides them from the directory and from '
              'billing. Their past bills are always kept.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.slateLight,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedRow extends ConsumerStatefulWidget {
  final Customer customer;

  const _ArchivedRow({required this.customer});

  @override
  ConsumerState<_ArchivedRow> createState() => _ArchivedRowState();
}

class _ArchivedRowState extends ConsumerState<_ArchivedRow> {
  bool _restoring = false;

  Future<void> _confirmRestore() async {
    final cust = widget.customer;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: PhosphorIconsRegular.arrowCounterClockwise,
        title: 'Restore ${cust.name}?',
        child: const Text(
          'They will appear in the client directory and can be billed again.',
          style: TextStyle(fontSize: 14, color: AppTheme.slateMedium),
        ),
        actions: AppDialogActions(
          submitLabel: 'Restore',
          onCancel: () => Navigator.pop(ctx, false),
          onSubmit: () => Navigator.pop(ctx, true),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _restoring = true);
    try {
      await ref.read(appDataProvider.notifier).unarchiveCustomer(cust.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cust.name} restored.'),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _restoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cust = widget.customer;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(PhosphorIconsFill.userMinus, size: 19, color: AppTheme.slateLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cust.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slateDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${cust.phone} · ${cust.visitCount} visit${cust.visitCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slateLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_restoring)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            OutlinedButton(
              onPressed: _confirmRestore,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                side: const BorderSide(color: AppTheme.borderStrong),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text(
                'Restore',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slateMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
