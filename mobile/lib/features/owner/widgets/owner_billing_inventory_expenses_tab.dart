import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../salon_state.dart';

// --- BILLING TAB ---

class OwnerBillingTab extends StatefulWidget {
  const OwnerBillingTab({super.key});

  @override
  State<OwnerBillingTab> createState() => _OwnerBillingTabState();
}

class _OwnerBillingTabState extends State<OwnerBillingTab> {
  String? _selectedCustomerName;
  final List<String> _selectedServices = [];
  double _discountPercent = 0.0;
  String _paymentMethod = 'UPI';

  final List<Map<String, dynamic>> _availableServices = [
    {'name': 'Premium Haircut & Styling', 'price': 1500.0},
    {'name': 'Beard Grooming & Trim', 'price': 800.0},
    {'name': 'Hydra Facial Treatment', 'price': 4500.0},
    {'name': 'Gel Nail Extensions', 'price': 3200.0},
    {'name': 'Balayage Hair Coloring', 'price': 9500.0},
    {'name': 'Keratin Smooth Therapy', 'price': 8500.0},
    {'name': 'Royal Pedicure & Spa', 'price': 2500.0},
    {'name': 'Deep Cleansing Facial', 'price': 2200.0},
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);

        // Calculations
        double subtotal = 0.0;
        for (var sName in _selectedServices) {
          final svc = _availableServices.firstWhere((element) => element['name'] == sName);
          subtotal += svc['price'];
        }
        double discountAmount = subtotal * (_discountPercent / 100);
        double totalAmount = subtotal - discountAmount;

        final isMobile = MediaQuery.of(context).size.width < 768;

