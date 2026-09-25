import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data_provider.dart';
import '../../../theme.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/async_state_views.dart';

String _formatRupees(double amount) {
  final whole = amount.round().toString();
  if (whole.length <= 3) return '₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole.substring(0, whole.length - 3);
  final grouped = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '₹$grouped,$last3';
}

/// The tax half of System Settings, on its own page under Billing's gear.
///
/// The GST switch and its rate decide what every bill totals to, but they
/// used to sit at the bottom of a general Settings page four nav entries
/// away from Billing - so "why is this total higher than the sum of the
/// services" was a question you could only answer by already knowing where
/// to look. The full Settings page still owns these same two fields; this
/// is the same state, reached from where its effect is felt.
class OwnerTaxSettingsPage extends ConsumerStatefulWidget {
  const OwnerTaxSettingsPage({super.key});

  @override
  ConsumerState<OwnerTaxSettingsPage> createState() => _OwnerTaxSettingsPageState();
}

class _OwnerTaxSettingsPageState extends ConsumerState<OwnerTaxSettingsPage> {
  final _gstRateController = TextEditingController();
  bool _gstEnabled = false;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _gstRateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rate = double.tryParse(_gstRateController.text.replaceAll('%', '').trim());
    if (_gstEnabled && (rate == null || rate < 0 || rate > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a GST rate between 0 and 100'),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(appDataProvider.notifier).updateSettings({
        'gstEnabled': _gstEnabled,
        // Saved even while disabled, so turning GST back on restores the
        // rate they already configured instead of asking for it again.
        'gstRate': rate ?? 0.0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tax settings saved'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);

    return asyncData.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(
        error: err,
        onRetry: () => ref.read(appDataProvider.notifier).refresh(),
      ),
      data: (state) {
        if (!_initialized && state.settings != null) {
          _gstEnabled = state.settings!.gstEnabled;
          _gstRateController.text = state.settings!.gstRate.toStringAsFixed(0);
          _initialized = true;
        }

        final rate = double.tryParse(_gstRateController.text.trim()) ?? 0;
        // A worked example on a round number, so the effect of the switch is
        // visible before saving rather than discovered on a real client's bill.
        const sample = 1000.0;
        final sampleTax = _gstEnabled ? sample * (rate / 100) : 0.0;

        // topCenter, not Center: this page is shorter than the viewport, and
        // a plain Center floats the whole form into the middle of the screen
        // with a dead band under the section description.
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                PhosphorIconsFill.percent,
                                size: 17,
                                color: Color(0xFF0EA5E9),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Charge GST on bills',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.slateDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Applies to every new bill from now on',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.slateLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _gstEnabled,
                              activeThumbColor: AppTheme.primaryBlue,
                              onChanged: (v) => setState(() => _gstEnabled = v),
                            ),
                          ],
                        ),
                        if (_gstEnabled) ...[
                          const Divider(height: 26, color: AppTheme.borderSubtle),
                          TextField(
                            controller: _gstRateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: appDialogFieldDecoration(
                              label: 'GST rate (%)',
                              hint: 'e.g. 18',
                              icon: PhosphorIconsRegular.percent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ON A ₹1,000 BILL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryBlue,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _taxPreviewRow('Services & products', _formatRupees(sample)),
                        _taxPreviewRow(
                          _gstEnabled ? 'GST @ ${rate.toStringAsFixed(0)}%' : 'GST (off)',
                          _formatRupees(sampleTax),
                        ),
                        const Divider(height: 16, color: Color(0xFFC7D2FE)),
                        _taxPreviewRow(
                          'Client pays',
                          _formatRupees(sample + sampleTax),
                          emphasise: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Tax Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _taxPreviewRow(String label, String value, {bool emphasise = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasise ? 13.5 : 12.5,
              fontWeight: emphasise ? FontWeight.w800 : FontWeight.w600,
              color: emphasise ? AppTheme.slateDark : AppTheme.slateMedium,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasise ? 16 : 12.5,
              fontWeight: emphasise ? FontWeight.w800 : FontWeight.w700,
              color: emphasise ? AppTheme.slateDark : AppTheme.slateMedium,
              letterSpacing: emphasise ? -0.4 : 0,
            ),
          ),
        ],
      ),
    );
  }
}
