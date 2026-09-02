import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../auth/auth_provider.dart';

String _formatRupees(double amount) {
  final whole = amount.round().toString();
  if (whole.length <= 3) return '₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole.substring(0, whole.length - 3);
  final grouped = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '₹$grouped,$last3';
}

String _formatDate(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

// --- BRANCH MANAGEMENT ---

class OwnerBranchTab extends StatelessWidget {
  const OwnerBranchTab({super.key});

  void _showAddBranchDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Branch'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Branch Name *')),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 12),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Branch name is required.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(appDataProvider.notifier).addBranch(
                      name: name,
                      address: addressController.text.trim(),
                      phone: phoneController.text.trim(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Branch "$name" added.'), backgroundColor: AppTheme.accentGreen),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                }
              }
            },
            child: const Text('Add Branch'),
          ),
        ],
      ),
    );
  }

  void _showEditBranchDialog(BuildContext context, WidgetRef ref, Branch branch, List<EmployeeProfile> branchEmployees) {
    final nameController = TextEditingController(text: branch.name);
    final addressController = TextEditingController(text: branch.address ?? '');
    final phoneController = TextEditingController(text: branch.phone ?? '');
    String? managerId = branch.managerId;
    bool active = branch.active;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit ${branch.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Branch Name *')),
                const SizedBox(height: 12),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 12),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: managerId,
                  decoration: const InputDecoration(labelText: 'Branch Manager'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                    ...branchEmployees.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name))),
                  ],
                  onChanged: (val) => setDialogState(() => managerId = val),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Branch Active'),
                  value: active,
                  onChanged: (val) => setDialogState(() => active = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Branch name is required.'), backgroundColor: AppTheme.accentRed),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(appDataProvider.notifier).updateBranch(
                        branch.id,
                        name: name,
                        address: addressController.text.trim(),
                        phone: phoneController.text.trim(),
                        managerId: managerId,
                        active: active,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Branch updated.'), backgroundColor: AppTheme.accentGreen),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text(err.toString())),
          data: (state) => _buildBody(context, ref, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppData state) {
    final totalRevenue = state.branches.fold<double>(0, (sum, b) => sum + b.monthlyRevenue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Multi-Branch Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                    SizedBox(height: 4),
                    Text('Comparison of active salon branches.', style: TextStyle(color: AppTheme.slateLight)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddBranchDialog(context, ref),
                icon: const Icon(Icons.add_business_rounded, size: 16),
                label: const Text('Add Branch'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (state.branches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No branches yet. Add your first branch above.', style: TextStyle(color: AppTheme.slateLight))),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = MediaQuery.of(context).size.width < 800;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 1 : 3,
                    crossAxisSpacing: isMobile ? 12 : 16,
                    mainAxisSpacing: isMobile ? 12 : 16,
                    childAspectRatio: isMobile ? 1.5 : 1.15,
                  ),
                  itemCount: state.branches.length,
                  itemBuilder: (context, idx) {
                    final branch = state.branches[idx];
                    final branchEmployees = state.employees.where((e) => e.branchId == branch.id).toList();
                    final revenuePerEmployee = branch.employeeCount > 0 ? branch.monthlyRevenue / branch.employeeCount : 0.0;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: branch.active ? AppTheme.primaryLight : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      branch.active ? 'ACTIVE' : 'INACTIVE',
                                      style: TextStyle(
                                        color: branch.active ? AppTheme.primaryBlue : AppTheme.slateLight,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.slateLight),
                                  onPressed: () => _showEditBranchDialog(context, ref, branch, branchEmployees),
                                  tooltip: 'Edit Branch',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(branch.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_formatRupees(branch.monthlyRevenue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -1)),
                                const Text('Monthly Revenue', style: TextStyle(fontSize: 10, color: AppTheme.slateLight)),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.people, color: AppTheme.slateLight, size: 14),
                                    const SizedBox(width: 4),
                                    Text('${branch.customerCount} Clients', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.badge_outlined, color: AppTheme.slateLight, size: 14),
                                    const SizedBox(width: 4),
                                    Text('${branch.employeeCount} Staff', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            if (branch.employeeCount > 0) ...[
                              const SizedBox(height: 4),
                              Text('Rev/Employee: ${_formatRupees(revenuePerEmployee)}', style: const TextStyle(fontSize: 10, color: AppTheme.slateLight)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Operations Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 640),
                        child: Table(
                          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.8), 4: FlexColumnWidth(1.3)},
                          border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade100, width: 1)),
                          children: [
                            TableRow(
                              children: ['Branch Name', 'Manager', 'Location', 'Active Target Progress', '% of Revenue'].map((header) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                  child: Text(header, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade500)),
                                );
                              }).toList(),
                            ),
                            ...state.branches.map((br) {
                              final branchEmployees = state.employees.where((e) => e.branchId == br.id).toList();
                              final branchEmployeeIds = branchEmployees.map((e) => e.id).toSet();
                              final activeTargets = state.salesTargets.where((t) => t.status == 'ACTIVE' && branchEmployeeIds.contains(t.employeeId)).toList();
                              final avgProgress = activeTargets.isEmpty
                                  ? null
                                  : activeTargets.map((t) => t.progressFraction).reduce((a, b) => a + b) / activeTargets.length * 100;
                              final revenueShare = totalRevenue == 0 ? 0.0 : (br.monthlyRevenue / totalRevenue) * 100;

                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                    child: Text(br.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                    child: Text(br.managerName ?? 'Unassigned', style: const TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                    child: Text(br.address ?? '-', style: const TextStyle(fontSize: 11, color: AppTheme.slateLight)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                    child: avgProgress == null
                                        ? const Text('No active targets', style: TextStyle(color: AppTheme.slateLight, fontSize: 11))
                                        : Row(
                                            children: [
                                              Icon(Icons.trending_up, color: avgProgress >= 75 ? AppTheme.accentGreen : Colors.orange, size: 14),
                                              const SizedBox(width: 6),
                                              Text('${avgProgress.toStringAsFixed(0)}%', style: TextStyle(color: avgProgress >= 75 ? AppTheme.accentGreen : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                    child: Text('${revenueShare.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${_formatRupees(req.requestedDiscount)} OFF', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Text('By: $employeeName • ${_formatDate(req.createdAt)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
            const SizedBox(height: 4),
            Text('Reason: ${req.reason}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (originalAmount != null)
                      Text('Original: ${_formatRupees(originalAmount)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough)),
                    Text(
                      discountedVal != null ? 'Final net: ${_formatRupees(discountedVal)}' : (req.overridePrice != null ? 'Override: ${_formatRupees(req.overridePrice!)}' : 'No linked bill'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.green),
                    ),
                  ],
                ),
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
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact),
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact),
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text(err.toString())),
          data: (state) {
            final pendingRequests = state.discountRequests.where((r) => r.status == 'PENDING').toList();
            final historyRequests = state.discountRequests.where((r) => r.status != 'PENDING').toList();

            final Widget pendingWidget = Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: isMobile ? BorderRadius.circular(16) : const BorderRadius.horizontal(right: Radius.circular(16)),
                side: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pending Approvals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: pendingRequests.isEmpty ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pendingRequests.length} Due',
                            style: TextStyle(color: pendingRequests.isEmpty ? Colors.green : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 10),
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
                              Icon(Icons.verified_outlined, size: 48, color: Colors.green),
                              SizedBox(height: 12),
                              Text('No pending discount requests!'),
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
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Approval Audit History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 16),
                      if (historyRequests.isEmpty)
                        const Text('No resolved requests yet.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: historyRequests.length,
                          separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                          itemBuilder: (context, idx) {
                            final req = historyRequests[idx];
                            final isApproved = req.status == 'APPROVED';
                            final bill = req.billId == null ? null : state.bills.where((b) => b.id == req.billId);
                            final matchedBill = (bill != null && bill.isNotEmpty) ? bill.first : null;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(matchedBill?.customerName ?? 'General request', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              subtitle: Text('By: ${state.employeeNameForUserId(req.requestedBy)} • ${_formatDate(req.createdAt)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_formatRupees(req.requestedDiscount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(color: isApproved ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                    child: Text(req.status, style: TextStyle(color: isApproved ? Colors.green : Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
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
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstRateController = TextEditingController();
  final _latePenaltyController = TextEditingController();
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
    _businessNameController.text = settings.salonName;
    _phoneController.text = settings.phone ?? '';
    _addressController.text = settings.address ?? '';
    _gstRateController.text = settings.gstRate.toStringAsFixed(0);
    _latePenaltyController.text = settings.lateAttendancePenalty.toStringAsFixed(0);
    _initialized = true;
  }

  Future<void> _save(WidgetRef ref) async {
    setState(() => _saving = true);
    try {
      await ref.read(appDataProvider.notifier).updateSettings({
        'salonName': _businessNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'gstRate': double.tryParse(_gstRateController.text) ?? 0,
        'lateAttendancePenalty': double.tryParse(_latePenaltyController.text) ?? 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salon settings saved.'), backgroundColor: AppTheme.accentGreen, behavior: SnackBarBehavior.floating),
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text(err.toString())),
          data: (state) {
            if (!_initialized && state.settings != null) {
              _hydrateFrom(state.settings!);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('System Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobileProfile = MediaQuery.of(context).size.width < 600;

                            final Widget detailsWidget = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(authState.name ?? 'Owner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Role: ${authState.role ?? "OWNER"} Account', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                Text('Linked: ${authState.email ?? "-"}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                              ],
                            );

                            final Widget logoutButton = ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm Logout'),
                                    content: const Text('Are you sure you want to end this session?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          ref.read(authControllerProvider.notifier).logout();
                                        },
                                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text('Logout Session'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade700, elevation: 0),
                            );

                            if (isMobileProfile) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(backgroundColor: AppTheme.primaryLight, radius: 28, child: const Icon(Icons.person, color: AppTheme.primaryBlue, size: 28)),
                                      const SizedBox(width: 16),
                                      Expanded(child: detailsWidget),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  logoutButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                CircleAvatar(backgroundColor: AppTheme.primaryLight, radius: 28, child: const Icon(Icons.person, color: AppTheme.primaryBlue, size: 28)),
                                const SizedBox(width: 16),
                                Expanded(child: detailsWidget),
                                logoutButton,
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Salon Business Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 20),
                            const Text('Business Trading Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 6),
                            TextField(controller: _businessNameController, decoration: _fieldDecoration()),
                            const SizedBox(height: 16),
                            const Text('Support Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 6),
                            TextField(controller: _phoneController, decoration: _fieldDecoration()),
                            const SizedBox(height: 16),
                            const Text('Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 6),
                            TextField(controller: _addressController, decoration: _fieldDecoration()),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('GST Rate (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      const SizedBox(height: 6),
                                      TextField(controller: _gstRateController, keyboardType: TextInputType.number, decoration: _fieldDecoration()),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Late Attendance Penalty (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      const SizedBox(height: 6),
                                      TextField(controller: _latePenaltyController, keyboardType: TextInputType.number, decoration: _fieldDecoration()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _saving ? null : () => _save(ref),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _saving
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _fieldDecoration() => InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      );
}
