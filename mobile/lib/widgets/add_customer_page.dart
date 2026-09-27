import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/app_data_provider.dart';
import '../data/models.dart';
import '../theme.dart';

/// Add Customer, as its own page.
///
/// This was an [AppDialog] opened from the directory. It became a page
/// because the form is the entire task rather than a confirmation on top of
/// something else, and because a dialog this tall has nowhere to go when the
/// keyboard opens on a phone - the old version had no scroll of its own, so
/// the fields and the buttons fought for what was left of the screen.
///
/// The VIP toggle that used to sit below the fields is gone at the owner's
/// request. `isVip` stays on the model and on existing client documents, so
/// anyone already marked VIP keeps their badge - but nothing in the app sets
/// it to true any more.
class AddCustomerPage extends ConsumerStatefulWidget {
  /// Only used to decide whether the "clients are shared across branches"
  /// note is worth showing, and to stamp where the client was registered.
  final List<Branch> branches;

  const AddCustomerPage({super.key, required this.branches});

  @override
  ConsumerState<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends ConsumerState<AddCustomerPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Drives the preview card's initials and name as they are typed. Local
    // state only - it rebuilds this page and touches nothing else.
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    // The dialog this replaced never disposed its controllers, so every time
    // it was opened and dismissed it leaked three of them.
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Same two-letter rule the client directory uses, so the preview matches
  /// the avatar this client will actually get in the list.
  String get _initials {
    final parts = _nameController.text
        .trim()
        .split(' ')
        .where((n) => n.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return parts.map((n) => n[0]).take(2).join().toUpperCase();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and phone are required.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await ref.read(appDataProvider.notifier).addCustomer(
            name: name,
            phone: phone,
            email: _emailController.text.trim(),
            registeredAtBranchId:
                widget.branches.isNotEmpty ? widget.branches.first.id : null,
          );
      if (!mounted) return;
      // Pop first, then report: the new client has just appeared in the
      // directory underneath, which is where the message belongs. The client
      // comes back as the route's result, so a caller that pushed this from
      // the billing picker can select them without a second search.
      Navigator.of(context).pop(created);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer "$name" added successfully!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
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
                    _fieldsCard(),
                    const SizedBox(height: 14),
                    _footerNote(),
                  ],
                ),
              ),
            ),
            _actionBar(context),
          ],
        ),
      ),
    );
  }

  /// A live preview of the client being created: the same initials avatar
  /// they will carry in the directory, filling in as the name is typed. It
  /// gives the top of an otherwise sparse form something to anchor on, and
  /// confirms what is about to be saved before the button is pressed.
  Widget _previewCard() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final hasName = name.isNotEmpty;

    return Container(
      // Keyed so tests can tell the preview's copy of the name apart from
      // the text field the name was typed into.
      key: const Key('addCustomerPreview'),
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
                  hasName ? name : 'New client',
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
                  phone.isNotEmpty
                      ? phone
                      : 'Their visits and spend start tracking from today',
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

  Widget _fieldsCard() {
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
              const Icon(
                PhosphorIconsBold.addressBook,
                size: 15,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 7),
              // Flexible, not a bare Text + Spacer: at a large text scale
              // (or in a longer translation) the two labels together exceed
              // the card and the row has no give.
              const Flexible(
                child: Text(
                  'Contact details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slateDark,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              const Flexible(
                child: Text(
                  '* required',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _field(
            controller: _nameController,
            label: 'Full Name *',
            hint: 'e.g. Priya Sharma',
            icon: PhosphorIconsRegular.user,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _phoneController,
            label: 'Phone Number *',
            hint: '10-digit mobile',
            icon: PhosphorIconsRegular.phone,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _emailController,
            label: 'Email Address',
            hint: 'Optional',
            icon: PhosphorIconsRegular.envelopeSimple,
            keyboardType: TextInputType.emailAddress,
            action: TextInputAction.done,
            onSubmitted: (_) {
              if (!_submitting) _submit();
            },
          ),
        ],
      ),
    );
  }

  /// Label above the box rather than a floating Material label: with an icon
  /// and a hint in play, a label that animates into the border crowds the
  /// field and makes the three rows read as different heights.
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.slateMedium,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: action,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
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
              borderSide: const BorderSide(
                color: AppTheme.primaryBlue,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Fills the space under a short form with the two things worth knowing
  /// before saving, rather than leaving it blank.
  Widget _footerNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _noteLine(
            PhosphorIconsRegular.receipt,
            'They can be billed straight away - the client picker in Billing '
            'will find them by name or phone.',
          ),
          if (widget.branches.length > 1) ...[
            const SizedBox(height: 10),
            _noteLine(
              PhosphorIconsRegular.storefront,
              'Clients are shared across all branches.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _noteLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.primaryBlue),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryDarker,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  /// Pinned to the bottom: the action stays reachable whatever the scroll
  /// position, and sits above the keyboard rather than under it, which is
  /// the thing the dialog could not manage.
  Widget _actionBar(BuildContext context) {
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
              onPressed:
                  _submitting ? null : () => Navigator.of(context).pop(),
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
              // Matches the Add Customer button in the directory that opens
              // this page, so the action keeps its identity across the push.
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
                    // min + Flexible so the label ellipsises rather than
                    // overflowing the button on a narrow phone.
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIconsBold.userPlus, size: 16),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Add Customer',
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
