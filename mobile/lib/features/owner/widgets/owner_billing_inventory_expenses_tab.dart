import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../data/repository.dart';

String _formatDateTime(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day} ${months[d.month - 1]}, $hour:$minute $period';
}

// --- BILLING TAB ---

class OwnerBillingTab extends StatefulWidget {
  const OwnerBillingTab({super.key});

  @override
  State<OwnerBillingTab> createState() => _OwnerBillingTabState();
}

class _OwnerBillingTabState extends State<OwnerBillingTab> {
  String? _selectedCustomerId;
  String? _selectedEmployeeId;
  String? _selectedBranchId;
  final Set<String> _selectedServiceIds = {};
  double _discountPercent = 0.0;
  String _paymentMethod = 'UPI';
  bool _submitting = false;

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
    _selectedBranchId ??= state.branches.isNotEmpty ? state.branches.first.id : null;

    double subtotal = 0.0;
    for (final id in _selectedServiceIds) {
      final svc = state.services.where((s) => s.id == id);
      if (svc.isNotEmpty) subtotal += svc.first.price;
    }
    final discountAmount = subtotal * (_discountPercent / 100);
    final taxable = subtotal - discountAmount;
    final gstRate = state.settings?.gstRate ?? 18;
    final taxAmount = taxable * (gstRate / 100);
    final totalAmount = taxable + taxAmount;

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
            const Text('Select Customer & Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Select a client and add catalog items below to draft an invoice.', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            const SizedBox(height: 24),

            if (state.branches.length > 1) ...[
              const Text('Branch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedBranchId,
                decoration: _fieldDecoration(),
                items: state.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) => setState(() => _selectedBranchId = val),
              ),
              const SizedBox(height: 16),
            ],

            const Text('Select Customer *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCustomerId,
              hint: const Text('Choose a customer', style: TextStyle(fontSize: 13)),
              decoration: _fieldDecoration(),
              items: state.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (val) => setState(() => _selectedCustomerId = val),
            ),
            const SizedBox(height: 16),

            const Text('Attending Stylist *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedEmployeeId,
              hint: const Text('Choose an employee', style: TextStyle(fontSize: 13)),
              decoration: _fieldDecoration(),
              items: state.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (val) => setState(() => _selectedEmployeeId = val),
            ),
            const SizedBox(height: 20),

