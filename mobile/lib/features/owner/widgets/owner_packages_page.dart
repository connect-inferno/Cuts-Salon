import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/client_package.dart';
import '../../../data/models.dart';
import '../../../data/money.dart';
import '../../../theme.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/async_state_views.dart';
import '../../../widgets/searchable_picker.dart';

String packageDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String planLabel(PackagePlan p) => 'Pay ${formatInr(p.pay)}, get ${formatInr(p.worth)}';

String planValidity(PackagePlan p) => 'Valid for ${p.months} month${p.months == 1 ? '' : 's'}';

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: error ? AppTheme.accentRed : AppTheme.accentGreen),
  );
}

String _reason(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Menu > Packages: what the salon offers, and who holds credit.
class OwnerPackagesPage extends ConsumerWidget {
  const OwnerPackagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(appDataProvider).when(
          loading: () => const AppLoadingView(),
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
          data: (state) => _buildBody(context, ref, state),
        );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppData state) {
    final plans = state.settings?.packagePlans ?? const <PackagePlan>[];
    final now = DateTime.now();
    final held = [...state.clientPackages]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    final clients = {for (final c in [...state.customers, ...state.archivedCustomers]) c.id: c.name};
    final live = held.where((p) => p.isUsableAt(now)).toList();
    final totalCredit = live.fold<double>(0, (sum, p) => sum + p.balance);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading('Packages on offer', action: 'Add plan', onAction: () => _showPlanDialog(context, ref, plans)),
              _card([
                if (plans.isEmpty)
                  const _Note('No packages yet. Add one to start selling prepaid credit.')
                else
                  for (var i = 0; i < plans.length; i++)
                    _row(
                      title: planLabel(plans[i]),
                      subtitle: planValidity(plans[i]),
                      onTap: () => _showPlanDialog(context, ref, plans, index: i),
                    ),
              ]),
              const SizedBox(height: 20),
              _heading(
                'Clients with credit',
                trailing: totalCredit > 0 ? '${formatInr(totalCredit)} held' : null,
              ),
              _card([
                if (held.isEmpty)
                  const _Note('Packages you sell show here until the credit is used.')
                else
                  for (final p in held)
                    _row(
                      title: clients[p.customerId] ?? 'Unknown client',
                      subtitle: p.isUsableAt(now)
                          ? 'Expires ${packageDate(p.expiresAt)}'
                          : 'Expired ${packageDate(p.expiresAt)}',
                      value: '${formatInr(p.balance)} of ${formatInr(p.creditValue)}',
                      warn: !p.isUsableAt(now),
                    ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String text, {String? action, VoidCallback? onAction, String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
          ),
          if (trailing != null)
            Text(trailing, style: const TextStyle(fontSize: 13, color: AppTheme.slateLight)),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  '+ $action',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.borderSubtle),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row({required String title, required String subtitle, String? value, bool warn = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: warn ? AppTheme.accentRed : AppTheme.slateLight),
                  ),
                ],
              ),
            ),
            if (value != null)
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slateDark,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            if (onTap != null) const Icon(PhosphorIconsRegular.caretRight, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  void _showPlanDialog(BuildContext context, WidgetRef ref, List<PackagePlan> plans, {int? index}) {
    final existing = index == null ? null : plans[index];
    final pay = TextEditingController(text: existing?.pay.toStringAsFixed(0) ?? '');
    final worth = TextEditingController(text: existing?.worth.toStringAsFixed(0) ?? '');
    final months = TextEditingController(text: existing?.months.toString() ?? '');
    var saving = false;

    Future<void> save(BuildContext ctx, void Function(void Function()) setState, List<PackagePlan> next) async {
      setState(() => saving = true);
      try {
        await ref.read(appDataProvider.notifier).savePackagePlans(next);
        if (ctx.mounted) Navigator.pop(ctx);
      } catch (e) {
        setState(() => saving = false);
        if (context.mounted) _snack(context, _reason(e), error: true);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.ticket,
          title: existing == null ? 'Add Package' : 'Edit Package',
          subtitle: 'Packages already sold keep the terms they were sold on.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pay,
                keyboardType: TextInputType.number,
                decoration: appDialogFieldDecoration(label: 'Client pays (₹) *', icon: PhosphorIconsRegular.currencyInr),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: worth,
                keyboardType: TextInputType.number,
                decoration: appDialogFieldDecoration(label: 'Services worth (₹) *', icon: PhosphorIconsRegular.gift),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: months,
                keyboardType: TextInputType.number,
                decoration: appDialogFieldDecoration(label: 'Valid for (months) *', icon: PhosphorIconsRegular.calendarBlank),
              ),
              if (existing != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: saving ? null : () => save(ctx, setDialogState, [...plans]..removeAt(index!)),
                    child: const Text('Stop offering this', style: TextStyle(color: AppTheme.accentRed)),
                  ),
                ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Save',
            submitting: saving,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () {
              final plan = PackagePlan(
                pay: double.tryParse(pay.text.trim()) ?? 0,
                worth: double.tryParse(worth.text.trim()) ?? 0,
                months: int.tryParse(months.text.trim()) ?? 0,
              );
              final problem = plan.problem;
              if (problem != null) {
                _snack(context, problem, error: true);
                return;
              }
              final next = [...plans];
              if (index == null) {
                next.add(plan);
              } else {
                next[index] = plan;
              }
              save(ctx, setDialogState, next);
            },
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.slateLight)),
    );
  }
}