        final Widget checkoutWidget = Card(
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
                const Text(
                  'Select Customer & Services',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a client and add catalog items below to draft an invoice.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                const SizedBox(height: 24),

                // Customer Selector Dropdown
                const Text('Select Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCustomerName,
                  hint: const Text('Walk-in Customer (Guest)', style: TextStyle(fontSize: 13)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: state.customers.map((cust) {
                    return DropdownMenuItem<String>(
                      value: cust.name,
                      child: Text(cust.name, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCustomerName = val;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Services catalog listing
                const Text('Available Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _availableServices.length,
                    itemBuilder: (context, idx) {
                      final svc = _availableServices[idx];
                      final sName = svc['name'] as String;
                      final sPrice = svc['price'] as double;
                      final isChecked = _selectedServices.contains(sName);

                      return CheckboxListTile(
                        title: Text(sName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        subtitle: Text('₹${sPrice.toStringAsFixed(0)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                        value: isChecked,
                        dense: true,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedServices.add(sName);
                            } else {
                              _selectedServices.remove(sName);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Discount Input Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Apply Discount (Authorized)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('${_discountPercent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                  ],
                ),
                Slider(
                  value: _discountPercent,
                  min: 0,
                  max: 50,
                  divisions: 10,
                  label: '${_discountPercent.toStringAsFixed(0)}%',
                  onChanged: (val) {
                    setState(() {
                      _discountPercent = val;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Payment Method
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: ['UPI', 'Cash', 'Pending'].map((method) {
                    final isSel = _paymentMethod == method;
                    Color color = Colors.blue;
                    if (method == 'Cash') color = Colors.amber.shade800;
                    if (method == 'Pending') color = Colors.redAccent;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _paymentMethod = method;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSel ? color.withOpacity(0.12) : Colors.transparent,
                              border: Border.all(color: isSel ? color : Colors.grey.shade300, width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                method,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? color : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );

        final Widget previewWidget = Column(
          children: [
            // Premium receipt invoice preview card
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TAX INVOICE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
                        Icon(Icons.receipt_outlined, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Glamour Studio Salon Ltd.', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    Text('Uptown Branch, Main Blvd, New Delhi', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                    const Divider(height: 32),

                    // Customer info line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CLIENT NAME', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(_selectedCustomerName ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('DATE & TIME', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text('15 July 2026, ${TimeOfDay.now().format(context)}', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    const Divider(height: 24),
                    // Service lines
                    if (_selectedServices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(child: Text('No services selected. Add above.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))),
                      )
                    else
                      ..._selectedServices.map((sName) {
                        final svc = _availableServices.firstWhere((element) => element['name'] == sName);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(sName, style: const TextStyle(fontSize: 12)),
                              Text('₹${svc['price'].toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        );
                      }),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: TextStyle(fontSize: 12)),
                        Text('₹${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    if (discountAmount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Discount (${_discountPercent.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, color: Colors.green)),
                          Text('-₹${discountAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Taxes (GST 18%)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('₹${(totalAmount * 0.18).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL PAYABLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        Text('₹${(totalAmount * 1.18).toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Process Billing Button
                    ElevatedButton(
                      onPressed: _selectedServices.isEmpty
                          ? null
                          : () {
                              // Trigger local state generation
                              ref.read(salonStateProvider.notifier).createBill(
                                customerName: _selectedCustomerName ?? 'Walk-in Customer',
                                services: _selectedServices,
                                subtotal: subtotal,
                                discountPercent: _discountPercent,
                                discountAmount: discountAmount,
                                totalAmount: totalAmount * 1.18, // including taxes
                                paymentMethod: _paymentMethod,
                              );

                              // Success dialog
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                                      SizedBox(width: 8),
                                      Text('Bill Checkout'),
                                    ],
                                  ),
                                  content: Text('Bill Generated Successfully for ${_selectedCustomerName ?? "Walk-in Customer"}!\nTotal Amount: ₹${(totalAmount * 1.18).toStringAsFixed(0)} via $_paymentMethod.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        setState(() {
                                          _selectedServices.clear();
                                          _discountPercent = 0.0;
                                          _selectedCustomerName = null;
                                        });
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Print & Generate Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bill History Section
            _buildBillHistoryCard(context, state),
          ],
        );

        if (isMobile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                checkoutWidget,
                const SizedBox(height: 20),
                previewWidget,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left checkout configuration
            Expanded(
              flex: 1,
              child: checkoutWidget,
            ),

            // Right Preview column & Bill history
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: previewWidget,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBillHistoryCard(BuildContext context, SalonState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Bill History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.bills.length,
              separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
              itemBuilder: (context, index) {
                final bill = state.bills[index];
                final isPending = bill.paymentMethod == 'Pending';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(bill.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  subtitle: Text('${bill.billNo} • ${bill.date}\n${bill.services.join(", ")}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${bill.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isPending ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          bill.paymentMethod,
                          style: TextStyle(color: isPending ? Colors.red.shade700 : Colors.green.shade700, fontSize: 8, fontWeight: FontWeight.bold),
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
    );
  }
}

// --- INVENTORY TAB ---

class OwnerInventoryTab extends StatefulWidget {
  const OwnerInventoryTab({super.key});

  @override
  State<OwnerInventoryTab> createState() => _OwnerInventoryTabState();
}

class _OwnerInventoryTabState extends State<OwnerInventoryTab> {
  final _stockController = TextEditingController();

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);

        // Low stock count
        final lowStockItems = state.inventory.where((prod) => prod.currentStock <= prod.minStockAlertThreshold).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Summary alert card
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final Widget headerText = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inventory Stock Manager',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage salon consumables and retail products.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              );

              final Widget alertCard = lowStockItems.isNotEmpty
                  ? Card(
                      elevation: 0,
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Low Stock Alert!',
                                  style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '${lowStockItems.length} products require restocking.',
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink();

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerText,
                    if (lowStockItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      alertCard,
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerText),
                  if (lowStockItems.isNotEmpty) alertCard,
                ],
              );
            },
          ),
          const SizedBox(height: 32),

              // Product Table list
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
                      const Text(
                        'Product Catalog',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.inventory.length,
                        separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                        itemBuilder: (context, idx) {
                          final prod = state.inventory[idx];
                          final isLow = prod.currentStock <= prod.minStockAlertThreshold;

                          final Widget stockBadge = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLow ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${prod.currentStock} ${prod.unit}',
                                  style: TextStyle(
                                    color: isLow ? Colors.red.shade700 : Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isLow) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_downward, color: Colors.red, size: 12),
                                ],
                              ],
                            ),
                          );

                          final Widget updateBtn = OutlinedButton(
                            onPressed: () {
                              _stockController.text = prod.currentStock.toString();
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Update Stock: ${prod.name}'),
                                  content: TextField(
                                    controller: _stockController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Current Stock Level (${prod.unit})',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        final newStk = int.tryParse(_stockController.text);
                                        if (newStk != null) {
                                          ref.read(salonStateProvider.notifier).updateProductStock(prod.id, newStk);

                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Stock updated for ${prod.name} to $newStk ${prod.unit}'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Update'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Update Stock', style: TextStyle(fontSize: 11)),
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: LayoutBuilder(builder: (context, cons) {
                              final isTight = cons.maxWidth < 480;
                              final Widget info = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prod.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Category: ${prod.category} • Min: ${prod.minStockAlertThreshold} ${prod.unit}',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );

                              if (isTight) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    info,
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        stockBadge,
                                        updateBtn,
                                      ],
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: info),
                                  const SizedBox(width: 8),
                                  stockBadge,
                                  const SizedBox(width: 12),
                                  updateBtn,
                                ],
                              );
                            }),
                          );
                        },
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

// --- EXPENSES TAB ---

class OwnerExpensesTab extends StatefulWidget {
  const OwnerExpensesTab({super.key});

  @override
  State<OwnerExpensesTab> createState() => _OwnerExpensesTabState();
}

class _OwnerExpensesTabState extends State<OwnerExpensesTab> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'Tea';
  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);

        // Category sums
        final Map<String, double> catSums = {};
        double totalExpense = 0;
        for (var exp in state.expenses) {
          catSums[exp.category] = (catSums[exp.category] ?? 0.0) + exp.amount;
          totalExpense += exp.amount;
        }

        final Widget listWidget = Card(
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expenses Log',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Transactions and categories tracker',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                    Text(
                      'Total: ₹${totalExpense.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.redAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // List of expenses
                isMobile 
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.expenses.length,
                        itemBuilder: (context, idx) {
                          final exp = state.expenses[idx];
                          return Card(
                            elevation: 0,
                            color: Colors.grey.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exp.description,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Category: ${exp.category} • ${exp.date}',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '-₹${exp.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: state.expenses.length,
                          itemBuilder: (context, idx) {
                            final exp = state.expenses[idx];
                            return Card(
                              elevation: 0,
                              color: Colors.grey.shade50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exp.description,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Category: ${exp.category} • ${exp.date}',
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '-₹${exp.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        );

        final Widget formAndBreakdownWidget = Column(
          children: [
            // Form
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Record New Expense',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 20),

                      // Dropdown category
                      const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['Tea', 'Cleaning', 'Repair', 'Maintenance', 'Electricity', 'Miscellaneous'].map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _category = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description input
                      const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Tea cups & biscuit packet',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please add description';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Amount input
                      const Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g. 150',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please add amount';
                          if (double.tryParse(val) == null) return 'Enter valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final desc = _descController.text;
                            final amt = double.parse(_amountController.text);
                            
                            ref.read(salonStateProvider.notifier).addExpenseItem(_category, desc, amt);

                            // Clear form
                            _descController.clear();
                            _amountController.clear();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Expense logged: $desc (-₹${amt.toStringAsFixed(0)})'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Log Expense Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Visual category summary card list
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
                    const Text('Category Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 16),
                    ...['Tea', 'Cleaning', 'Repair', 'Maintenance', 'Electricity', 'Miscellaneous'].map((cat) {
                      final sum = catSums[cat] ?? 0.0;
                      final ratio = totalExpense == 0 ? 0.0 : sum / totalExpense;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('₹${sum.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: ratio,
                              minHeight: 4,
                              backgroundColor: Colors.grey.shade100,
                              color: Colors.redAccent.withOpacity(0.7),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );

        if (isMobile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                listWidget,
                const SizedBox(height: 20),
                formAndBreakdownWidget,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left list of expenses & summary
            Expanded(
              flex: 1,
              child: listWidget,
            ),

            // Right Add expense form & breakdown
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: formAndBreakdownWidget,
              ),
            ),
          ],
        );
      },
    );
  }
}