            const Text('Available Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
              child: state.services.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No services in catalog yet. Add one from Catalog Management.', style: TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.services.length,
                      itemBuilder: (context, idx) {
                        final svc = state.services[idx];
                        final isChecked = _selectedServiceIds.contains(svc.id);
                        return CheckboxListTile(
                          title: Text(svc.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          subtitle: Text('Rs. ${svc.price.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                          value: isChecked,
                          dense: true,
                          onChanged: (val) => setState(() {
                            if (val == true) {
                              _selectedServiceIds.add(svc.id);
                            } else {
                              _selectedServiceIds.remove(svc.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Apply Discount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${_discountPercent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
              ],
            ),
            Slider(
              value: _discountPercent,
              min: 0,
              max: 50,
              divisions: 10,
              label: '${_discountPercent.toStringAsFixed(0)}%',
              onChanged: (val) => setState(() => _discountPercent = val),
            ),
            const SizedBox(height: 20),

            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: ['UPI', 'CASH', 'CARD'].map((method) {
                final isSel = _paymentMethod == method;
                Color color = Colors.blue;
                if (method == 'CASH') color = Colors.amber.shade800;
                if (method == 'CARD') color = Colors.deepPurple;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap: () => setState(() => _paymentMethod = method),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSel ? color.withValues(alpha: 0.12) : Colors.transparent,
                          border: Border.all(color: isSel ? color : Colors.grey.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text(method, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? color : Colors.grey.shade600, fontSize: 12))),
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
                Text(state.settings?.salonName ?? 'Salon', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CLIENT NAME', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(
                      _selectedCustomerId == null ? 'None selected' : state.customers.firstWhere((c) => c.id == _selectedCustomerId, orElse: () => Customer(id: '', name: 'Unknown', phone: '', isVip: false, branchId: '')).name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (_selectedServiceIds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(child: Text('No services selected. Add above.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))),
                  )
                else
                  ..._selectedServiceIds.map((id) {
                    final svc = state.services.firstWhere((s) => s.id == id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(svc.name, style: const TextStyle(fontSize: 12)),
                          Text('Rs. ${svc.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    );
                  }),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const Text('Subtotal', style: TextStyle(fontSize: 12)), Text('Rs. ${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12))],
                ),
                if (discountAmount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discount (${_discountPercent.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, color: Colors.green)),
                      Text('-Rs. ${discountAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GST (${gstRate.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text('Rs. ${taxAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL PAYABLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    Text('Rs. ${totalAmount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_selectedServiceIds.isEmpty || _selectedCustomerId == null || _selectedEmployeeId == null || _selectedBranchId == null || _submitting)
                      ? null
                      : () => _submit(context, ref, state, discountAmount),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Generate Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildBillHistoryCard(state),
      ],
    );

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [checkoutWidget, const SizedBox(height: 20), previewWidget]),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 1, child: checkoutWidget),
        Expanded(flex: 1, child: SingleChildScrollView(padding: const EdgeInsets.all(24.0), child: previewWidget)),
      ],
    );
  }

  InputDecoration _fieldDecoration() => InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      );

  Future<void> _submit(BuildContext context, WidgetRef ref, AppData state, double discountAmount) async {
    setState(() => _submitting = true);
    try {
      final items = _selectedServiceIds.map((id) => BillItemInput(type: 'SERVICE', serviceId: id, employeeId: _selectedEmployeeId!, quantity: 1)).toList();
      final bill = await ref.read(appDataProvider.notifier).createBill(
            customerId: _selectedCustomerId!,
            branchId: _selectedBranchId!,
            paymentMethod: _paymentMethod,
            discountAmount: discountAmount,
            items: items,
          );

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 28), SizedBox(width: 8), Text('Bill Generated')]),
          content: Text('Invoice ${bill.invoiceNumber} created.\nTotal: Rs. ${bill.finalAmount.toStringAsFixed(0)} via $_paymentMethod.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedServiceIds.clear();
                  _discountPercent = 0.0;
                  _selectedCustomerId = null;
                  _selectedEmployeeId = null;
                });
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildBillHistoryCard(AppData state) {
    final bills = [...state.bills]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200, width: 1)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales Bill History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 16),
            if (bills.isEmpty)
              const Text('No bills yet.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bills.length > 20 ? 20 : bills.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  final itemNames = bill.items.map((i) => i.serviceName ?? i.productName ?? 'Item').join(', ');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(bill.customerName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text('${bill.invoiceNumber} • ${_formatDateTime(bill.createdAt)}\n$itemNames', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Rs. ${bill.finalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text(bill.paymentMethod, style: TextStyle(color: Colors.green.shade700, fontSize: 8, fontWeight: FontWeight.bold)),
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

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    final skuController = TextEditingController();
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final thresholdController = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: skuController, decoration: const InputDecoration(labelText: 'SKU *')),
              const SizedBox(height: 12),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Product Name *')),
              const SizedBox(height: 12),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category *', hintText: 'e.g. Hair Care')),
              const SizedBox(height: 12),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (Rs.) *')),
              const SizedBox(height: 12),
              TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost Price (Rs.) *')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Initial Stock'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: thresholdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Low Stock Alert'))),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final sku = skuController.text.trim();
              final name = nameController.text.trim();
              final category = categoryController.text.trim();
              final price = double.tryParse(priceController.text);
              final cost = double.tryParse(costController.text);
              if (sku.isEmpty || name.isEmpty || category.isEmpty || price == null || cost == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required with valid numbers.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(appDataProvider.notifier).addInventoryItem(
                      sku: sku,
                      name: name,
                      category: category,
                      price: price,
                      costPrice: cost,
                      stockCount: int.tryParse(stockController.text) ?? 0,
                      minAlertThreshold: int.tryParse(thresholdController.text) ?? 5,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added to inventory.'), backgroundColor: AppTheme.accentGreen));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
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
          data: (state) {
            final lowStockItems = state.inventory.where((p) => p.isLowStock).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 650;
                      final Widget headerText = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inventory Stock Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                          const SizedBox(height: 4),
                          Text('Manage salon consumables and retail products.', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      );

                      final Widget actions = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (lowStockItems.isNotEmpty)
                            Card(
                              elevation: 0,
                              color: Colors.red.shade50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200)),
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
                                        Text('Low Stock Alert!', style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('${lowStockItems.length} products require restocking.', style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showAddProductDialog(context, ref),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Product'),
                          ),
                        ],
                      );

                      if (isMobile) {
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [headerText, const SizedBox(height: 16), actions]);
                      }
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: headerText), actions]);
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
                          const Text('Product Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          if (state.inventory.isEmpty)
                            const Text('No products yet. Add one above.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.inventory.length,
                              separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                              itemBuilder: (context, idx) => _buildProductRow(context, ref, state.inventory[idx]),
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
      },
    );
  }

  Widget _buildProductRow(BuildContext context, WidgetRef ref, InventoryItem prod) {
    final isLow = prod.isLowStock;

    final Widget stockBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: isLow ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${prod.stockCount} units', style: TextStyle(color: isLow ? Colors.red.shade700 : Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
          if (isLow) ...[const SizedBox(width: 6), const Icon(Icons.arrow_downward, color: Colors.red, size: 12)],
        ],
      ),
    );

    final Widget updateBtn = OutlinedButton(
      onPressed: () {
        _stockController.text = prod.stockCount.toString();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Update Stock: ${prod.name}'),
            content: TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Current Stock Level', border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  final newStk = int.tryParse(_stockController.text);
                  Navigator.pop(ctx);
                  if (newStk != null) {
                    try {
                      await ref.read(appDataProvider.notifier).updateInventoryStock(prod.id, newStk);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stock updated for ${prod.name} to $newStk'), behavior: SnackBarBehavior.floating));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                      }
                    }
                  }
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
            Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${prod.category} • SKU: ${prod.sku} • Min: ${prod.minAlertThreshold}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10), overflow: TextOverflow.ellipsis),
          ],
        );

        if (isTight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [stockBadge, updateBtn])],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Expanded(child: info), const SizedBox(width: 8), stockBadge, const SizedBox(width: 12), updateBtn],
        );
      }),
    );
  }
}

