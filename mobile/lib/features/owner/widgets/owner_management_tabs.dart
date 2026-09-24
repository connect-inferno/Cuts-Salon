import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../auth/auth_provider.dart';
import '../../../widgets/async_state_views.dart';
import '../../../widgets/app_dialog.dart';

String _formatRupees(double amount) {
  final whole = amount.round().toString();
  if (whole.length <= 3) return '₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole.substring(0, whole.length - 3);
  final grouped = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '₹$grouped,$last3';
}

const _kMonthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatDate(DateTime? d) {
  if (d == null) return '-';
  return '${d.day} ${_kMonthNames[d.month - 1]} ${d.year}';
}

// --- BRANCH MANAGEMENT ---

class OwnerBranchTab extends StatelessWidget {
  const OwnerBranchTab({super.key});

  void _showAddBranchDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.storefront,
          title: 'Add New Branch',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: appDialogFieldDecoration(label: 'Branch Name *', icon: PhosphorIconsRegular.storefront)),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: appDialogFieldDecoration(label: 'Address', icon: PhosphorIconsRegular.mapPin)),
              const SizedBox(height: 12),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: appDialogFieldDecoration(label: 'Phone Number', icon: PhosphorIconsRegular.phone)),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Add Branch',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Branch name is required.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).addBranch(
                      name: name,
                      address: addressController.text.trim(),
                      phone: phoneController.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Branch "$name" added.'), backgroundColor: AppTheme.accentGreen),
                  );
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _showEditBranchDialog(BuildContext context, WidgetRef ref, Branch branch, List<EmployeeProfile> branchEmployees) {
    final nameController = TextEditingController(text: branch.name);
    final addressController = TextEditingController(text: branch.address ?? '');
    final phoneController = TextEditingController(text: branch.phone ?? '');
    String? managerId = branch.managerId;
    bool active = branch.active;

    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.pencilSimple,
          title: 'Edit ${branch.name}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: appDialogFieldDecoration(label: 'Branch Name *', icon: PhosphorIconsRegular.storefront)),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: appDialogFieldDecoration(label: 'Address', icon: PhosphorIconsRegular.mapPin)),
              const SizedBox(height: 12),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: appDialogFieldDecoration(label: 'Phone Number', icon: PhosphorIconsRegular.phone)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: managerId,
                decoration: appDialogFieldDecoration(label: 'Branch Manager', icon: PhosphorIconsRegular.userGear),
                borderRadius: BorderRadius.circular(14),
                dropdownColor: Colors.white,
                elevation: 3,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                  ...branchEmployees.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name))),
                ],
                onChanged: (val) => setDialogState(() => managerId = val),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Branch Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: active,
                  onChanged: (val) => setDialogState(() => active = val),
                ),
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Save Changes',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Branch name is required.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).updateBranch(
                      branch.id,
                      name: name,
                      address: addressController.text.trim(),
                      phone: phoneController.text.trim(),
                      managerId: managerId,
                      active: active,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Branch updated.'), backgroundColor: AppTheme.accentGreen),
                  );
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                }
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final asyncData = ref.watch(appDataProvider);
        return asyncData.when(
          loading: () => const AppLoadingView(),
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
          data: (state) => _buildBody(context, ref, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppData state) {
    final totalRevenue = state.branches.fold<double>(0, (sum, b) => sum + b.monthlyRevenue);
    final activeCount = state.branches.where((b) => b.active).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Mini Header with Storefront & Bell
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(PhosphorIconsFill.storefront, size: 18, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Cuts Salon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(PhosphorIconsRegular.bell, size: 18, color: Color(0xFF475569)),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Header Row: Title & Add Branch Pill Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Multi-Branch\nPerformance',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.6,
                        height: 1.15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$activeCount Active Branches • Real-time Overview',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddBranchDialog(context, ref),
                icon: const Icon(PhosphorIconsBold.plus, size: 14, color: Colors.white),
                label: const Text(
                  'Add Branch',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // "TOTAL NETWORK GROSS" Banner Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    PhosphorIconsFill.buildings,
                    size: 22,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL NETWORK GROSS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatRupees(totalRevenue),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${state.branches.length} branch${state.branches.length == 1 ? '' : 'es'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475467),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_kMonthNames[DateTime.now().month - 1]} ${DateTime.now().year}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Active Branches Vertical List
          if (state.branches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No branches yet. Add your first branch above.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.branches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, idx) {
                final branch = state.branches[idx];
                final branchEmployees = state.employees.where((e) => e.branchId == branch.id).toList();
                final revenuePerEmployee = branch.employeeCount > 0 ? branch.monthlyRevenue / branch.employeeCount : 0.0;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge & Edit Pencil
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: branch.active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: branch.active ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  branch.active ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: branch.active ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 17, color: Color(0xFF94A3B8)),
                            onPressed: () => _showEditBranchDialog(context, ref, branch, branchEmployees),
                            tooltip: 'Edit Branch',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Branch Name
                      Text(
                        branch.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Location & real headcount (no fabricated "chair
                      // occupancy" - there's no such data in this app).
                      Row(
                        children: [
                          const Icon(PhosphorIconsRegular.mapPin, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              branch.address?.isNotEmpty == true
                                  ? '${branch.address} • ${branch.employeeCount} staff'
                                  : '${branch.employeeCount} staff',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Monthly Revenue Row
                      const Text(
                        'MONTHLY REVENUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatRupees(branch.monthlyRevenue),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metrics 3-Item Row
                      Row(
                        children: [
                          // Clients Box
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(PhosphorIconsRegular.users, size: 14, color: Color(0xFF4F46E5)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${branch.customerCount}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const Text(
                                          'Clients',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Staff Box
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(PhosphorIconsRegular.identificationBadge, size: 14, color: Color(0xFF4F46E5)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${branch.employeeCount} Stylists',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Text(
                                          'Staff',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Rev/Emp Box
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatRupees(revenuePerEmployee),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                  const Text(
                                    'Rev/Emp',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          // Bottom Spacing for floating navbar
          const SizedBox(height: 110),
        ],
      ),
    );
  }
}

// --- DISCOUNT REQUESTS ---

class OwnerDiscountsTab extends StatefulWidget {
  const OwnerDiscountsTab({super.key});

  @override
  State<OwnerDiscountsTab> createState() => _OwnerDiscountsTabState();
}

class _OwnerDiscountsTabState extends State<OwnerDiscountsTab> {
  Widget _buildRequestCard(BuildContext context, WidgetRef ref, AppData state, DiscountRequest req) {
    final bill = req.billId == null ? null : state.bills.where((b) => b.id == req.billId);
    final matchedBill = (bill != null && bill.isNotEmpty) ? bill.first : null;
    final employeeName = state.employeeNameForUserId(req.requestedBy);
    final originalAmount = matchedBill?.finalAmount;
    final discountedVal = req.overridePrice ?? (originalAmount == null ? null : originalAmount - req.requestedDiscount);

    return Card(
      elevation: 0,
      color: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.borderSubtle)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    matchedBill?.customerName ?? 'General discount request',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slateDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${_formatRupees(req.requestedDiscount)} OFF', style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Text('By: $employeeName • ${_formatDate(req.createdAt)}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 10)),
            const SizedBox(height: 4),
            Text('Reason: ${req.reason}', style: const TextStyle(color: AppTheme.slateMedium, fontSize: 11)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (originalAmount != null)
                        Text('Original: ${_formatRupees(originalAmount)}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppTheme.slateLight, decoration: TextDecoration.lineThrough)),
                      Text(
                        discountedVal != null ? 'Final net: ${_formatRupees(discountedVal)}' : (req.overridePrice != null ? 'Override: ${_formatRupees(req.overridePrice!)}' : 'No linked bill'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.accentGreen),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await ref.read(appDataProvider.notifier).rejectDiscountRequest(req.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discount request rejected.')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRed, side: const BorderSide(color: AppTheme.accentRed), padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact),
                      child: const Text('Reject', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await ref.read(appDataProvider.notifier).approveDiscountRequest(req.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discount request approved!')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact),
                      child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Consumer(
      builder: (context, ref, child) {
        final asyncData = ref.watch(appDataProvider);
        return asyncData.when(
          loading: () => const AppLoadingView(),
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
          data: (state) {
            final pendingRequests = state.discountRequests.where((r) => r.status == 'PENDING').toList();
            final historyRequests = state.discountRequests.where((r) => r.status != 'PENDING').toList();

            final Widget pendingWidget = Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pending Approvals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.slateDark)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: pendingRequests.isEmpty ? AppTheme.accentGreenBg : AppTheme.accentAmberBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pendingRequests.length} Due',
                            style: TextStyle(color: pendingRequests.isEmpty ? AppTheme.accentGreen : AppTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Builder(builder: (context) {
                      final emptyState = const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIconsRegular.sealCheck, size: 48, color: AppTheme.accentGreen),
                              SizedBox(height: 12),
                              Text('No pending discount requests!', style: TextStyle(color: AppTheme.slateMedium)),
                            ],
                          ),
                        ),
                      );
                      final list = ListView.builder(
                        shrinkWrap: isMobile,
                        physics: isMobile ? const NeverScrollableScrollPhysics() : null,
                        itemCount: pendingRequests.length,
                        itemBuilder: (context, idx) => _buildRequestCard(context, ref, state, pendingRequests[idx]),
                      );
                      if (isMobile) return pendingRequests.isEmpty ? emptyState : list;
                      return Expanded(child: pendingRequests.isEmpty ? emptyState : list);
                    }),
                  ],
                ),
              ),
            );

            final Widget auditHistoryWidget = Padding(
              padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(24.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Approval Audit History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slateDark)),
                      const SizedBox(height: 16),
                      if (historyRequests.isEmpty)
                        const Text('No resolved requests yet.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: historyRequests.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final req = historyRequests[idx];
                            final isApproved = req.status == 'APPROVED';
                            final bill = req.billId == null ? null : state.bills.where((b) => b.id == req.billId);
                            final matchedBill = (bill != null && bill.isNotEmpty) ? bill.first : null;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(matchedBill?.customerName ?? 'General request', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slateDark)),
                                            Text('By: ${state.employeeNameForUserId(req.requestedBy)} • ${_formatDate(req.createdAt)}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(_formatRupees(req.requestedDiscount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slateDark)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(color: isApproved ? AppTheme.accentGreenBg : AppTheme.accentRedBg, borderRadius: BorderRadius.circular(4)),
                                            child: Text(req.status, style: TextStyle(color: isApproved ? AppTheme.accentGreen : AppTheme.accentRed, fontSize: 8, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isApproved && req.authorizedCode != null) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: AppTheme.accentGreenBg, borderRadius: BorderRadius.circular(6)),
                                      child: Text(
                                        'Code: ${req.authorizedCode}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.accentGreen, letterSpacing: 0.5),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );

            if (isMobile) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [pendingWidget, const SizedBox(height: 20), auditHistoryWidget]),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(flex: 1, child: pendingWidget), Expanded(flex: 1, child: auditHistoryWidget)],
            );
          },
        );
      },
    );
  }
}

// --- SETTINGS TAB ---

class OwnerSettingsTab extends StatefulWidget {
  const OwnerSettingsTab({super.key});

  @override
  State<OwnerSettingsTab> createState() => _OwnerSettingsTabState();
}

class _OwnerSettingsTabState extends State<OwnerSettingsTab> {
  // Empty until _hydrateFrom loads the real settings doc - these used to
  // default to a fabricated business identity ("Cuts Salon & Luxury Spa",
  // a fake phone, a fake address) which _hydrateFrom only overwrites when
  // the real field is non-empty, so a salon that hadn't set a phone/address
  // yet would silently keep - and could save - someone else's made-up
  // contact details as their own.
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstRateController = TextEditingController(text: '18');
  final _latePenaltyController = TextEditingController(text: '150');
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstRateController.dispose();
    _latePenaltyController.dispose();
    super.dispose();
  }

  void _hydrateFrom(SalonSettings settings) {
    if (settings.salonName.isNotEmpty) _businessNameController.text = settings.salonName;
    if (settings.phone?.isNotEmpty ?? false) _phoneController.text = settings.phone!;
    if (settings.address?.isNotEmpty ?? false) _addressController.text = settings.address!;
    if (settings.gstRate > 0) _gstRateController.text = settings.gstRate.toStringAsFixed(0);
    if (settings.lateAttendancePenalty > 0) _latePenaltyController.text = settings.lateAttendancePenalty.toStringAsFixed(0);
    _initialized = true;
  }

  Future<void> _save(WidgetRef ref) async {
    setState(() => _saving = true);
    try {
      await ref.read(appDataProvider.notifier).updateSettings({
        'salonName': _businessNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'gstRate': double.tryParse(_gstRateController.text.replaceAll('%', '').trim()) ?? 18.0,
        'lateAttendancePenalty': double.tryParse(_latePenaltyController.text.replaceAll('₹', '').replaceAll('/ hr', '').trim()) ?? 150.0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(PhosphorIconsFill.checkCircle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Salon configuration saved successfully!')),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);
        final asyncData = ref.watch(appDataProvider);

        return asyncData.when(
          loading: () => const AppLoadingView(),
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
          data: (state) {
            if (!_initialized && state.settings != null) {
              _hydrateFrom(state.settings!);
            }

            final ownerName = authState.name?.isNotEmpty == true ? authState.name! : 'Rajesh Kumar';
            final ownerEmail = authState.email?.isNotEmpty == true ? authState.email! : 'owner@cutssalon.com';
            final initials = ownerName.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join();

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(PhosphorIconsFill.storefront, size: 18, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Cuts Salon • Main Branch',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(PhosphorIconsRegular.bell, size: 18, color: Color(0xFF475569)),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Owner Account Profile Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4F46E5),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initials.isNotEmpty ? initials : 'RK',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ownerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Role: ${authState.role ?? "OWNER"} Account',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    ownerEmail,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Logout Button
                            Material(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AppDialog(
                                      icon: PhosphorIconsRegular.signOut,
                                      iconColor: AppTheme.accentRed,
                                      iconBackground: AppTheme.accentRedBg,
                                      title: 'Confirm Logout',
                                      child: const Text(
                                        'Are you sure you want to end this session?',
                                        style: TextStyle(fontSize: 14, color: AppTheme.slateMedium),
                                      ),
                                      actions: AppDialogActions(
                                        submitLabel: 'Logout',
                                        submitColor: AppTheme.accentRed,
                                        onCancel: () => Navigator.pop(ctx),
                                        onSubmit: () {
                                          Navigator.pop(ctx);
                                          ref.read(authControllerProvider.notifier).logout();
                                        },
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(PhosphorIconsRegular.signOut, size: 14, color: Color(0xFFDC2626)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Logout',
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Active Owner Mode Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Active Owner Mode • Full Access',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                              const Icon(
                                PhosphorIconsFill.shieldCheck,
                                size: 16,
                                color: Color(0xFF16A34A),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Salon Business Configuration Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(PhosphorIconsFill.slidersHorizontal, size: 16, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Salon Business Configuration',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Manage core salon profile, billing tax rules, and operational penalties.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // BUSINESS TRADING NAME
                        const Text(
                          'BUSINESS TRADING NAME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _businessNameController,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          decoration: _buildInputDecoration(
                            icon: PhosphorIconsRegular.storefront,
                            hint: 'Cuts Salon & Luxury Spa',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // SUPPORT PHONE
                        const Text(
                          'SUPPORT PHONE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          decoration: _buildInputDecoration(
                            icon: PhosphorIconsRegular.phone,
                            hint: '+91 98200 12345',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // SALON ADDRESS
                        const Text(
                          'SALON ADDRESS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _addressController,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          decoration: _buildInputDecoration(
                            icon: PhosphorIconsRegular.mapPin,
                            hint: 'Shop 12, Ground Floor, Galleria Arcade',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // GST Rate & Late Attendance Penalty Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'GST RATE (%)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _gstRateController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    decoration: _buildInputDecoration(
                                      prefixText: '% ',
                                      hint: '18%',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ATTENDANCE PENALTY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _latePenaltyController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    decoration: _buildInputDecoration(
                                      prefixText: '₹ ',
                                      hint: '₹150 / hr',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // Gradient Save Business Configuration Button
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _saving ? null : () => _save(ref),
                              child: Center(
                                child: _saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(PhosphorIconsFill.checkCircle, size: 18, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text(
                                            'Save Business Configuration',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Navbar spacing
                  const SizedBox(height: 110),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration({
    IconData? icon,
    String? prefixText,
    String? hint,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: const Color(0xFF94A3B8))
          : null,
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    );
  }
}
