import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../salon_state.dart';
import '../../auth/auth_provider.dart';

// --- BRANCH MANAGEMENT ---

class OwnerBranchTab extends StatelessWidget {
  const OwnerBranchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Multi-Branch Performance',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comparison of active salon branches across the city.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Comparison Cards
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
                      childAspectRatio: isMobile ? 1.65 : 1.25,
                    ),
                itemCount: state.branches.length,
                itemBuilder: (context, idx) {
                  final branch = state.branches[idx];

                  // Card styling based on performance ranking
                  Color perfColor = Colors.green;
                  if (branch.performanceScore < 90) perfColor = Colors.orange;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  branch.name.split(' - ').last,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Icon(Icons.store, color: Theme.of(context).colorScheme.primary, size: 24),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${(branch.monthlyRevenue / 100000).toStringAsFixed(1)}L',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28, letterSpacing: -1),
                              ),
                              const Text('Monthly Turnover', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people, color: Colors.grey, size: 14),
                                  const SizedBox(width: 4),
                                  Text('${branch.customerCount} Clients', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.star, color: perfColor, size: 14),
                                  const SizedBox(width: 4),
                                  Text('${branch.performanceScore.toStringAsFixed(0)}% Score', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: perfColor)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),

              // Branch Details Table Comparison card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
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
                          constraints: const BoxConstraints(minWidth: 600),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1.5),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(1.5),
                            },
                            border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade100, width: 1)),
                            children: [
                              TableRow(
                                children: ['Branch Name', 'Manager In-Charge', 'Location Address', 'Monthly Target Status'].map((header) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                    child: Text(
                                      header,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  );
                                }).toList(),
                              ),
                              ...state.branches.map((br) {
                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                      child: Text(br.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                      child: Text(br.manager, style: const TextStyle(fontSize: 12)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                      child: Text(br.address, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                          const SizedBox(width: 6),
                                          Text(br.id == 'br_3' ? 'Exceeded (+12%)' : 'On Track', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
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
          ),
        );
      },
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
  Widget _buildRequestCard(BuildContext context, WidgetRef ref, DiscountRequest req) {
    final double discountedVal = req.originalAmount * (1 - (req.requestedDiscountPercent / 100));

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  req.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${req.requestedDiscountPercent.toStringAsFixed(0)}% OFF',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Stylist: ${req.employeeName} • ${req.date}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original: ₹${req.originalAmount.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough),
                    ),
                    Text(
                      'Final net: ₹${discountedVal.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.green),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        ref.read(salonStateProvider.notifier).rejectDiscountRequest(req.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Discount request rejected.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(salonStateProvider.notifier).approveDiscountRequest(req.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Discount request approved!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
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
        final state = ref.watch(salonStateProvider);

        // Separate pending and history
        final pendingRequests = state.discountRequests.where((r) => r.status == 'Pending').toList();
        final historyRequests = state.discountRequests.where((r) => r.status != 'Pending').toList();

        final Widget pendingWidget = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: isMobile 
                ? BorderRadius.circular(16)
                : const BorderRadius.horizontal(right: Radius.circular(16)),
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
                    const Text(
                      'Pending Approvals',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: pendingRequests.isEmpty ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${pendingRequests.length} Due',
                        style: TextStyle(
                          color: pendingRequests.isEmpty ? Colors.green : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                isMobile
                    ? (pendingRequests.isEmpty
                        ? const Center(
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
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pendingRequests.length,
                            itemBuilder: (context, idx) => _buildRequestCard(context, ref, pendingRequests[idx]),
                          ))
                    : Expanded(
                        child: pendingRequests.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified_outlined, size: 48, color: Colors.green),
                                    SizedBox(height: 12),
                                    Text('No pending discount requests!'),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: pendingRequests.length,
                                itemBuilder: (context, idx) => _buildRequestCard(context, ref, pendingRequests[idx]),
                              ),
                      ),
              ],
            ),
          ),
        );

        final Widget auditHistoryWidget = Padding(
          padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(24.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Approval Audit History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: historyRequests.length,
                    separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                    itemBuilder: (context, idx) {
                      final req = historyRequests[idx];
                      final isApproved = req.status == 'Approved';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(req.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        subtitle: Text('By: ${req.employeeName} • ${req.date}\nAmount: ₹${req.originalAmount.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${req.requestedDiscountPercent.toStringAsFixed(0)}% Off', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isApproved ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                req.status,
                                style: TextStyle(color: isApproved ? Colors.green : Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
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
            child: Column(
              children: [
                pendingWidget,
                const SizedBox(height: 20),
                auditHistoryWidget,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: pendingWidget,
            ),
            Expanded(
              flex: 1,
              child: auditHistoryWidget,
            ),
          ],
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
  final _businessNameController = TextEditingController(text: 'Glamour Studio Ltd');
  final _gstinController = TextEditingController(text: '27AAAAA1111A1Z1');
  final _phoneController = TextEditingController(text: '+91 98765 00000');

  @override
  void dispose() {
    _businessNameController.dispose();
    _gstinController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                const SizedBox(height: 24),

                // Account profile card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobileProfile = MediaQuery.of(context).size.width < 600;

                        final Widget detailsWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.name ?? 'Alex Mercer',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Role: ${authState.role ?? "OWNER"} Account',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            Text(
                              'Linked: ${authState.email ?? "owner@salon.com"}',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        );

                        final Widget logoutButton = ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirm Logout'),
                                content: const Text('Are you sure you want to end the salon demo session?'),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade700,
                            elevation: 0,
                          ),
                        );

                        if (isMobileProfile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    radius: 28,
                                    child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 28),
                                  ),
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
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              radius: 28,
                              child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 28),
                            ),
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

                // Salon Details Panel
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Salon Business Configurations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 20),
                        
                        const Text('Business Trading Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _businessNameController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text('GSTIN Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _gstinController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text('Support Contacts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Salon Settings Saved Locally!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save Local Modifications', style: TextStyle(fontWeight: FontWeight.bold)),
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
  }
}