// --- EXPENSES TAB ---

const _expenseCategories = ['RENT', 'UTILITIES', 'SUPPLIES', 'WAGES', 'MISC'];

class OwnerExpensesTab extends StatefulWidget {
  const OwnerExpensesTab({super.key});

  @override
  State<OwnerExpensesTab> createState() => _OwnerExpensesTabState();
}

class _OwnerExpensesTabState extends State<OwnerExpensesTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'MISC';
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
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
            final Map<String, double> catSums = {};
            double totalExpense = 0;
            for (final exp in state.expenses) {
              catSums[exp.category] = (catSums[exp.category] ?? 0.0) + exp.amount;
              totalExpense += exp.amount;
            }

            final Widget listWidget = Card(
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
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Expenses Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            SizedBox(height: 2),
                            Text('Transactions and categories tracker', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        Text('Total: Rs. ${totalExpense.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.redAccent)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (state.expenses.isEmpty)
                      const Text('No expenses logged yet.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                    else
                      ListView.builder(
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text('${exp.category} • ${exp.date != null ? _formatDateTime(exp.date) : '-'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Text('-Rs. ${exp.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );

            final Widget formAndBreakdownWidget = Column(
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Record New Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 20),
                          const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            items: _expenseCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _category = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text('Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(hintText: 'e.g. Tea and snacks', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please add a title' : null,
                          ),
                          const SizedBox(height: 16),
                          const Text('Amount (Rs.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(hintText: 'e.g. 150', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please add amount';
                              if (double.tryParse(val) == null) return 'Enter valid amount';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _submitting
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    setState(() => _submitting = true);
                                    final title = _titleController.text.trim();
                                    final amt = double.parse(_amountController.text);
                                    try {
                                      await ref.read(appDataProvider.notifier).addExpense(
                                            title: title,
                                            amount: amt,
                                            category: _category,
                                            date: DateTime.now().toIso8601String().split('T').first,
                                          );
                                      _titleController.clear();
                                      _amountController.clear();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Expense logged: $title (-Rs. ${amt.toStringAsFixed(0)})'), behavior: SnackBarBehavior.floating),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                                      }
                                    } finally {
                                      if (mounted) setState(() => _submitting = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: _submitting
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Log Expense Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 16),
                        ..._expenseCategories.map((cat) {
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
                                    Text('Rs. ${sum.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(value: ratio, minHeight: 4, backgroundColor: Colors.grey.shade100, color: Colors.redAccent.withValues(alpha: 0.7)),
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
              return SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Column(children: [listWidget, const SizedBox(height: 20), formAndBreakdownWidget]));
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: listWidget),
                Expanded(flex: 1, child: SingleChildScrollView(padding: const EdgeInsets.all(24.0), child: formAndBreakdownWidget)),
              ],
            );
          },
        );
      },
    );
  }
}
