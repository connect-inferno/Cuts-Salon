import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../theme.dart';

/// Create Employee Account, as its own page.
///
/// This was an [AppDialog] with eight fields stacked in it. At phone width
/// the two commission fields sat side by side with floating Material labels,
/// which clipped them to "Service Com..." and "Product Com..." - the two
/// numbers that decide what someone gets paid, unreadable. Labels sit above
/// their fields here, so they have the full width to themselves.
///
/// The fields are grouped rather than run together: this form creates a
/// login, a roster entry and a pay agreement all at once, and those are three
/// different decisions.
class AddEmployeePage extends ConsumerStatefulWidget {
  /// Active branches only - the caller filters, because an empty list is an
  /// error worth reporting before the page is ever pushed.
  final List<Branch> assignableBranches;

  const AddEmployeePage({super.key, required this.assignableBranches});

  @override
  ConsumerState<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends ConsumerState<AddEmployeePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController(text: 'Hair Stylist');
  final _salaryController = TextEditingController(text: '25000');
  final _serviceCommController = TextEditingController(text: '15');
  final _productCommController = TextEditingController(text: '5');

  late String _branchId = widget.assignableBranches.first.id;
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Drive the preview card and the live commission example. Local state
    // only - nothing here reads Firestore.
    for (final c in [_nameController, _roleController, _serviceCommController]) {
      c.addListener(_rebuild);
    }
    _passwordController.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    // The dialog this replaced disposed none of its eight controllers.
    for (final c in [
      _nameController,
      _emailController,
      _passwordController,
      _phoneController,
      _roleController,
      _salaryController,
      _serviceCommController,
      _productCommController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _initials {
    final parts =
        _nameController.text.trim().split(' ').where((n) => n.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.map((n) => n[0]).take(2).join().toUpperCase();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty) {
      _warn('Name, email, and phone are required.');
      return;
    }
    if (password.length < 8) {
      _warn('Password must be at least 8 characters.');
      return;
    }

    // Same fallbacks the dialog used: a blank or unparseable box keeps the
    // default rather than writing a zero into someone's pay terms.
    final salary = double.tryParse(_salaryController.text) ?? 25000;
    final serviceComm = double.tryParse(_serviceCommController.text) ?? 15;
    final productComm = double.tryParse(_productCommController.text) ?? 5;

    setState(() => _submitting = true);
    try {
      await ref.read(appDataProvider.notifier).addEmployee(
            name: name,
            phone: phone,
            roleTitle: _roleController.text.trim(),
            baseSalary: salary,
            serviceCommissionPct: serviceComm,
            productCommissionPct: productComm,
            email: email,
            password: password,
            branchId: _branchId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account created for $name. They can log in with the password you just set.',
          ),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _warn(e.toString());
    }
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.accentRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 560),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _previewCard(),
                    const SizedBox(height: 16),
                    _whoSection(),
                    const SizedBox(height: 14),
                    _loginSection(),
                    const SizedBox(height: 14),
                    _paySection(),
                  ],
                ),
              ),
            ),
            _actionBar(),
          ],
        ),
      ),
    );
  }

  Widget _previewCard() {
    final name = _nameController.text.trim();
    final role = _roleController.text.trim();
    final hasName = name.isNotEmpty;

    return Container(
      key: const Key('addEmployeePreview'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: hasName
                ? Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  )
                : const Icon(
                    PhosphorIconsRegular.userPlus,
                    size: 24,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasName ? name : 'New team member',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  role.isEmpty ? 'They can log in as soon as you save' : role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whoSection() {
    return _section(
      icon: PhosphorIconsBold.identificationCard,
      title: 'Who they are',
      children: [
        _field(
          controller: _nameController,
          label: 'Full Name *',
          hint: 'e.g. Jamie Davis',
          icon: PhosphorIconsRegular.user,
          textCapitalization: TextCapitalization.words,
        ),
        _field(
          controller: _phoneController,
          label: 'Phone Number *',
          hint: '+91 98765 43210',
          icon: PhosphorIconsRegular.phone,
          keyboardType: TextInputType.phone,
        ),
        _field(
          controller: _roleController,
          label: 'Stylist Role',
          hint: 'Senior Stylist / Colorist',
          icon: PhosphorIconsRegular.scissors,
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _loginSection() {
    final password = _passwordController.text;
    final longEnough = password.length >= 8;

    return _section(
      icon: PhosphorIconsBold.lockKey,
      title: 'How they sign in',
      note: 'These are real credentials - they can log in the moment you save.',
      children: [
        _field(
          controller: _emailController,
          label: 'Login Email *',
          hint: 'e.g. jamie@salon.com',
          icon: PhosphorIconsRegular.envelopeSimple,
          keyboardType: TextInputType.emailAddress,
        ),
        _field(
          controller: _passwordController,
          label: 'Login Password *',
          hint: 'At least 8 characters',
          icon: PhosphorIconsRegular.lockKey,
          obscure: _obscurePassword,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? PhosphorIconsRegular.eyeSlash
                  : PhosphorIconsRegular.eye,
              size: 18,
              color: AppTheme.slateLight,
            ),
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          // Tells you the rule is met before you press the button, rather
          // than rejecting the whole form afterwards.
          helper: password.isEmpty
              ? null
              : _requirement(
                  met: longEnough,
                  text: longEnough
                      ? 'Long enough'
                      : '${8 - password.length} more character${8 - password.length == 1 ? '' : 's'} needed',
                ),
        ),
      ],
    );
  }

  Widget _paySection() {
    return _section(
      icon: PhosphorIconsBold.wallet,
      title: 'Branch and pay',
      children: [
        _branchPicker(),
        _field(
          controller: _salaryController,
          label: 'Base Retainer (₹ per month)',
          hint: '25000',
          icon: PhosphorIconsRegular.wallet,
          keyboardType: TextInputType.number,
        ),
        Row(
          children: [
            Expanded(
              child: _field(
                controller: _serviceCommController,
                // Full label, not the "Service Com..." the dialog clipped it
                // to: it sits above the box with the whole width available.
                label: 'Service Commission (%)',
                hint: '15',
                icon: PhosphorIconsRegular.percent,
                keyboardType: TextInputType.number,
                dense: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                controller: _productCommController,
                label: 'Product Commission (%)',
                hint: '5',
                icon: PhosphorIconsRegular.percent,
                keyboardType: TextInputType.number,
                dense: true,
              ),
            ),
          ],
        ),
        _commissionExample(),
      ],
    );
  }

  /// A percentage is abstract; the rupees it produces are not. Shows what the
  /// service rate actually pays on a round number, so a typo (1.5 for 15) is
  /// obvious before the pay terms are saved.
  Widget _commissionExample() {
    final pct = double.tryParse(_serviceCommController.text);
    if (pct == null || pct <= 0) return const SizedBox.shrink();
    final earned = (1000 * pct / 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.accentGreenBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsBold.calculator,
            size: 14,
            color: AppTheme.accentGreen,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'On ₹1,000 of services they earn ₹$earned',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF027A48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chips rather than a dropdown: a salon has a handful of branches, and a
  /// Wrap grows down the page instead of overflowing sideways.
  Widget _branchPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Branch *',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.slateMedium,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in widget.assignableBranches)
              _branchChip(b, selected: _branchId == b.id),
          ],
        ),
      ],
    );
  }

  Widget _branchChip(Branch branch, {required bool selected}) {
    return InkWell(
      onTap: () => setState(() => _branchId = branch.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : AppTheme.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? PhosphorIconsFill.storefront
                  : PhosphorIconsRegular.storefront,
              size: 14,
              color: selected ? AppTheme.primaryBlue : AppTheme.slateLight,
            ),
            const SizedBox(width: 7),
            Text(
              branch.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppTheme.primaryDark : AppTheme.slateMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    String? note,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: AppTheme.slateDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppTheme.primaryBlue),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slateDark,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.slateLight,
                height: 1.4,
              ),
            ),
          ],
          for (final child in children) ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }

  Widget _requirement({required bool met, required String text}) {
    final color = met ? AppTheme.accentGreen : AppTheme.slateLight;
    return Row(
      children: [
        Icon(
          met ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// Label above the box rather than a floating Material label. With an icon
  /// and a hint in play, a label that animates into the border runs out of
  /// room - which is exactly how the two commission fields ended up reading
  /// "Service Com..." and "Product Com...".
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscure = false,
    Widget? suffix,
    Widget? helper,
    bool dense = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.slateMedium,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          obscureText: obscure,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.slateDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
            prefixIcon: Icon(icon, size: 18, color: AppTheme.slateLight),
            // A narrow half-width box has no room for a 48px icon gutter.
            prefixIconConstraints: dense
                ? const BoxConstraints(minWidth: 34, minHeight: 34)
                : null,
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          helper,
        ],
      ],
    );
  }

  Widget _actionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: const Border(top: BorderSide(color: AppTheme.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.slateDark.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.slateMedium,
                side: const BorderSide(color: AppTheme.borderStrong),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _submitting
                    ? null
                    : const LinearGradient(
                        colors: [AppTheme.primaryBlue, Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _submitting
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFC7D2FE),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIconsBold.userPlus, size: 16),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Create Account',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