/// Sells a package, to [customer] or to a client picked here.
void showSellPackageDialog(BuildContext context, WidgetRef ref, {Customer? customer}) {
  final state = ref.read(appDataProvider).valueOrNull;
  final plans = state?.settings?.packagePlans ?? const <PackagePlan>[];
  if (state == null || plans.isEmpty) {
    _snack(context, 'Add a package under Menu > Packages first.', error: true);
    return;
  }
  var client = customer;
  var plan = plans.first;
  var method = 'UPI';
  var selling = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AppDialog(
        icon: PhosphorIconsRegular.ticket,
        title: 'Sell Package',
        subtitle: 'The credit is for this client only.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: customer != null
                  ? null
                  : () async {
                      final picked = await showSearchablePicker<Customer>(
                        context: ctx,
                        title: 'Choose a client',
                        items: state.customers,
                        labelOf: (c) => c.name,
                        subtitleOf: (c) => c.phone,
                        searchHint: 'Name or mobile number',
                      );
                      if (picked != null) setDialogState(() => client = picked);
                    },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                isEmpty: client == null,
                decoration: appDialogFieldDecoration(label: 'Client *', icon: PhosphorIconsRegular.user),
                child: Text(client?.name ?? '', style: const TextStyle(fontSize: 14, color: AppTheme.slateDark)),
              ),
            ),
            const SizedBox(height: 12),
            for (final option in plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SelectRow(
                  title: planLabel(option),
                  subtitle: planValidity(option),
                  selected: identical(option, plan),
                  onTap: () => setDialogState(() => plan = option),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final (i, m) in const ['UPI', 'CASH'].indexed)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: _SelectRow(
                        title: paymentMethodLabel(m),
                        selected: method == m,
                        onTap: () => setDialogState(() => method = m),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: AppDialogActions(
          submitLabel: 'Sell for ${formatInr(plan.pay)}',
          submitting: selling,
          onCancel: () => Navigator.pop(ctx),
          onSubmit: () async {
            final buyer = client;
            if (buyer == null) {
              _snack(context, 'Choose a client first.', error: true);
              return;
            }
            final branches = state.branches;
            final branch = branches.any((b) => b.id == buyer.branchId)
                ? buyer.branchId
                : (branches.isEmpty ? '' : branches.first.id);
            setDialogState(() => selling = true);
            try {
              final sold = await ref.read(appDataProvider.notifier).sellPackage(
                    customerId: buyer.id,
                    branchId: branch,
                    plan: plan,
                    paymentMethod: method,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                _snack(context, '${formatInr(sold.creditValue)} credit added for ${buyer.name}.');
              }
            } catch (e) {
              setDialogState(() => selling = false);
              if (context.mounted) _snack(context, _reason(e), error: true);
            }
          },
        ),
      ),
    ),
  );
}

class _SelectRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectRow({required this.title, this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppTheme.primaryBlue : AppTheme.borderSubtle, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A client's package credit on their page, and where the next one is sold.
class ClientPackageStrip extends ConsumerWidget {
  final Customer customer;

  const ClientPackageStrip({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appDataProvider).valueOrNull;
    if (state == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final packages = usablePackages(state.clientPackages, customer.id, now);
    final canSell = state.settings?.packagePlans.isNotEmpty ?? false;
    if (packages.isEmpty && !canSell) return const SizedBox.shrink();
    final credit = usableCredit(state.clientPackages, customer.id, now);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: packages.isEmpty ? AppTheme.bgSurface : AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsRegular.ticket, size: 18, color: AppTheme.primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: packages.isEmpty
                  ? const Text('No package', style: TextStyle(fontSize: 13, color: AppTheme.slateLight))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatInr(credit)} package credit',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                        ),
                        Text(
                          'Expires ${packageDate(packages.first.expiresAt)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.slateLight),
                        ),
                      ],
                    ),
            ),
            if (canSell)
              TextButton(
                onPressed: () => showSellPackageDialog(context, ref, customer: customer),
                child: const Text('Sell package'),
              ),
          ],
        ),
      ),
    );
  }
}
