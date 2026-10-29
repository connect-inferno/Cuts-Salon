import 'package:flutter/material.dart';
import '../../../router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../widgets/liquid_nav_bar.dart';
import '../../../data/salary_provider.dart';
import '../../../data/models.dart';
import '../../../data/attendance_labels.dart';
import '../../../data/attendance_shift.dart';
import '../../../widgets/load_older_attendance.dart';
import '../../../data/client_search.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_page_switcher.dart';
import '../../../widgets/add_customer_page.dart';
import '../../../widgets/app_sub_page.dart';
import '../../../widgets/pay_period_picker.dart';
import '../../../widgets/dues_view.dart';
import '../../../widgets/async_state_views.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/birthday_picker.dart';
import '../../../widgets/open_link.dart';
import '../../../data/birthday.dart';
import '../../auth/auth_provider.dart';
import 'add_employee_page.dart';
import 'owner_shift_card.dart';
import 'attendance_qr_page.dart';
import 'owner_birthdays_page.dart';
import '../../../widgets/ds.dart';
import 'owner_payroll_view.dart';
import '../../../data/money.dart';

/// How overdue a client is for their next appointment.
///
/// Public, unlike the widgets around it, so the boundary days can be unit
/// tested without pumping the whole directory - see
/// `test/client_follow_up_test.dart`.
///
/// The salon's working assumption is that a haircut lasts about three weeks,
/// so a client who has not come back 21 days after their last visit is one
/// worth chasing, and the two days before that are the window to call them in
/// before they drift. Both are counted in whole calendar days from
/// `lastVisitAt`, which billing already maintains on the customer document -
/// so the markers cost no extra Firestore read, they are derived from the
/// AppData snapshot the directory has already loaded.
enum FollowUp { none, dueSoon, overdue }

const _kShortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Added by Anjali on 12 Sep 2026", degrading to whichever half is known.
/// Clients created before the creator stamp existed carry neither field, and
/// the caller leaves the line out entirely rather than printing "Added by
/// Unknown" over a record nobody did anything wrong with.
String _addedByLine(Customer cust) {
  final who = cust.createdByName;
  final when = cust.createdAt;
  final date = when == null ? null : '${when.day} ${_kShortMonths[when.month - 1]} ${when.year}';
  if (who != null && date != null) return 'Added by $who on $date';
  if (who != null) return 'Added by $who';
  return 'Added on $date';
}

const int kFollowUpDays = 21;
const int kFollowUpWarningDays = 2;

// Marker colours. Red and amber rather than two shades of one hue, so the
// two states are still distinguishable to a red-green colour-blind reader;
// the dot is always paired with a day count for the same reason.
const Color _kOverdueColor = Color(0xFFDC2626);
const Color _kOverdueBg = Color(0xFFFEF2F2);
const Color _kDueSoonColor = Color(0xFFD97706);
const Color _kDueSoonBg = Color(0xFFFFFBEB);

FollowUp followUpFor(Customer cust, DateTime now) {
  final last = cust.lastVisitAt;
  // Never been in: there is no visit to be overdue from. A client added but
  // not yet billed must not show up as if they had lapsed.
  if (last == null) return FollowUp.none;
  final days = daysSinceVisit(last, now);
  if (days >= kFollowUpDays) return FollowUp.overdue;
  if (days >= kFollowUpDays - kFollowUpWarningDays) return FollowUp.dueSoon;
  return FollowUp.none;
}

/// Whole calendar days, not elapsed 24-hour periods: a visit late yesterday
/// evening is "1 day ago" the next morning, which is how anyone reading the
/// screen counts it.
int daysSinceVisit(DateTime last, DateTime now) {
  final lastDay = DateTime(last.year, last.month, last.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(lastDay).inDays;
}

String _initials(String name) => name.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join();


String _formatDate(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _formatShortDate(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _formatMonthDay(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

// --- CUSTOMERS TAB ---

class OwnerCustomersTab extends StatefulWidget {
  final ValueChanged<Customer>? onStartBill;
  final VoidCallback? onOpenNotifications;

  const OwnerCustomersTab({
    super.key,
    this.onStartBill,
    this.onOpenNotifications,
  });

  @override
  State<OwnerCustomersTab> createState() => _OwnerCustomersTabState();
}

class _OwnerCustomersTabState extends State<OwnerCustomersTab> with _CustomerDetailSections {
  @override
  List<Bill>? get customerBills => _customerBills;
  @override
  bool get loadingBills => _loadingBills;
  @override
  ValueChanged<Customer>? get startBill => widget.onStartBill;

  final _searchController = TextEditingController();
  Customer? _selectedCustomer;
  String _activeFilter = 'All'; // 'All', 'VIP', 'Recent'
  List<Bill>? _customerBills;
  bool _loadingBills = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomer(WidgetRef ref, Customer cust) async {
    setState(() {
      _selectedCustomer = cust;
      _customerBills = null;
      _loadingBills = true;
    });
    try {
      final bills = await ref.read(appDataProvider.notifier).loadBillsForCustomer(cust.id);
      if (mounted && _selectedCustomer?.id == cust.id) {
        setState(() {
          _customerBills = bills;
          _loadingBills = false;
        });
      }
    } catch (_) {
      if (mounted && _selectedCustomer?.id == cust.id) {
        setState(() {
          _customerBills = [];
          _loadingBills = false;
        });
      }
    }
  }

  // No branch picker here on purpose: the client directory is salon-wide, so
  // a customer added at one branch is immediately visible and billable at
  // every other one. (This dialog used to ask for a branch, which implied a
  // per-branch client list the app never actually enforced.) The branch they
  // happened to be registered at is still recorded for reference.
  void _openAddCustomer(BuildContext context, List<Branch> branches) {
    // A full page rather than a dialog: the form is the whole task, and on a
    // phone a dialog this tall fights the keyboard for room (see the old
    // AppDialog version, which had no scroll of its own).
    openAppSubPage(
      context,
      title: 'Add client',
      subtitle: 'Save their details to start tracking visits',
      child: AddCustomerPage(branches: branches),
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
          data: (state) => Container(
            color: AppTheme.bgSurface,
            child: Column(
              children: [
                AppPageHeader(
                  title: 'Clients',
                  subtitle: '${state.customers.length} on the books',
                  actions: [
                    // Add, then the bell. (The gear here opened "Client
                    // Settings", which held nothing but the archived list -
                    // already the Archived filter chip on this page.)
                    AppPageAction(
                      icon: PhosphorIconsBold.plus,
                      label: 'Add',
                      tooltip: 'Add client',
                      onTap: () => _openAddCustomer(context, state.branches),
                    ),
                    AppPageAction(
                      icon: PhosphorIconsRegular.bell,
                      tooltip: 'Requests',
                      badgeCount: state.pendingPaymentRequestCount,
                      onTap: () => widget.onOpenNotifications?.call(),
                    ),
                  ],
                ),
                Expanded(child: _buildBody(context, ref, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Directory rows carry only the name (plus the VIP star, which is the one
  // thing staff scan the list for) - everything else lives on the detail page.
  Widget _buildCustomerNameRow(
    BuildContext context,
    WidgetRef ref,
    Customer cust,
    bool archived,
    DateTime now,
  ) {
    // The follow-up state colours the whole row, not just the badge at its
    // end. A 7px dot at the far right of a long list is easy to miss while
    // scrolling, and the two markers only mean something in contrast with
    // the rows around them - a tinted band plus a left rule is what makes
    // "three of these need chasing" readable at a glance.
    final followUp = archived ? FollowUp.none : followUpFor(cust, now);
    final rowTint = switch (followUp) {
      FollowUp.overdue => _kOverdueBg,
      FollowUp.dueSoon => _kDueSoonBg,
      FollowUp.none => Colors.transparent,
    };
    final rowRule = switch (followUp) {
      FollowUp.overdue => _kOverdueColor,
      FollowUp.dueSoon => _kDueSoonColor,
      FollowUp.none => Colors.transparent,
    };

    return InkWell(
      onTap: archived ? null : () => _openCustomerDetail(context, ref, cust),
      child: Container(
        decoration: BoxDecoration(
          color: rowTint,
          // A 3px rule down the left edge, so the state survives being read
          // in greyscale or by someone who cannot separate red from amber.
          border: Border(left: BorderSide(color: rowRule, width: 3)),
        ),
        padding: EdgeInsets.fromLTRB(
          // Keeps every avatar on the same vertical line whether or not the
          // row carries a rule.
          followUp == FollowUp.none ? 14 : 11,
          13,
          14,
          13,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: switch (followUp) {
                FollowUp.overdue => const Color(0xFFFEE2E2),
                FollowUp.dueSoon => const Color(0xFFFEF3C7),
                FollowUp.none => AppTheme.avatarColorsFor(cust.name).$1,
              },
              child: Text(
                _initials(cust.name),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: switch (followUp) {
                    FollowUp.overdue => _kOverdueColor,
                    FollowUp.dueSoon => _kDueSoonColor,
                    FollowUp.none => AppTheme.avatarColorsFor(cust.name).$2,
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cust.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Phone and last visit under the name - the two things
                  // staff check before calling or billing someone, which
                  // used to take opening each client's page.
                  Text(
                    '${cust.phone} · ${_lastVisitLabel(cust, now)}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Follow-up marker. Archived clients are excluded: they have been
            // deliberately taken out of circulation, so chasing them back in
            // is not a thing the salon wants to be nudged about.
            if (!archived) ...[
              _followUpMarker(cust, now),
            ],
            if (cust.isVip) ...[
              const Icon(PhosphorIconsFill.star, size: 13, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
            ],
            if (archived)
              TextButton.icon(
                onPressed: () => _confirmUnarchiveCustomer(context, ref, cust),
                icon: const Icon(PhosphorIconsRegular.arrowCounterClockwise, size: 15),
                label: const Text('Restore', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(PhosphorIconsBold.dotsThree, size: 18, color: Color(0xFF94A3B8)),
                tooltip: 'Options',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showCustomerOptions(context, ref, cust),
              ),
              const Icon(PhosphorIconsBold.caretRight, size: 14, color: Color(0xFFCBD5E1)),
            ],
          ],
        ),
      ),
    );
  }

  String _lastVisitLabel(Customer cust, DateTime now) {
    final last = cust.lastVisitAt;
    if (last == null) return 'No visits yet';
    final days = daysSinceVisit(last, now);
    if (days <= 0) return 'Visited today';
    if (days == 1) return 'Visited yesterday';
    return 'Last visit $days days ago';
  }

  /// The red/amber dot beside a client's name, with the day count next to
  /// it. Returns an empty box for everyone else, so the column only carries
  /// weight for the clients who need chasing.
  Widget _followUpMarker(Customer cust, DateTime now) {
    final status = followUpFor(cust, now);
    if (status == FollowUp.none) return const SizedBox.shrink();

    final overdue = status == FollowUp.overdue;
    final days = daysSinceVisit(cust.lastVisitAt!, now);
    final color = overdue ? _kOverdueColor : _kDueSoonColor;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: overdue
            ? 'Overdue - last visit $days days ago, past the $kFollowUpDays-day mark'
            : 'Due in ${kFollowUpDays - days} day${kFollowUpDays - days == 1 ? '' : 's'} - last visit $days days ago',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: overdue ? _kOverdueBg : _kDueSoonBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              // The number is what makes the two markers tellable apart
              // without relying on colour alone.
              Text(
                '${days}d',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmUnarchiveCustomer(BuildContext context, WidgetRef ref, Customer cust) {
    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.arrowCounterClockwise,
          title: 'Restore ${cust.name}?',
          subtitle: 'They will appear in the directory and billing again.',
          child: const Text(
            'Their visit history and totals are unchanged - nothing was lost while they were archived.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.slateMedium, height: 1.4),
          ),
          actions: AppDialogActions(
            submitLabel: 'Restore',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).unarchiveCustomer(cust.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${cust.name} restored.'), backgroundColor: AppTheme.accentGreen),
                  );
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _openCustomerDetail(BuildContext context, WidgetRef ref, Customer cust) {
    // Keep the tab's own selection in step so the options sheet opened from
    // the list still has this client's bills loaded behind it.
    _selectCustomer(ref, cust);
    pushAppRoute(
      context,
      OwnerCustomerDetailPage(
        customerId: cust.id,
        onStartBill: widget.onStartBill,
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppData state) {

    final query = _searchController.text.toLowerCase().trim();
    final showingArchived = _activeFilter == 'Archived';
    // One clock reading for the whole build, so a customer can't land in two
    // different buckets because midnight passed between two calls.
    final now = DateTime.now();
    // Archived clients live in their own list precisely so they can't show up
    // anywhere else, so this is the one screen that reads it - and only when
    // the Archived chip is active.
    final source = showingArchived ? state.archivedCustomers : state.customers;
    final filteredCustomers = source.where((cust) {
      final matchesSearch = customerMatchesQuery(cust, query);

      if (!matchesSearch) return false;
      if (_activeFilter == 'Recent') return cust.visitCount > 0;
      if (_activeFilter == 'Overdue') {
        return followUpFor(cust, now) == FollowUp.overdue;
      }
      if (_activeFilter == 'DueSoon') {
        return followUpFor(cust, now) == FollowUp.dueSoon;
      }
      return true;
    }).toList();

    final allCount = state.customers.length;
    final archivedCount = state.archivedCustomers.length;

    // One pass for all three chip counts. Typing in the search box rebuilds
    // on every keystroke, so a separate `.where().length` per chip walks the
    // whole client list three extra times per character - free at two
    // clients, not at the ten thousand listCustomers() is written to expect.
    var recentCount = 0;
    var overdueCount = 0;
    var dueSoonCount = 0;
    for (final c in state.customers) {
      if (c.visitCount > 0) recentCount++;
      switch (followUpFor(c, now)) {
        case FollowUp.overdue:
          overdueCount++;
        case FollowUp.dueSoon:
          dueSoonCount++;
        case FollowUp.none:
          break;
      }
    }
    // Clients carrying an unpaid balance, for the Pending Payments button's
    // badge. Derived the same way DuesView groups its rows - unpaid bills by
    // customerId - so the badge and the page it opens can never disagree.
    // customers.outstandingBalance would be the cheaper read but counts a
    // different set: it includes archived clients, whom DuesView also shows,
    // and is maintained independently of the (capped) loaded bills list.
    final owingCount = state.bills
        .where((b) => !b.isFullyPaid)
        .map((b) => b.customerId)
        .toSet()
        .length;

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: const Color(0xFFF8F9FC),
      // topCenter, not Center: this only exists to cap the content width on
      // desktop. A plain Center also centres vertically, which left a big gap
      // above the header whenever the page was shorter than the viewport.
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
          child: SingleChildScrollView(
            // Bottom padding ensures list is not cut off by floating bottom navbar
            padding: const EdgeInsets.fromLTRB(16, 12, 16, LiquidNavBar.barInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // At-a-glance cards: money owed, birthdays coming up, and
                // clients overdue for a visit - each opens where it's dealt
                // with. (The old row here was a Dues pill and a floating Add
                // button; Add now sits beside the search box.)
                _buildClientSummary(context, state, owingCount, overdueCount, now),
                const SizedBox(height: 14),

                // 3. Search Bar
                // Full-width search; Add is in the page header.
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search name or mobile number',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: Color(0xFF94A3B8), size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Filter Chips Row. Scrolls horizontally - five chips do
                // not fit across a phone, and wrapping them onto a second
                // line pushes the directory itself below the fold.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All ($allCount)',
                        isSelected: _activeFilter == 'All',
                        onTap: () => setState(() => _activeFilter = 'All'),
                      ),
                      const SizedBox(width: 8),
                      // The two follow-up markers. Red first: an overdue
                      // client is the one costing the salon money today.
                      _buildFilterChip(
                        label: 'Overdue ($overdueCount)',
                        icon: PhosphorIconsFill.circle,
                        isSelected: _activeFilter == 'Overdue',
                        onTap: () => setState(() => _activeFilter = 'Overdue'),
                        accent: _kOverdueColor,
                        accentBg: _kOverdueBg,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Due soon ($dueSoonCount)',
                        icon: PhosphorIconsFill.circle,
                        isSelected: _activeFilter == 'DueSoon',
                        onTap: () => setState(() => _activeFilter = 'DueSoon'),
                        accent: _kDueSoonColor,
                        accentBg: _kDueSoonBg,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Recent ($recentCount)',
                        icon: PhosphorIconsRegular.clock,
                        isSelected: _activeFilter == 'Recent',
                        onTap: () => setState(() => _activeFilter = 'Recent'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Archived ($archivedCount)',
                        icon: PhosphorIconsRegular.archive,
                        isSelected: showingArchived,
                        onTap: () => setState(() => _activeFilter = 'Archived'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 5. Customer Directory - names only; tapping opens the
                // full detail page.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All clients',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      showingArchived
                          ? '${filteredCustomers.length} archived'
                          : '${filteredCustomers.length} shown',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (filteredCustomers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        showingArchived
                            ? 'No archived customers.'
                            : 'No customers match your search.',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (int i = 0; i < filteredCustomers.length; i++) ...[
                          if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          _buildCustomerNameRow(
                            context,
                            ref,
                            filteredCustomers[i],
                            showingArchived,
                            now,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientSummary(BuildContext context, AppData state, int owingCount, int overdueCount, DateTime now) {
    final dueTotal = state.bills.where((b) => !b.isFullyPaid).fold<double>(0, (sum, b) => sum + b.amountDue);
    var birthdaysThisWeek = 0;
    for (final c in state.customers) {
      final d = OwnerBirthdaysPage.daysUntil(c, now);
      if (d != null && d <= 6) birthdaysThisWeek++;
    }
    String rupees(double v) {
      final whole = v.round().toString();
      if (whole.length <= 3) return '₹$whole';
      final last3 = whole.substring(whole.length - 3);
      final rest = whole.substring(0, whole.length - 3).replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
      return '₹$rest,$last3';
    }

    Widget card({
      required IconData icon,
      required Color tint,
      required Color tintBg,
      required String label,
      required String value,
      required String caption,
      required VoidCallback onTap,
    }) {
      return Expanded(
        // Icon beside the number rather than stacked above it - the cards
        // were taller than one figure each needs.
        child: DsCard(
          padding: const EdgeInsets.all(12),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: tintBg, borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 15, color: tint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slateDark, letterSpacing: -0.3)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
              const SizedBox(height: 1),
              Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(
          icon: PhosphorIconsRegular.handCoins,
          tint: AppTheme.accentOrange,
          tintBg: AppTheme.accentOrangeBg,
          label: 'Dues',
          value: rupees(dueTotal),
          caption: owingCount == 0 ? 'All paid' : '$owingCount client${owingCount == 1 ? '' : 's'}',
          onTap: () => openAppSubPage(
            context,
            title: 'Dues',
            subtitle: 'What clients still owe, by client',
            child: const DuesView(),
          ),
        ),
        const SizedBox(width: 10),
        card(
          icon: PhosphorIconsRegular.cake,
          tint: AppTheme.accentRose,
          tintBg: AppTheme.accentRoseBg,
          label: 'Birthdays',
          value: '$birthdaysThisWeek',
          caption: 'this week',
          onTap: () => openAppSubPage(
            context,
            title: 'Birthdays',
            subtitle: 'Wish your clients on their day',
            child: const OwnerBirthdaysPage(),
          ),
        ),
        const SizedBox(width: 10),
        card(
          icon: PhosphorIconsRegular.clockCounterClockwise,
          tint: AppTheme.accentBlue,
          tintBg: AppTheme.accentBlueBg,
          label: 'Due a visit',
          value: '$overdueCount',
          caption: '21+ days',
          onTap: () => setState(() => _activeFilter = overdueCount > 0 ? 'Overdue' : 'All'),
        ),
      ],
    );
  }

  /// [accent] recolours the chip - used by the two follow-up markers so the
  /// red and amber dots read the same on the chip as they do in the list.
  /// Their icon keeps its colour whether the chip is selected or not; that
  /// dot *is* the marker, so greying it out when unselected would hide the
  /// very thing the chip is named after.
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? accent,
    Color? accentBg,
  }) {
    final fg = accent ?? const Color(0xFF1E3A5F);
    final selectedBg = accentBg ?? const Color(0xFFEEF2F7);
    final selectedBorder = accent ?? const Color(0xFFC3D0E2);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: accent != null ? 9 : 12,
                color: accent ?? (isSelected ? fg : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? fg : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen detail view for one client, pushed from the directory list.
// Keyed by id so an edit (or an archive) re-resolves against live AppData.
// It loads that client's full bill history itself - AppData's `bills` list is
// capped, so older visits would be missing if we read from there.
class OwnerCustomerDetailPage extends ConsumerStatefulWidget {
  final String customerId;
  final ValueChanged<Customer>? onStartBill;

  const OwnerCustomerDetailPage({super.key, required this.customerId, this.onStartBill});

  @override
  ConsumerState<OwnerCustomerDetailPage> createState() => _OwnerCustomerDetailPageState();
}

class _OwnerCustomerDetailPageState extends ConsumerState<OwnerCustomerDetailPage>
    with _CustomerDetailSections {
  List<Bill>? _bills;
  bool _loading = true;

  @override
  List<Bill>? get customerBills => _bills;
  @override
  bool get loadingBills => _loading;
  // The dashboard's handler switches the tab underneath to Billing - this
  // page is pushed on top of it, so it has to close itself first or New
  // Bill looks like it did nothing.
  @override
  ValueChanged<Customer>? get startBill => widget.onStartBill == null
      ? null
      : (customer) {
          Navigator.of(context).pop();
          widget.onStartBill!(customer);
        };

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    try {
      final bills = await ref.read(appDataProvider.notifier).loadBillsForCustomer(widget.customerId);
      if (mounted) setState(() { _bills = bills; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _bills = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: asyncData.when(
        loading: () => const AppLoadingView(),
        error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
        data: (state) {
          final matches = state.customers.where((c) => c.id == widget.customerId);
          if (matches.isEmpty) {
            // Archiving from this page removes the client from the snapshot,
            // so this is also the frame right before the pop lands.
            return _buildShell(context, null, const Center(
              child: Text(
                'This client is no longer in the directory.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ));
          }
          final cust = matches.first;
          return _buildShell(
            context,
            cust,
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: _buildCustomerHeroCard(context, ref, cust, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShell(BuildContext context, Customer? cust, Widget body) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 20, color: Color(0xFF0F172A)),
                  tooltip: 'Back to directory',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Just a title - the card below already shows the avatar,
                // name, phone and VIP badge, and they used to appear twice.
                if (cust != null) ...[
                  const Expanded(
                    child: Text(
                      'Client',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.3),
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// One customer's detail UI - the hero card, its metric tiles, the options
// sheet and the full visit-history sheet. Shared by OwnerCustomersTab (which
// still uses the options sheet from its list) and by the pushed
// OwnerCustomerDetailPage, so both render identical cards.
/// The "Birthday & WhatsApp" dialog for one client - shared by the client
/// page and the Birthdays page (owner_birthdays_page.dart).
void showClientBirthdayDialog(BuildContext context, WidgetRef ref, Customer cust) {
  String? birthday = parseBirthday(cust.birthday) == null ? null : cust.birthday;
  bool optIn = cust.whatsappOptIn;
  bool submitting = false;
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AppDialog(
        icon: PhosphorIconsRegular.cake,
        iconColor: const Color(0xFF16A34A),
        iconBackground: const Color(0xFFDCFCE7),
        title: cust.name,
        subtitle: 'Birthday and WhatsApp consent',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BirthdayPicker(initial: birthday, onChanged: (b) => birthday = b),
            const SizedBox(height: 8),
            WhatsAppOptInTile(value: optIn, onChanged: (v) => setDialogState(() => optIn = v)),
          ],
        ),
        actions: AppDialogActions(
          submitLabel: 'Save',
          submitting: submitting,
          onCancel: () => Navigator.pop(ctx),
          onSubmit: () async {
            setDialogState(() => submitting = true);
            try {
              await ref.read(appDataProvider.notifier).updateCustomerWhatsApp(
                    cust.id,
                    birthday: birthday,
                    whatsappOptIn: optIn,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${cust.name} updated.'), backgroundColor: AppTheme.accentGreen),
                );
              }
            } catch (e) {
              setDialogState(() => submitting = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed),
                );
              }
            }
          },
        ),
      ),
    ),
  );
}

mixin _CustomerDetailSections<T extends StatefulWidget> on State<T> {
  List<Bill>? get customerBills;
  bool get loadingBills;
  ValueChanged<Customer>? get startBill;

  void _showCustomerOptions(BuildContext context, WidgetRef ref, Customer cust) {
    showModalBottomSheet(
      context: context,
      // Scroll-controlled and scrollable: with Birthday & WhatsApp added
      // the list outgrew the default half-height sheet and overflowed.
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.avatarColorsFor(cust.name).$1,
                      child: Text(_initials(cust.name), style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.avatarColorsFor(cust.name).$2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cust.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          Text(cust.phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.receipt, color: Color(0xFF1E3A5F)),
                  title: const Text('New bill', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    startBill?.call(cust);
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.phone, color: Color(0xFF2F4E79)),
                  title: const Text('Call', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _callClient(context, cust);
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.whatsappLogo, color: Color(0xFF16A34A)),
                  title: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _whatsappClient(context, cust);
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.clockCounterClockwise, color: Color(0xFF1E3A5F)),
                  title: const Text('All visits', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAllBillsDialog(context, cust, customerBills ?? []);
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.cake, color: Color(0xFF16A34A)),
                  title: const Text('Birthday & WhatsApp', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    [
                      formatBirthday(cust.birthday) ?? 'No birthday',
                      cust.whatsappOptIn ? 'WhatsApp OK' : 'No WhatsApp consent',
                    ].join(' • '),
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editBirthdayAndWhatsApp(context, ref, cust);
                  },
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.archive, color: AppTheme.accentRed),
                  title: const Text('Remove client', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accentRed)),
                  subtitle: const Text('Hides them from the app - billing history is kept', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmArchiveCustomer(context, ref, cust);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // These two used to only show a "Calling..." / "Opening messaging..."
  // snackbar and do nothing else, which read as a broken button.
  void _callClient(BuildContext context, Customer cust) {
    final number = cust.phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (number.isEmpty || !openLink('tel:$number')) {
      _linkFailed(context, 'Could not start a call to ${cust.phone}.');
    }
  }

  /// Opens a WhatsApp chat with the client from the staff member's own
  /// WhatsApp - unrelated to the salon's automatic messages, and so not
  /// gated on the client's WhatsApp consent.
  void _whatsappClient(BuildContext context, Customer cust) {
    final number = whatsappNumber(cust.phone);
    if (number == null || !openLink('https://wa.me/$number')) {
      _linkFailed(context, '${cust.phone} does not look like a WhatsApp number.');
    }
  }

  void _linkFailed(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.accentRed, behavior: SnackBarBehavior.floating),
    );
  }

  // Clients registered before birthdays existed - or who only share one on
  // a later visit - get it here. These two fields drive the WhatsApp
  // messages (functions/index.js), which is why they're the editable ones.
  void _editBirthdayAndWhatsApp(BuildContext context, WidgetRef ref, Customer cust) =>
      showClientBirthdayDialog(context, ref, cust);

  // Firestore blocks real customer deletes (see archiveCustomer) - this hides
  // the client everywhere without touching a single bill.
  void _confirmArchiveCustomer(BuildContext context, WidgetRef ref, Customer cust) {
    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.archive,
          iconColor: AppTheme.accentRed,
          iconBackground: AppTheme.accentRedBg,
          title: 'Remove ${cust.name}?',
          subtitle: 'They will no longer appear in the directory, search, or billing.',
          child: const Text(
            'Their past bills and visit history stay exactly as they are - nothing is deleted. '
            'To bring them back, set archived to false on their record in the Firebase Console.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.slateMedium, height: 1.4),
          ),
          actions: AppDialogActions(
            submitLabel: 'Remove',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).archiveCustomer(cust.id);
                if (ctx.mounted) Navigator.pop(ctx);
                // Close the detail page too when the removal happened there.
                if (context.mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${cust.name} removed from the directory.'), backgroundColor: AppTheme.accentGreen),
                  );
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _showAllBillsDialog(BuildContext context, Customer cust, List<Bill> bills) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${cust.name} — Visit History', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))),
                            Text('${bills.length} total visits', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(PhosphorIconsBold.x), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: bills.isEmpty
                        ? const Center(child: Text('No visits recorded yet.', style: TextStyle(color: Color(0xFF64748B))))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: bills.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0)),
                            itemBuilder: (context, idx) {
                              final bill = bills[idx];
                              final itemNames = bill.items.map((i) => i.serviceName ?? i.productName ?? 'Service').where((s) => s.isNotEmpty).join(' + ');
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(color: const Color(0xFFEEF2F7), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(PhosphorIconsBold.receipt, color: Color(0xFF1E3A5F), size: 18),
                                ),
                                title: Text(_formatShortDate(bill.createdAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF0F172A))),
                                subtitle: Text('${bill.invoiceNumber}  ·  ${itemNames.isNotEmpty ? itemNames : 'No services listed'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                trailing: Text(formatInr(bill.finalAmount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                              );
                            },
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

  Widget _buildCustomerHeroCard(BuildContext context, WidgetRef ref, Customer cust, AppData state) {
    // customerBills is fetched once when the profile opens. A balance
    // collected afterwards (Clear Balance > Collect) patches the bill in
    // `state`, not that copy - so the strip below kept showing the old
    // amount owed until a reload. Prefer the live version of any bill the
    // snapshot also holds.
    final live = {for (final b in state.bills) b.id: b};
    final bills = customerBills?.map((b) => live[b.id] ?? b).toList();

    // Calculate dynamic stats
    final unpaid = (bills ?? const <Bill>[]).where((b) => !b.isFullyPaid).toList();
    final outstanding = unpaid.fold<double>(0.0, (acc, b) => acc + b.amountDue);
    final unpaidCount = unpaid.length;
    double totalSpent = cust.totalSpent;
    if (totalSpent <= 0 && bills != null && bills.isNotEmpty) {
      totalSpent = bills.fold<double>(0.0, (acc, b) => acc + b.finalAmount);
    }

    int visits = cust.visitCount;
    if (visits <= 0 && bills != null) {
      visits = bills.length;
    }

    String lastVisit = '-';
    if (cust.lastVisitAt != null) {
      lastVisit = _formatMonthDay(cust.lastVisitAt);
    } else if (bills != null && bills.isNotEmpty && bills.first.createdAt != null) {
      lastVisit = _formatMonthDay(bills.first.createdAt);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Name, VIP, Options
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.avatarColorsFor(cust.name).$1,
                child: Text(
                  _initials(cust.name),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.avatarColorsFor(cust.name).$2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cust.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cust.isVip) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2F7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '★ VIP',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cust.phone,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(PhosphorIconsBold.dotsThree, color: Color(0xFF94A3B8), size: 20),
                onPressed: () => _showCustomerOptions(context, ref, cust),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Action Buttons: Call, Message, New Bill
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callClient(context, cust),
                  icon: const Icon(PhosphorIconsRegular.phone, size: 14, color: Color(0xFF334155)),
                  label: FittedBox(fit: BoxFit.scaleDown, child: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _whatsappClient(context, cust),
                  icon: const Icon(PhosphorIconsRegular.whatsappLogo, size: 14, color: Color(0xFF16A34A)),
                  label: FittedBox(fit: BoxFit.scaleDown, child: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => startBill?.call(cust),
                  icon: const Icon(PhosphorIconsBold.receipt, size: 14, color: Colors.white),
                  label: FittedBox(fit: BoxFit.scaleDown, child: const Text('New bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Outstanding balance, when there is one. Derived from this
          // client's own unpaid bills rather than the denormalized
          // customers.outstandingBalance, so the strip agrees with the bill
          // list right below it even if the two ever drift apart.
          if (outstanding > 0) ...[
            // Tappable: this strip is where an owner notices a balance, so
            // it is also where settling it has to start. It opens DuesView
            // pre-searched to this client rather than duplicating the
            // record-a-payment flow, so there is still exactly one place
            // that writes a settlement.
            InkWell(
              onTap: () => openAppSubPage(
                context,
                title: 'Clear Balance',
                // No amount here: this header is fixed when the page opens,
                // so it kept saying "₹390 outstanding" after the balance was
                // collected. The page's own Total Outstanding card is live.
                subtitle: cust.name,
                child: DuesView(initialQuery: cust.name),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsFill.handCoins, size: 17, color: Color(0xFFB45309)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Outstanding balance',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                          ),
                          Text(
                            '$unpaidCount unpaid bill${unpaidCount == 1 ? '' : 's'} · tap to clear',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatInr(outstanding),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF78350F)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(PhosphorIconsBold.caretRight, size: 13, color: Color(0xFFB45309)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Row 3: 3 Stat KPI Boxes: Total Spent, Visits, Last Visit
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: PhosphorIconsFill.wallet,
                  iconBg: AppTheme.accentVioletBg,
                  iconColor: AppTheme.accentViolet,
                  label: 'Total spent',
                  value: formatInr(totalSpent),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: PhosphorIconsFill.calendarBlank,
                  iconBg: AppTheme.accentBlueBg,
                  iconColor: AppTheme.accentBlue,
                  label: 'Visits',
                  value: '$visits',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: PhosphorIconsFill.clock,
                  iconBg: AppTheme.accentOrangeBg,
                  iconColor: AppTheme.accentOrange,
                  label: 'Last visit',
                  value: lastVisit,
                ),
              ),
            ],
          ),

          // Provenance line. Who put this client on the books settles the
          // "where did this record come from" question without opening an
          // audit trail, and both fields are already on the loaded customer
          // document - no extra read to show them.
          if (cust.createdByName != null || cust.createdAt != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(PhosphorIconsRegular.userPlus, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _addedByLine(cust),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          // Birthday and WhatsApp consent, tappable to change - they're what
          // the automatic WhatsApp messages run on, so staff should see at a
          // glance whether this client will get them.
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _editBirthdayAndWhatsApp(context, ref, cust),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.cake, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    formatBirthday(cust.birthday) ?? 'Add birthday',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cust.birthday == null ? AppTheme.primaryBlue : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    PhosphorIconsRegular.whatsappLogo,
                    size: 13,
                    color: cust.whatsappOptIn ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      cust.whatsappOptIn ? 'WhatsApp OK' : 'No WhatsApp consent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cust.whatsappOptIn ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Row 4: Visit History Subsection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Visit History',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              InkWell(
                onTap: () => _showAllBillsDialog(context, cust, bills ?? []),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visit History Items
          if (loadingBills)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A5F)),
                ),
              ),
            )
          else if (bills == null || bills.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: const Center(
                child: Text(
                  'No previous visits recorded yet.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ...bills.take(3).map((bill) {
              final itemSummary = bill.items.map((i) => i.serviceName ?? i.productName ?? 'Service').where((s) => s.isNotEmpty).join(' + ');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7.0),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        PhosphorIconsBold.receipt,
                        color: Color(0xFF1E3A5F),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatShortDate(bill.createdAt),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          // Real items only - this used to fall back to a
                          // made-up "Haircut & Styling".
                          Text(
                            '${bill.invoiceNumber}  ·  ${itemSummary.isNotEmpty ? itemSummary : 'No services listed'}',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatInr(bill.finalAmount),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// --- EMPLOYEES TAB ---

class OwnerEmployeesTab extends StatefulWidget {
  final VoidCallback? onOpenNotifications;

  const OwnerEmployeesTab({super.key, this.onOpenNotifications});

  @override
  State<OwnerEmployeesTab> createState() => _OwnerEmployeesTabState();
}

class _OwnerEmployeesTabState extends State<OwnerEmployeesTab> with _EmployeeDetailSections {
  EmployeeProfile? _selectedEmployee;
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'All';
  // null = every branch. Staff are branch-scoped, so the roster needs a way
  // to answer "who works at this branch" - the branch name on each row was
  // the only hint before, with no way to narrow the list down to one.
  String? _branchFilterId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Staff *are* branch-scoped (unlike customers), so this always asks which
  // branch the new hire works at - it used to hide the picker whenever the
  // salon had a single branch, and with *zero* branches it hid the picker
  // and then rejected the form for having no branch, with no way out of the
  // dialog. Only open branches are assignable.
  void _openAddEmployee(BuildContext context, List<Branch> branches) {
    final assignable = branches.where((b) => b.active).toList();
    // Checked before pushing: with no branch to assign to, the form cannot be
    // completed, so it is better to say why than to open a dead page.
    if (assignable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(branches.isEmpty
              ? 'Add a branch first - every staff member works at one. See More > Branch Management.'
              : 'Every branch is deactivated. Reactivate one in More > Branch Management before adding staff.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    openAppSubPage(
      context,
      title: 'Add Staff',
      subtitle: 'Create their login and pay terms',
      child: AddEmployeePage(assignableBranches: assignable),
    );
  }

  // Roster rows deliberately carry only the name (plus a presence dot) -
  // everything else about the employee lives on the detail page this pushes.
  Widget _buildRosterNameRow(BuildContext context, AppData state, EmployeeProfile emp, int idx) {
    final status = _todayStatus(state, emp.id);
    final isPresent = status == 'PRESENT';
    final isLate = status == 'LATE';
    final (bg, fg) = AppTheme.avatarColorsFor(emp.name);

    return InkWell(
      onTap: () => _openEmployeeDetail(context, emp),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                _initials(emp.name),
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Role and today's state in words - the dot alone didn't
                  // say what grey meant.
                  Text(
                    '${emp.roleTitle.isEmpty ? 'Staff' : emp.roleTitle} · ${!emp.active ? 'Removed' : isPresent ? 'In today' : isLate ? 'Late today' : 'Not in yet'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isPresent
                    ? const Color(0xFF10B981)
                    : isLate
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(PhosphorIconsRegular.caretRight, size: 15, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _openEmployeeDetail(BuildContext context, EmployeeProfile emp) {
    // Keep the desktop master-detail pane in sync, so returning from the
    // pushed page (or switching to a wider window) lands on the same person.
    setState(() => _selectedEmployee = emp);
    pushAppRoute(
      context,
      OwnerEmployeeDetailPage(employeeId: emp.id),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppData state, bool isMobile) {
    if (isMobile) {
      return _buildMobileStaffView(context, ref, state);
    }
    return _buildDesktopStaffView(context, ref, state);
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder, not MediaQuery - see the comment in OwnerCustomersTab's
    // build() for why (the sidebar means MediaQuery's width overstates the
    // space this tab actually has).
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return Consumer(
          builder: (context, ref, child) {
            final asyncData = ref.watch(appDataProvider);
            return asyncData.when(
              loading: () => const AppLoadingView(),
              error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
              data: (state) {
                final team = state.employees.where((e) => e.active).toList();
                final present =
                    team.where((e) => _todayStatus(state, e.id) == 'PRESENT').length;
                return Container(
                  color: AppTheme.bgSurface,
                  child: Column(
                    children: [
                      AppPageHeader(
                        title: 'Team',
                        subtitle:
                            '${team.length} staff · $present in today',
                        actions: [
                          // Add, then the bell - Attendance and Payroll were
                          // behind a "Team settings" gear; they're buttons on
                          // the page now (see _buildBody), and discount
                          // requests are in the bell's inbox.
                          AppPageAction(
                            icon: PhosphorIconsBold.plus,
                            label: 'Add',
                            tooltip: 'Add staff',
                            onTap: () => _openAddEmployee(context, state.branches),
                          ),
                          AppPageAction(
                            icon: PhosphorIconsRegular.bell,
                            tooltip: 'Requests',
                            badgeCount: state.pendingPaymentRequestCount,
                            onTap: () => widget.onOpenNotifications?.call(),
                          ),
                        ],
                      ),
                      Expanded(child: _buildBody(context, ref, state, isMobile)),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// One filter chip. The count rides in a pill inside the chip rather than
  /// in brackets after the label: "All (4)" and "Present (0)" set at the same
  /// weight made the number look like part of the name, and a bare zero read
  /// as if the filter itself were broken.
  Widget _buildFilterChip(String label, String filterKey, {int? count}) {
    final isSelected = _activeFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFC3D0E2) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryBlue : const Color(0xFF64748B),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Branch scope, as a pill that opens a picker - the same control Home
  /// uses, so "which branch" means and looks the same on both screens.
  Widget _buildBranchSelectorPill(AppData state) {
    final selected = state.branches.where((b) => b.id == _branchFilterId);
    final label = selected.isNotEmpty ? selected.first.name : 'All branches';
    final shown = _branchFilterId == null
        ? state.employees.where((e) => e.active).length
        : state.employees.where((e) => e.active && e.branchId == _branchFilterId).length;

    return InkWell(
      onTap: () => _showBranchPicker(state),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsFill.mapPin, size: 14, color: Color(0xFF1E3A5F)),
            const SizedBox(width: 7),
            // Flexible, because this pill now shares its line with the Add
            // Staff button: a long branch name has to give way rather than
            // overflow the row.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$shown staff',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(PhosphorIconsBold.caretDown, size: 11, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _showBranchPicker(AppData state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget option(String label, String? branchId, int count) {
          final isSelected = _branchFilterId == branchId;
          return ListTile(
            leading: Icon(
              branchId == null ? PhosphorIconsRegular.buildings : PhosphorIconsRegular.storefront,
              size: 19,
              color: isSelected ? const Color(0xFF1E3A5F) : const Color(0xFF94A3B8),
            ),
            title: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              '$count staff',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
            trailing: isSelected
                ? const Icon(PhosphorIconsBold.check, size: 17, color: Color(0xFF1E3A5F))
                : null,
            onTap: () {
              setState(() => _branchFilterId = branchId);
              Navigator.pop(ctx);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  'Show staff from',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
              option('All branches', null, state.employees.where((e) => e.active).length),
              for (final b in state.branches)
                option(b.name, b.id, state.employees.where((e) => e.active && e.branchId == b.id).length),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileStaffView(BuildContext context, WidgetRef ref, AppData state) {
    // One pass for all four chip counts - the roster rebuilds on every
    // keystroke in the search box, so a separate .where().length per chip
    // walks the staff list four extra times per character.
    var presentCount = 0;
    var stylistCount = 0;
    var receptionCount = 0;
    // Removed staff (active: false - rules don't allow deleting an
    // employee) only show under the Removed chip, so they can be brought
    // back; every other count and chip is the current team.
    final team = <EmployeeProfile>[];
    final removed = <EmployeeProfile>[];
    for (final e in state.employees) {
      if (!e.active) {
        removed.add(e);
        continue;
      }
      team.add(e);
      if (_todayStatus(state, e.id) == 'PRESENT') presentCount++;
      final role = e.roleTitle.toLowerCase();
      if (role.contains('stylist')) stylistCount++;
      if (role.contains('reception')) receptionCount++;
    }
    // The last removed person was just brought back - don't strand the
    // list on an empty, chip-less filter.
    if (_activeFilter == 'Removed' && removed.isEmpty) _activeFilter = 'All';
    final showingRemoved = _activeFilter == 'Removed';

    final q = _searchController.text.toLowerCase().trim();
    final filteredEmployees = (showingRemoved ? removed : team).where((emp) {
      if (_branchFilterId != null && emp.branchId != _branchFilterId) {
        return false;
      }
      if (q.isNotEmpty && !emp.name.toLowerCase().contains(q) && !emp.roleTitle.toLowerCase().contains(q)) {
        return false;
      }
      if (showingRemoved) return true;
      if (_activeFilter == 'Present') {
        return _todayStatus(state, emp.id) == 'PRESENT';
      }
      if (_activeFilter != 'All' && !emp.roleTitle.toLowerCase().contains(_activeFilter.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12 + LiquidNavBar.barInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branch scope only when there is more than one branch.
          if (state.branches.length > 1) ...[
            _buildBranchSelectorPill(state),
            const SizedBox(height: 12),
          ],
          // Full-width search; Add is in the page header.
          TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Search name or role',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(PhosphorIconsRegular.xCircle, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
                    ),
                  ),
                ),
          const SizedBox(height: 12),

          // Attendance and Payroll are daily/monthly team jobs, so they're
          // on the page - they used to hide behind a "Team settings" gear.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openAppSubPage(
                    context,
                    title: 'Attendance',
                    subtitle: "Your shift, and today's roster",
                    child: const OwnerAttendanceTab(),
                  ),
                  icon: const Icon(PhosphorIconsRegular.calendarCheck, size: 17),
                  label: const Text('Attendance'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openAppSubPage(
                    context,
                    title: 'Payroll',
                    subtitle: 'Salary slips and commission payouts',
                    child: const OwnerPayrollView(),
                  ),
                  icon: const Icon(PhosphorIconsRegular.wallet, size: 17),
                  label: const Text('Payroll'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'All', count: team.length),
                const SizedBox(width: 8),
                _buildFilterChip('Present', 'Present', count: presentCount),
                const SizedBox(width: 8),
                _buildFilterChip('Stylists', 'Stylist', count: stylistCount),
                const SizedBox(width: 8),
                _buildFilterChip('Reception', 'Reception', count: receptionCount),
                if (removed.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip('Removed', 'Removed', count: removed.length),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 5. Staff list - tapping a row opens the full detail page.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                showingRemoved ? 'Removed staff' : 'All staff',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '${filteredEmployees.length} shown',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (filteredEmployees.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: const Text('No staff members found matching filter.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: AppTheme.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int idx = 0; idx < filteredEmployees.length; idx++) ...[
                    if (idx > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    _buildRosterNameRow(context, state, filteredEmployees[idx], idx),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 88), // clearance for floating navbar

        ],
      ),
    );
  }

  Widget _buildDesktopStaffView(BuildContext context, WidgetRef ref, AppData state) {
    final team = state.employees.where((e) => e.active).toList();
    final presentCount = team.where((e) => _todayStatus(state, e.id) == 'PRESENT').length;
    // Removed staff go last, marked as such, so they can still be opened
    // and brought back.
    final listed = [...team, ...state.employees.where((e) => !e.active)];

    final Widget listColumn = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Staff & Stylists',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.slateDark),
                ),
              ),
              IconButton(
                onPressed: () => _showGenerateSalaryDialog(context, ref),
                icon: const Icon(PhosphorIconsRegular.moneyWavy, color: AppTheme.primaryBlue),
                tooltip: 'Run Payroll for All Staff',
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddEmployee(context, state.branches),
                icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                label: const Text('Add Staff', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(0, 34)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Active on Shift: $presentCount / ${team.length}',
            style: const TextStyle(color: AppTheme.slateLight, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: listed.isEmpty
                ? const Center(child: Text('No employees yet.', style: TextStyle(color: AppTheme.slateLight)))
                : ListView.builder(
                    itemCount: listed.length,
                    itemBuilder: (context, idx) {
                      final emp = listed[idx];
                      final isSel = _selectedEmployee?.id == emp.id;
                      final status = emp.active ? _todayStatus(state, emp.id) : 'REMOVED';
                      Color statusColor = AppTheme.accentGreen;
                      if (status == 'LATE') statusColor = AppTheme.accentAmber;
                      if (status == 'ABSENT' || status == 'REMOVED') statusColor = AppTheme.slateLight;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryLight : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSel ? AppTheme.primaryBlue : AppTheme.borderSubtle, width: 1),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryLight,
                            child: Text(_initials(emp.name), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 12)),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  emp.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(status, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          subtitle: Text('${emp.roleTitle} • ${emp.email}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                          onTap: () => setState(() => _selectedEmployee = emp),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    return Row(
      children: [
        Expanded(flex: 1, child: listColumn),
        Expanded(
          flex: 1,
          child: AppPageSwitcher(
            child: _selectedEmployee == null
                ? const Center(
                    key: ValueKey('empty'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsRegular.identificationBadge, size: 56, color: AppTheme.slateLight),
                        SizedBox(height: 12),
                        Text('Select an employee to view details & metrics', style: TextStyle(color: AppTheme.slateMedium)),
                      ],
                    ),
                  )
                : Container(key: ValueKey('employee-${_selectedEmployee!.id}'), child: _buildEmployeeProfile(context, ref, state)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeProfile(BuildContext context, WidgetRef ref, AppData state) {
    final emp = state.employees.firstWhere((e) => e.id == _selectedEmployee!.id, orElse: () => _selectedEmployee!);

    final now = DateTime.now();
    final monthAttendance = state.attendance.where((a) => a.employeeId == emp.id && a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
    final presentDays = monthAttendance.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
    final attendancePct = monthAttendance.isEmpty ? 0.0 : (presentDays / monthAttendance.length) * 100;

    final activeTargets = state.salesTargets.where((t) => t.employeeId == emp.id && t.status == 'ACTIVE').toList();
    final target = activeTargets.isNotEmpty ? activeTargets.first : null;

    final pendingCommission = state.commissions
        .where((c) => c.employeeId == emp.id && c.status == 'PENDING')
        .fold<double>(0, (sum, c) => sum + c.amount);
    final projectedPayout = emp.baseSalary + pendingCommission;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primaryBlue,
                  child: Text(_initials(emp.name), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.slateDark)),
                      Text(emp.roleTitle, style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Phone: ${emp.phone}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                      Text('Email: ${emp.email}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                      if (emp.branchName != null) Text('Branch: ${emp.branchName}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditEmployeeDialog(context, ref, emp, state.branches),
                  icon: const Icon(PhosphorIconsRegular.pencilSimple, color: AppTheme.slateLight),
                  tooltip: 'Edit Employee',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildRemoveFromTeamButton(context, ref, emp),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sales Target', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark)),
                    TextButton.icon(
                      onPressed: () => _showSetSalesTargetDialog(context, ref, emp),
                      icon: const Icon(PhosphorIconsRegular.target, size: 15),
                      label: Text(target == null ? 'Set Target' : 'New Target', style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                    ),
                  ],
                ),
                if (target == null)
                  const Text('No active sales target set.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                else ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${target.type == 'SERVICE_VOLUME' ? 'Service Revenue' : 'Product Units'} target', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                      Text('${(target.progressFraction * 100).toStringAsFixed(0)}% Achieved', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: target.progressFraction, backgroundColor: const Color(0xFFE2E8F0), valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue), minHeight: 7),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Achieved: ${target.progressValue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                      Text('Target: ${target.targetValue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.slateLight, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Attendance (Month)', '${attendancePct.toStringAsFixed(0)}%', PhosphorIconsRegular.calendarBlank, AppTheme.accentGreen)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('Base Salary', formatInr(emp.baseSalary), PhosphorIconsRegular.money, AppTheme.slateDark)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Service Commission', '${emp.serviceCommissionPct.toStringAsFixed(0)}%', PhosphorIconsRegular.percent, AppTheme.primaryBlue)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('Product Commission', '${emp.productCommissionPct.toStringAsFixed(0)}%', PhosphorIconsRegular.percent, AppTheme.primaryBlue)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projected Payout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark)),
                    Text('Base salary + pending commission', style: TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                  ],
                ),
                Text(formatInr(projectedPayout), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.accentGreen)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPendingCommissionsCard(context, ref, state, emp),
          const SizedBox(height: 16),
          _buildSalaryHistoryCard(context, ref, state, emp),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showResetPasswordDialog(context, ref, emp),
              icon: const Icon(PhosphorIconsRegular.lockKey, size: 18, color: AppTheme.primaryBlue),
              label: const Text('Reset Employee Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
            ),
          ),
        ],
      ),
    );
  }

}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// Full-screen detail view for one staff member, pushed from the roster list.
// Keyed by id rather than by the EmployeeProfile object so an edit made from
// this page (or by anyone else) re-resolves against the live AppData snapshot
// instead of rendering a stale copy.
class OwnerEmployeeDetailPage extends StatefulWidget {
  final String employeeId;

  const OwnerEmployeeDetailPage({super.key, required this.employeeId});

  @override
  State<OwnerEmployeeDetailPage> createState() => _OwnerEmployeeDetailPageState();
}

class _OwnerEmployeeDetailPageState extends State<OwnerEmployeeDetailPage> with _EmployeeDetailSections {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: Consumer(
        builder: (context, ref, child) {
          final asyncData = ref.watch(appDataProvider);
          return asyncData.when(
            loading: () => const AppLoadingView(),
            error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
            data: (state) {
              final matches = state.employees.where((e) => e.id == widget.employeeId);
              if (matches.isEmpty) {
                return _buildMissing(context);
              }
              final emp = matches.first;
              final monthName = _monthNames[DateTime.now().month - 1];

              return SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, ref, state, emp),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSelectedStaffCard(context, ref, state, emp),
                            const SizedBox(height: 14),
                            _buildSalesTargetCard(context, ref, state, emp, monthName),
                            const SizedBox(height: 14),
                            _buildMetricsGrid(context, ref, state, emp),
                            const SizedBox(height: 14),
                            _buildPayrollEstimateCard(context, ref, state, emp, monthName),
                            const SizedBox(height: 14),
                            _buildPendingCommissionsCard(context, ref, state, emp),
                            const SizedBox(height: 14),
                            _buildSalaryHistoryCard(context, ref, state, emp),
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
      ),
    );
  }

  // The employee can disappear while this page is open (another owner
  // deletes them, or the snapshot reloads without them) - show that plainly
  // rather than popping the user out from under their own scroll position.
  Widget _buildMissing(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 20, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'This staff member is no longer on the roster.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    final status = _todayStatus(state, emp.id);
    final isPresent = status == 'PRESENT';
    final isLate = status == 'LATE';

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 20, color: Color(0xFF0F172A)),
            tooltip: 'Back to roster',
            onPressed: () => Navigator.of(context).pop(),
          ),
          // Just a title (plus today's status) - the card below already
          // shows the avatar, name and role, which used to appear twice.
          const Expanded(
            child: Text(
              'Staff',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.3),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPresent
                  ? const Color(0xFFECFDF5)
                  : isLate
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              // "Absent" only when someone was marked absent - before they
              // have clocked in (or been marked) it is just "Not in yet",
              // not an accusation at 10 in the morning.
              isPresent ? 'Present' : isLate ? 'Late' : status == 'ABSENT' ? 'Absent' : 'Not in yet',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isPresent
                    ? const Color(0xFF059669)
                    : isLate
                        ? const Color(0xFFD97706)
                        : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Every section of an employee's detail view. Shared by the desktop
// master-detail layout in OwnerEmployeesTab and by the pushed
// OwnerEmployeeDetailPage the mobile roster navigates to, so both render
// the same cards from the same code.
mixin _EmployeeDetailSections<T extends StatefulWidget> on State<T> {
  String _todayStatus(AppData state, String employeeId) {
    final today = DateTime.now();
    final match = state.attendance.where((a) => a.employeeId == employeeId && a.date != null && _isSameDay(a.date!, today));
    return match.isEmpty ? 'Absent' : match.first.status;
  }


  void _showResetPasswordDialog(BuildContext context, WidgetRef ref, EmployeeProfile emp) {
    // Firebase's client SDK can't set another user's password directly (no
    // Admin SDK, no server) - the owner can only trigger Firebase's own
    // reset-link email. See salon_auth.dart's sendPasswordResetEmail and
    // app_data_provider.dart's resetEmployeePassword.
    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.lockKey,
          title: 'Reset Password',
          child: Text(
            "This sends a password reset link to ${emp.email}. ${emp.name} will follow it to choose a new password themselves.",
            style: const TextStyle(fontSize: 14, color: AppTheme.slateMedium, height: 1.4),
          ),
          actions: AppDialogActions(
            submitLabel: 'Send Reset Email',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).resetEmployeePassword(emp.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password reset email sent to ${emp.email}.'), backgroundColor: AppTheme.accentGreen),
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

  void _showEditEmployeeDialog(BuildContext context, WidgetRef ref, EmployeeProfile emp, List<Branch> branches) {
    final nameController = TextEditingController(text: emp.name);
    final phoneController = TextEditingController(text: emp.phone);
    final roleController = TextEditingController(text: emp.roleTitle);
    final salaryController = TextEditingController(text: emp.baseSalary.toStringAsFixed(0));
    final serviceCommController = TextEditingController(text: emp.serviceCommissionPct.toStringAsFixed(0));
    final productCommController = TextEditingController(text: emp.productCommissionPct.toStringAsFixed(0));
    // Email isn't editable here - it's also the Firebase Auth login
    // identity, and there's no Admin SDK to rename that account to match
    // (same no-server constraint as resetEmployeePassword above).
    String? branchId = emp.branchId.isEmpty ? null : emp.branchId;
    // Only open branches are assignable, but the branch they're already on
    // stays listed even if it was deactivated - otherwise the dropdown would
    // show a blank value and any save would silently move them elsewhere.
    final assignable = [
      ...branches.where((b) => b.active),
      ...branches.where((b) => !b.active && b.id == emp.branchId),
    ];
    bool active = emp.active;
    // Firestore rules gate almost every write/read on isActiveEmployee()
    // (via myProfile().active) - if the owner flipped this off on their own
    // record, isOwner() would also go false on their next request, and only
    // an owner can flip it back. There's no server to catch that mistake
    // for them, so the toggle is disabled entirely on your own profile.
    final isSelf = ref.read(authControllerProvider).userId == emp.id;

    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.pencilSimple,
          title: 'Edit ${emp.name}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: appDialogFieldDecoration(label: 'Full Name *', icon: PhosphorIconsRegular.user)),
              const SizedBox(height: 12),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: appDialogFieldDecoration(label: 'Phone Number *', icon: PhosphorIconsRegular.phone)),
              const SizedBox(height: 12),
              TextField(controller: roleController, decoration: appDialogFieldDecoration(label: 'Stylist Role', icon: PhosphorIconsRegular.scissors)),
              const SizedBox(height: 12),
              if (assignable.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: branchId,
                    decoration: appDialogFieldDecoration(label: 'Branch *', icon: PhosphorIconsRegular.storefront),
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: Colors.white,
                    elevation: 3,
                    items: assignable
                        .map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.active ? b.name : '${b.name} (deactivated)'),
                            ))
                        .toList(),
                    onChanged: (val) => setDialogState(() => branchId = val),
                  ),
                ),
              TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Base salary (₹ per month)', icon: PhosphorIconsRegular.wallet)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: serviceCommController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Service Comm. (%)', icon: PhosphorIconsRegular.percent))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: productCommController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Product Comm. (%)', icon: PhosphorIconsRegular.percent))),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    isSelf ? "You can't deactivate your own account here - ask another owner, or use the Firebase Console." : 'Deactivated staff can no longer sign in or be billed against.',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: active,
                  onChanged: isSelf ? null : (val) => setDialogState(() => active = val),
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
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty || branchId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name, phone, and branch are required.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              final salary = double.tryParse(salaryController.text) ?? emp.baseSalary;
              final serviceComm = double.tryParse(serviceCommController.text) ?? emp.serviceCommissionPct;
              final productComm = double.tryParse(productCommController.text) ?? emp.productCommissionPct;

              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).updateEmployee(emp.id, {
                  'name': name,
                  'phone': phone,
                  'roleTitle': roleController.text.trim(),
                  'baseSalary': salary,
                  'serviceCommissionPct': serviceComm,
                  'productCommissionPct': productComm,
                  'branchId': branchId,
                  'active': active,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$name updated.'), backgroundColor: AppTheme.accentGreen),
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

  /// "Remove from team", or "Bring back" for someone already removed.
  /// Nothing on the owner's own profile - updateEmployee and the rules both
  /// refuse deactivating yourself (it would lock the salon out).
  Widget _buildRemoveFromTeamButton(BuildContext context, WidgetRef ref, EmployeeProfile emp) {
    if (ref.read(authControllerProvider).userId == emp.id) return const SizedBox.shrink();
    final removing = emp.active;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('removeFromTeam'),
        onPressed: () => _confirmRemoveFromTeam(context, ref, emp),
        icon: Icon(removing ? PhosphorIconsRegular.userMinus : PhosphorIconsRegular.arrowCounterClockwise, size: 16),
        label: Text(removing ? 'Remove from team' : 'Bring back to team'),
        style: OutlinedButton.styleFrom(
          foregroundColor: removing ? AppTheme.accentRed : AppTheme.primaryBlue,
          side: BorderSide(color: removing ? AppTheme.accentRedBg : AppTheme.borderStrong),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // Firestore blocks deleting an employee (firestore.rules) - their bills,
  // commissions, attendance and slips all point at employees/{uid}. Removing
  // sets active: false instead: they can't sign in (auth_provider.dart) and
  // drop out of the Team list and billing, and everything they did stays.
  void _confirmRemoveFromTeam(BuildContext context, WidgetRef ref, EmployeeProfile emp) {
    final removing = emp.active;
    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: removing ? PhosphorIconsRegular.userMinus : PhosphorIconsRegular.arrowCounterClockwise,
          iconColor: removing ? AppTheme.accentRed : null,
          iconBackground: removing ? AppTheme.accentRedBg : null,
          title: removing ? 'Remove ${emp.name}?' : 'Bring back ${emp.name}?',
          subtitle: removing
              ? 'They will no longer be able to sign in, and won\'t appear in the team or billing.'
              : 'They can sign in again with their old email and password.',
          child: Text(
            removing
                ? 'Their past bills, commissions, attendance and salary slips stay exactly as they are. '
                    'You can bring them back any time from Team > Removed.'
                : 'They go back on the team list and can be picked in billing again.',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.slateMedium, height: 1.4),
          ),
          actions: AppDialogActions(
            submitLabel: removing ? 'Remove' : 'Bring back',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).updateEmployee(emp.id, {'active': !removing});
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(removing ? '${emp.name} removed from the team.' : '${emp.name} is back on the team.'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  /// A date as a tappable field rather than a button: the label sits above
  /// the value instead of sharing a line with it, so neither is ever the one
  /// that gets truncated on a narrow screen.
  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsRegular.calendarBlank, size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetSalesTargetDialog(BuildContext context, WidgetRef ref, EmployeeProfile emp) {
    String type = 'SERVICE_VOLUME';
    final targetValueController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));

    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.target,
          title: 'Set Sales Target',
          subtitle: 'For ${emp.name}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: appDialogFieldDecoration(label: 'Target Type', icon: PhosphorIconsRegular.flag),
                items: const [
                  DropdownMenuItem(value: 'SERVICE_VOLUME', child: Text('Service Revenue (₹)')),
                  DropdownMenuItem(value: 'PRODUCT_SALES_COUNT', child: Text('Product Units Sold')),
                ],
                onChanged: (val) => setDialogState(() => type = val ?? type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetValueController,
                keyboardType: TextInputType.number,
                decoration: appDialogFieldDecoration(label: type == 'SERVICE_VOLUME' ? 'Target Revenue (₹) *' : 'Target Units *', icon: PhosphorIconsRegular.trendUp),
              ),
              const SizedBox(height: 12),
              // Two date fields, laid out by how much room there actually is.
              // Side-by-side OutlinedButtons reading "Start: 30 Sep 2026"
              // wrapped onto two lines inside the button on a phone, which is
              // what made this dialog look broken; below 320 logical pixels
              // of dialog width they stack instead.
              LayoutBuilder(
                builder: (context, constraints) {
                  final startField = _dateField(
                    label: 'Start',
                    value: _formatDate(startDate),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      setDialogState(() {
                        startDate = picked;
                        // Keeps the range valid without a second error
                        // message: moving the start past the end drags the
                        // end along rather than leaving an impossible window.
                        if (!endDate.isAfter(startDate)) {
                          endDate = startDate.add(const Duration(days: 30));
                        }
                      });
                    },
                  );
                  final endField = _dateField(
                    label: 'End',
                    value: _formatDate(endDate),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: endDate.isAfter(startDate) ? endDate : startDate,
                        firstDate: startDate,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => endDate = picked);
                    },
                  );

                  if (constraints.maxWidth < 320) {
                    return Column(
                      children: [
                        startField,
                        const SizedBox(height: 10),
                        endField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: startField),
                      const SizedBox(width: 10),
                      Expanded(child: endField),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Set Target',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final targetValue = double.tryParse(targetValueController.text);
              if (targetValue == null || targetValue <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid target value.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).addSalesTarget(
                      employeeId: emp.id,
                      type: type,
                      targetValue: targetValue,
                      startDate: startDate.toIso8601String(),
                      endDate: endDate.toIso8601String(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Target set for ${emp.name}.'), backgroundColor: AppTheme.accentGreen),
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


  // forEmployee == null runs payroll for every active employee at once
  // (AppDataNotifier.generateSalary / SalonFirestore.generateSalary already
  // skip anyone already PAID for the chosen month, so rerunning this is
  // always safe).
  void _showGenerateSalaryDialog(BuildContext context, WidgetRef ref, {EmployeeProfile? forEmployee}) {
    final now = DateTime.now();
    int month = now.month;
    int year = now.year;

    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.moneyWavy,
          title: forEmployee == null ? 'Run Payroll for All Staff' : 'Generate Salary',
          subtitle: forEmployee == null ? null : forEmployee.name,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sums pending commissions and late-attendance deductions for the chosen month into a draft salary record${forEmployee == null ? ' for every active employee' : ''}.',
                style: const TextStyle(color: AppTheme.slateLight, fontSize: 12),
              ),
              const SizedBox(height: 16),
              // Replaces two DropdownButtonFormFields that sat side by side.
              // They overflowed the dialog by 18px once a long month name was
              // selected, and each opened a full-height menu across the whole
              // screen to choose from twelve items - for a choice that fits
              // inside the dialog itself.
              PayPeriodPicker(
                month: month,
                year: year,
                now: now,
                onChanged: (m, y) => setDialogState(() {
                  month = m;
                  year = y;
                }),
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Generate',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).generateSalary(month: month, year: year, employeeId: forEmployee?.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Salary generated for ${_monthNames[month - 1]} $year.'), backgroundColor: AppTheme.accentGreen),
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

  Widget _buildSelectedStaffCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE4EF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(emp.name),
                  style: const TextStyle(
                    color: Color(0xFF2F4E79),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            emp.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          PhosphorIconsFill.checkCircle,
                          size: 16,
                          color: Color(0xFF2F4E79),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE4EF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        emp.roleTitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2F4E79),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      // Real data only - this used to fall back to a made-up
                      // "Chair #01 • Tier 1 Master" for anyone without a
                      // branch, the owner included.
                      emp.branchName != null
                          ? 'Branch: ${emp.branchName}'
                          : (emp.roleTitle == 'Owner' ? 'All branches' : 'No branch assigned'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3 Action Buttons: Call, Schedule, Edit
          Row(
            children: [
              Expanded(
                child: _buildStaffActionButton(
                  icon: PhosphorIconsRegular.phone,
                  label: 'Call',
                  // A real call (tel: link) - this only showed a "Calling..."
                  // snackbar before.
                  onTap: () {
                    final number = emp.phone.replaceAll(RegExp(r'[^\d+]'), '');
                    if (number.isEmpty || !openLink('tel:$number')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not start a call to ${emp.phone}.'), backgroundColor: AppTheme.accentRed),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStaffActionButton(
                  icon: PhosphorIconsRegular.calendarBlank,
                  label: 'Schedule',
                  onTap: () => _showScheduleSheet(context, emp, state),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStaffActionButton(
                  icon: PhosphorIconsRegular.pencilSimple,
                  label: 'Edit',
                  onTap: () => _showEditEmployeeDialog(context, ref, emp, state.branches),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // Contact Info Rows
          _buildStaffInfoRow(PhosphorIconsRegular.phone, 'Phone', emp.phone),
          const SizedBox(height: 8),
          _buildStaffInfoRow(PhosphorIconsRegular.envelopeSimple, 'Email', emp.email),
          const SizedBox(height: 8),
          _buildStaffInfoRow(PhosphorIconsRegular.userCircle, 'Status', emp.active ? 'Active' : 'Removed'),
          const SizedBox(height: 14),
          _buildRemoveFromTeamButton(context, ref, emp),
        ],
      ),
    );
  }

  Widget _buildStaffActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF475467)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTargetCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp, String monthName) {
    final activeTargets = state.salesTargets.where((t) => t.employeeId == emp.id && t.status == 'ACTIVE').toList();
    final target = activeTargets.isNotEmpty ? activeTargets.first : null;

    // No fabricated numbers when there's no real target - this used to
    // invent a fake "achieved" figure from the employee's salary and a fake
    // ₹1,80,000 goal, which showed the owner a made-up performance number
    // with nothing behind it. Show an honest empty state instead.
    if (target == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                PhosphorIconsRegular.trendUp,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No active sales target set',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$monthName progress will show here once one is set.',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _showSetSalesTargetDialog(context, ref, emp),
              child: const Text('Set Target'),
            ),
          ],
        ),
      );
    }

    final targetAchieved = target.progressValue;
    final targetGoal = target.targetValue > 0 ? target.targetValue : 1.0;
    final targetPct = target.progressFraction;
    final toTarget = (targetGoal - targetAchieved).clamp(0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE4EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  PhosphorIconsRegular.trendUp,
                  color: Color(0xFF2F4E79),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$monthName Sales Target',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE4EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(targetPct * 100).toInt()}% Goal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Color(0xFF2F4E79),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatInr(targetAchieved),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'of ${formatInr(targetGoal)} goal',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: targetPct.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFFEEF2F7),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2F4E79)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                targetPct >= 1.0 ? 'Target reached' : 'In progress',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE4EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${formatInr(toTarget)} to target',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F4E79),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    final now = DateTime.now();
    final monthAttendance = state.attendance.where((a) => a.employeeId == emp.id && a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
    final presentDays = monthAttendance.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
    final attendancePct = monthAttendance.isEmpty ? 0.0 : (presentDays / monthAttendance.length) * 100;

    // One card of four compact tiles, like Home's figures. It was a grid of
    // fixed-ratio cards each with its own badge ("This Month", "Fixed",
    // "0% Tier") - noisy, and the fixed ratio overflowed on phone widths.
    const vDivider = VerticalDivider(width: 1, thickness: 1, color: AppTheme.borderSubtle);
    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DsStatTile(
                    icon: PhosphorIconsRegular.calendarCheck,
                    tint: AppTheme.accentBlue,
                    tintBg: AppTheme.accentBlueBg,
                    label: 'Attendance',
                    value: '${attendancePct.toInt()}%',
                  ),
                ),
                vDivider,
                Expanded(
                  child: DsStatTile(
                    icon: PhosphorIconsRegular.money,
                    tint: AppTheme.accentViolet,
                    tintBg: AppTheme.accentVioletBg,
                    label: 'Base salary',
                    value: formatInr(emp.baseSalary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DsStatTile(
                    icon: PhosphorIconsRegular.scissors,
                    tint: AppTheme.accentOrange,
                    tintBg: AppTheme.accentOrangeBg,
                    label: 'On services',
                    value: '${emp.serviceCommissionPct.toInt()}%',
                  ),
                ),
                vDivider,
                Expanded(
                  child: DsStatTile(
                    icon: PhosphorIconsRegular.tote,
                    tint: AppTheme.accentRose,
                    tintBg: AppTheme.accentRoseBg,
                    label: 'On products',
                    value: '${emp.productCommissionPct.toInt()}%',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollEstimateCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp, String monthName) {
    // Shared with the employee's own Earnings screen (AppData.
    // pendingCommissionFor) so both render the same figures. This used to be
    // a fabricated 85/15 split of the pending total, falling back to
    // baseSalary * pct * 2.5 (services) and * 1.2 (retail) when nothing was
    // pending - magic multipliers with no data behind them, on the screen the
    // owner uses to decide what to pay someone.
    final split = state.pendingCommissionFor(emp.id);
    final pendingCommissionTotal = split.total;
    final serviceComm = split.service;
    final productComm = split.product;
    final unattributedComm = split.unattributed;

    // Once this month's slip is generated, its commissions are settled (moved
    // to PAID), so base + pending alone dropped back to the bare base salary
    // - the card read ₹25,000 right after a ₹25,120 slip was made. When the
    // slip exists, it is the payout; anything still pending was earned after
    // it and is added on top.
    final now = DateTime.now();
    final slip = (ref.watch(salaryRecordsProvider).valueOrNull ?? const <SalaryRecord>[])
        .where((r) => r.employeeId == emp.id && r.month == now.month && r.year == now.year)
        .firstOrNull;
    final projectedPayout = slip != null ? slip.totalPaid + pendingCommissionTotal : emp.baseSalary + pendingCommissionTotal;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$monthName pay",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentVioletBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  PhosphorIconsRegular.receipt,
                  color: AppTheme.accentViolet,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatInr(projectedPayout),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A5F),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                slip == null ? 'so far this month' : (slip.status == 'PAID' ? 'slip paid' : 'slip made'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          const SizedBox(height: 10),
          if (slip != null) ...[
            _buildPayrollBreakdownRow(
              '${monthName.substring(0, 3)} slip (base + commission - deductions)',
              formatInr(slip.totalPaid),
            ),
            const SizedBox(height: 6),
            _buildPayrollBreakdownRow(
              'Service Commission since slip (${emp.serviceCommissionPct.toInt()}%)',
              '+ ${formatInr(serviceComm)}',
            ),
            const SizedBox(height: 6),
            _buildPayrollBreakdownRow(
              'Product Commission since slip (${emp.productCommissionPct.toInt()}%)',
              '+ ${formatInr(productComm)}',
            ),
          ] else ...[
            _buildPayrollBreakdownRow('Base salary', formatInr(emp.baseSalary)),
            const SizedBox(height: 6),
            _buildPayrollBreakdownRow(
              'Commission on services (${emp.serviceCommissionPct.toInt()}%)',
              '+ ${formatInr(serviceComm)}',
            ),
            const SizedBox(height: 6),
            _buildPayrollBreakdownRow(
              'Commission on products (${emp.productCommissionPct.toInt()}%)',
              '+ ${formatInr(productComm)}',
            ),
          ],
          if (unattributedComm.abs() >= 1) ...[
            const SizedBox(height: 6),
            _buildPayrollBreakdownRow(
              'Other pending commission',
              '+ ${formatInr(unattributedComm)}',
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _showDetailedSlipSheet(context, ref, state, emp),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'See full breakdown',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 6),
                  Icon(PhosphorIconsBold.arrowRight, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollBreakdownRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475467),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _showScheduleSheet(BuildContext context, EmployeeProfile emp, AppData state) {
    final recentAttendance = state.attendance.where((a) => a.employeeId == emp.id && a.date != null).toList()
      ..sort(compareAttendanceNewestFirst);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${emp.name}\'s Schedule & Attendance',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Most recent days, newest first',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                if (recentAttendance.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No attendance records logged yet.', style: TextStyle(color: Color(0xFF94A3B8)))),
                  )
                else
                  SizedBox(
                    height: 240,
                    child: ListView.separated(
                      itemCount: recentAttendance.length > 8 ? 8 : recentAttendance.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final rec = recentAttendance[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_formatDate(rec.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          // The day's real clock times. This used to read
                          // "Shift: Morning & Evening" on every row whatever
                          // had happened.
                          subtitle: Text(
                            punchTimesLabel(rec) ?? 'Marked on the roster',
                            style: TextStyle(
                              fontSize: 11,
                              color: (punchTimesLabel(rec) ?? '').endsWith('no clock-out')
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: rec.status == 'PRESENT'
                                  ? const Color(0xFFECFDF5)
                                  : rec.status == 'LATE'
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              attendanceStatusLabel(rec.status),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: rec.status == 'PRESENT'
                                    ? const Color(0xFF059669)
                                    : rec.status == 'LATE'
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF64748B),
                              ),
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
      },
    );
  }

  void _showDetailedSlipSheet(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${emp.name} • Payroll Slip',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Salary records and pending commission breakdown',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showGenerateSalaryDialog(context, ref, forEmployee: emp);
                        },
                        icon: const Icon(PhosphorIconsRegular.calendarPlus, color: Color(0xFF2F4E79)),
                        tooltip: 'Generate Salary',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPendingCommissionsCard(context, ref, state, emp),
                  const SizedBox(height: 16),
                  _buildSalaryHistoryCard(context, ref, state, emp),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingCommissionsCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    // Zero-amount commissions (staff on 0% - the owner, usually) are left
    // out: a list of "Rs. 0  Mark Paid" rows was all noise and no money.
    final pending = state.commissions.where((c) => c.employeeId == emp.id && c.status == 'PENDING' && c.amount > 0).toList()
      ..sort((a, b) => (b.calculatedAt ?? DateTime(0)).compareTo(a.calculatedAt ?? DateTime(0)));

    Future<void> markPaid(String id) async {
      try {
        await ref.read(appDataProvider.notifier).markCommissionPaid(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
        }
      }
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pending Commissions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark)),
          const SizedBox(height: 4),
          const Text('Paid off automatically the next time payroll runs for the covering month, or mark one individually below.', style: TextStyle(color: AppTheme.slateLight, fontSize: 11)),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            const Text('No pending commissions.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pending.length > 20 ? 20 : pending.length,
              itemBuilder: (context, idx) {
                final c = pending[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDate(c.calculatedAt), style: const TextStyle(fontSize: 11, color: AppTheme.slateLight)),
                      Row(
                        children: [
                          Text(formatInr(c.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 26,
                            child: TextButton(
                              onPressed: () => markPaid(c.id),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 26)),
                              child: const Text('Mark Paid', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSalaryHistoryCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    // Loaded with this card rather than at sign-in; an empty history while
    // it arrives is the same thing the card shows for a new employee.
    final records = (ref.watch(salaryRecordsProvider).valueOrNull ?? const <SalaryRecord>[])
        .where((r) => r.employeeId == emp.id)
        .toList()
      ..sort((a, b) => (b.year * 12 + b.month).compareTo(a.year * 12 + a.month));

    Future<void> markPaid(String id) async {
      try {
        await ref.read(salaryRecordsProvider.notifier).markPaid(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
        }
      }
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Salary History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark)),
              TextButton.icon(
                onPressed: () => _showGenerateSalaryDialog(context, ref, forEmployee: emp),
                icon: const Icon(PhosphorIconsRegular.calendarPlus, size: 15),
                label: const Text('Generate', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Text('No slips yet - tap Generate to make one.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              itemBuilder: (context, idx) {
                final r = records[idx];
                final isPaid = r.status == 'PAID';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.borderSubtle)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_monthNames[r.month - 1]} ${r.year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            Text('Base ${formatInr(r.baseSalary)} + Commission ${formatInr(r.commissionEarned)} - Deductions ${formatInr(r.deductions)}',
                                style: const TextStyle(color: AppTheme.slateLight, fontSize: 10)),
                          ],
                        ),
                      ),
                      Text(formatInr(r.totalPaid), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 10),
                      if (isPaid)
                        const Icon(PhosphorIconsRegular.checkCircle, color: AppTheme.accentGreen, size: 20)
                      else
                        SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () => markPaid(r.id),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 28)),
                            child: const Text('Mark Paid', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(val, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: color), overflow: TextOverflow.ellipsis, maxLines: 1),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: AppTheme.slateLight, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ),
    );
  }
}

// --- ATTENDANCE TAB ---



/// The day from [d] and the time from [clockIn]. A record's `date` is always
/// stored as local midnight, so formatting its time - as this used to - put
/// "12:00 AM In" on every row. A day marked on the roster with no punch has
/// no clock-in time at all, and shows none.
String _formatRosterDate(DateTime? d, DateTime? clockIn) {
  if (d == null) return '-';
  final now = DateTime.now();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String timeStr = '';
  if (clockIn != null) {
    final hour = clockIn.hour > 12 ? clockIn.hour - 12 : (clockIn.hour == 0 ? 12 : clockIn.hour);
    final minute = clockIn.minute.toString().padLeft(2, '0');
    final period = clockIn.hour >= 12 ? 'PM' : 'AM';
    timeStr = ' • $hour:$minute $period In';
  }

  if (now.year == d.year && now.month == d.month && now.day == d.day) {
    return 'Today, ${d.day} ${months[d.month - 1]}$timeStr';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (yesterday.year == d.year && yesterday.month == d.month && yesterday.day == d.day) {
    return 'Yesterday, ${d.day} ${months[d.month - 1]}$timeStr';
  }
  return '${d.day} ${months[d.month - 1]} ${d.year}$timeStr';
}

class OwnerAttendanceTab extends StatefulWidget {
  final VoidCallback? onOpenNotifications;

  const OwnerAttendanceTab({super.key, this.onOpenNotifications});

  @override
  State<OwnerAttendanceTab> createState() => _OwnerAttendanceTabState();
}

class _OwnerAttendanceTabState extends State<OwnerAttendanceTab> {
  // Unsaved edits only - the letters the owner has tapped but not yet
  // confirmed. Cleared per employee the moment that row is written, so
  // AppData goes back to being the only thing this screen reads from.
  //
  // It used to be a plain local mirror that was never cleared, which made it
  // win over the provider forever: once a row had been tapped, a later
  // clock-in (or a refresh, or the same staff member being marked from
  // another device) patched AppData.attendance correctly and this screen
  // carried on showing the stale letter. A failed save was worse - the
  // roster kept rendering every edit as though it had been written.
  final Map<String, String> _pendingRosterEdits = {};
  bool _submittingRoster = false;
  // Separate from _submittingRoster: punching your own shift and confirming
  // everyone's roster are different writes, and one being in flight should
  // not grey out the other.
  bool _submittingOwnPunch = false;

  /// The owner's own current shift - still open (even since yesterday
  /// evening), else today's record - or null if they have not punched.
  ///
  /// An owner is an employees/{uid} document like anyone else, so this is the
  /// same lookup a stylist's clock card does (attendance_shift.dart).
  AttendanceRecord? _ownRecordToday(AppData state, String? userId, DateTime now) {
    if (userId == null) return null;
    return currentShiftRecord(state.attendance, userId, now);
  }

  Future<void> _punch(WidgetRef ref, {required bool out}) async {
    setState(() => _submittingOwnPunch = true);
    try {
      final notifier = ref.read(appDataProvider.notifier);
      if (out) {
        await notifier.clockOut();
      } else {
        await notifier.clockIn();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(out ? 'Clocked out.' : 'Clocked in.'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed),
      );
    } finally {
      if (mounted) setState(() => _submittingOwnPunch = false);
    }
  }

  String _statusFor(AppData state, String employeeId) {
    // An unsaved edit shows through, because that's what the owner is
    // looking at while they work; anything already saved reads from AppData.
    final pending = _pendingRosterEdits[employeeId];
    if (pending != null) return pending;
    final today = DateTime.now();
    final match = state.attendance.where((a) => a.employeeId == employeeId && a.date != null && _isSameDay(a.date!, today));
    // '' = not marked yet. This used to read as ABSENT, so every unmarked
    // row showed a red "Absent" and confirming the roster wrote it - the
    // owner could mark the whole team absent at 9am with one tap.
    return match.isEmpty ? '' : match.first.status;
  }

  /// Writes today's roster, then drops the draft for every row that landed.
  ///
  /// Each row is its own doc ("{employeeId}_{date}"), so they're independent:
  /// one failing shouldn't abandon the rest, and the ones that succeeded
  /// shouldn't stay queued as unsaved edits. Issued together rather than in
  /// sequence - this used to await one write per employee back to back, so a
  /// 15-person salon paid 15 serial round trips (and 15 full rebuilds, one
  /// per _patchAttendance) before the button released.
  Future<void> _confirmRoster(WidgetRef ref, AppData state) async {
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    // Read the statuses before any await, so what gets written is what was
    // on screen when the button was tapped.
    // Only the rows the owner actually set on this screen - nobody is marked
    // anything they weren't explicitly given.
    final roster = Map<String, String>.of(_pendingRosterEdits);
    if (roster.isEmpty) return;
    final notifier = ref.read(appDataProvider.notifier);

    setState(() => _submittingRoster = true);

    final failures = <String, Object>{};
    await Future.wait(roster.entries.map((entry) async {
      try {
        await notifier.markAttendance(employeeId: entry.key, date: dateStr, status: entry.value);
      } catch (e) {
        failures[entry.key] = e;
      }
    }));

    if (!mounted) return;
    setState(() {
      _submittingRoster = false;
      // Everything that saved is in AppData now, so its draft goes away and
      // _statusFor reads the real record again. Rows that failed stay queued
      // so the owner still sees what they entered and can retry it.
      _pendingRosterEdits.removeWhere(
        (empId, _) => roster.containsKey(empId) && !failures.containsKey(empId),
      );
    });

    final messenger = ScaffoldMessenger.of(context);
    if (failures.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Attendance saved'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    // Named, not counted: "3 rows failed" with no idea which three is not
    // something the owner can act on.
    final names = failures.keys.map((id) => state.employeeById(id)?.name ?? 'Unknown').join(', ');
    messenger.showSnackBar(SnackBar(
      content: Text('Could not save $names: ${failures.values.first}'),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
  }

  void _showAllHistoryModal(BuildContext context, List<AttendanceRecord> records, AppData state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Attendance History Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  Expanded(
                    // Read live rather than from the list handed in, so
                    // "Load older days" at the bottom grows this sheet.
                    child: Consumer(
                      builder: (context, ref, _) {
                        final live = ref.watch(appDataProvider).valueOrNull ?? state;
                        final all = [...live.attendance]..sort(compareAttendanceNewestFirst);
                        if (all.isEmpty) {
                          return const Center(child: Text('No attendance history recorded.', style: TextStyle(color: Color(0xFF64748B))));
                        }
                        return ListView.separated(
                          controller: scrollCtrl,
                          itemCount: all.length + 1,
                          separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, idx) {
                            if (idx == all.length) return const LoadOlderAttendance();
                            final rec = all[idx];
                            final emp = live.employeeById(rec.employeeId);
                            return _buildLogTile(rec, emp, branches: live.branches);
                          },
                        );
                      },
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

  Widget _buildLogTile(AttendanceRecord rec, EmployeeProfile? emp, {List<Branch> branches = const []}) {
    Color dotColor = const Color(0xFF10B981);
    Color badgeBg = const Color(0xFFECFDF5);
    Color badgeFg = const Color(0xFF059669);

    if (rec.status == 'LATE') {
      dotColor = const Color(0xFFF59E0B);
      badgeBg = const Color(0xFFFFFBEB);
      badgeFg = const Color(0xFFD97706);
    } else if (rec.status == 'ABSENT') {
      dotColor = const Color(0xFFEF4444);
      badgeBg = const Color(0xFFFEF2F2);
      badgeFg = const Color(0xFFDC2626);
    } else if (rec.status == 'LEAVE') {
      dotColor = const Color(0xFFF97316);
      badgeBg = const Color(0xFFFFFBEB);
      badgeFg = const Color(0xFFEA580C);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp?.name ?? 'Staff Member',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Flexible, not a bare Text: "Yesterday, 26 Sep - 10:05
                    // AM In" plus the chip overruns the row on a phone.
                    Flexible(
                      child: Text(
                        _formatRosterDate(rec.date, null),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                    // A day nobody has vouched for. Staff punch for
                    // themselves, so an unconfirmed row is a claim, not a
                    // fact - and payroll will not deduct for an unconfirmed
                    // LATE. Saying so here is the whole point: confirmation
                    // that is invisible never gets done.
                    if (!rec.confirmed) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Unconfirmed',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // In, out and hours - or "on shift" / "no clock-out". A
                // forgotten clock-out is amber so it stands out in the log.
                if (punchTimesLabel(rec) case final times?) ...[
                  const SizedBox(height: 2),
                  Text(
                    times,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: times.endsWith('no clock-out') ? const Color(0xFFD97706) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              attendanceStatusLabel(rec.status),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeFg, letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // Name on top, the three status buttons full-width underneath: side by
  // side, the buttons squeezed the name down to "A..." on a phone, so the
  // owner couldn't see whom they were marking.
  Widget _buildStaffRosterRow(EmployeeProfile emp, int index, String currentStatus) {
    final (bg, fg) = AppTheme.avatarColorsFor(emp.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    _initials(emp.name),
                    style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      emp.roleTitle.isNotEmpty ? emp.roleTitle : 'Staff',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _buildStatusCircle(emp.id, 'Present', 'PRESENT', currentStatus == 'PRESENT', AppTheme.accentGreen)),
                const SizedBox(width: 3),
                Expanded(child: _buildStatusCircle(emp.id, 'Late', 'LATE', currentStatus == 'LATE', AppTheme.accentAmber)),
                const SizedBox(width: 3),
                Expanded(child: _buildStatusCircle(emp.id, 'Absent', 'ABSENT', currentStatus == 'ABSENT', AppTheme.accentRed)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCircle(String empId, String letter, String statusKey, bool isSelected, Color activeColor) {
    return InkWell(
      onTap: () {
        setState(() {
          _pendingRosterEdits[empId] = statusKey;
        });
      },
      borderRadius: BorderRadius.circular(15),
      // Whole words, not P / L / A - single letters meant nothing to a new
      // receptionist marking the roster for the first time.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
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
          data: (state) => _buildContent(context, ref, state),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AppData state) {
    // Removed staff (active: false) are off the roster - see
    // _confirmRemoveFromTeam.
    final staff = state.employees.where((e) => e.active).toList();
    final isMobile = MediaQuery.of(context).size.width < 768;

    int presentCount = 0;
    for (final emp in staff) {
      final s = _statusFor(state, emp.id);
      if (s == 'PRESENT' || s == 'LATE') presentCount++;
    }

    final today = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final todayFormatted = 'Today, ${today.day} ${months[today.month - 1]}';

    final recentAttendance = [...state.attendance]..sort(compareAttendanceNewestFirst);

    return Container(
      color: const Color(0xFFF8F9FC),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // (A calendar button sat here. It only showed a "Date set
                // to today" snackbar - there's no picking another day - so
                // it's gone; the roster card below says which day it is.)
                // The owner's own shift, above the roster they mark for
                // everyone else. They already appear in that roster and can
                // be given a status letter there, but a letter records no
                // hours - so an owner who worked a full day had no clock-in
                // time anywhere in the app while every stylist did.
                OwnerShiftCard(
                  today: _ownRecordToday(
                    state,
                    ref.read(authControllerProvider).userId,
                    today,
                  ),
                  submitting: _submittingOwnPunch,
                  now: today,
                  onClockIn: () => _punch(ref, out: false),
                  onClockOut: () => _punch(ref, out: true),
                ),
                const SizedBox(height: 12),
                // Staff punch only by scanning this (firestore.rules), so
                // it sits right here rather than behind a menu.
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AttendanceQrPage()),
                    ),
                    icon: const Icon(PhosphorIconsRegular.qrCode, size: 18),
                    label: const Text('Show attendance QR for staff'),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Date & Quick Action Status Pills Row
                Row(
                  children: [
                    // Status Pill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            // Just the count - the date was squeezed to
                            // "Today, ..." beside it on a phone.
                            Flexible(
                              child: Text(
                                '$presentCount of ${staff.length} in today',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Mark All Present Pill
                    InkWell(
                      onTap: () {
                        setState(() {
                          for (final emp in staff) {
                            _pendingRosterEdits[emp.id] = 'PRESENT';
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Everyone marked Present - tap Save attendance to keep it.'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2F7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDCE4EF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(PhosphorIconsBold.check, size: 13, color: Color(0xFF1E3A5F)),
                            SizedBox(width: 5),
                            Text(
                              'All present',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A5F)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 4. Card 1: Mark Roster Today
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Today's date under the title - the old subtitle
                          // was a hardcoded "Shift: Morning & Evening" and a
                          // "Live" pill that meant nothing.
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Today's roster",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                todayFormatted,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Staff Roster Items
                      if (staff.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: Text('No employees found in system.', style: TextStyle(color: Color(0xFF64748B)))),
                        )
                      else
                        ...staff.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final emp = entry.value;
                          final status = _statusFor(state, emp.id);
                          return _buildStaffRosterRow(emp, idx, status);
                        }),

                      const SizedBox(height: 8),

                      // Confirm Daily Roster Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _pendingRosterEdits.isEmpty ? AppTheme.borderSubtle : AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: _submittingRoster || _pendingRosterEdits.isEmpty
                                ? null
                                : () => _confirmRoster(ref, state),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _submittingRoster
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(PhosphorIconsBold.checkCircle, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _pendingRosterEdits.isEmpty
                                            ? 'Mark staff above to save'
                                            : 'Save attendance (${_pendingRosterEdits.length})',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Card 2: Recent Attendance Log
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Expanded + ellipsis: the title and "View History"
                          // overflowed the card on a phone-width screen.
                          Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2F7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  PhosphorIconsBold.clockCounterClockwise,
                                  color: Color(0xFF1E3A5F),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                'Recent attendance',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              ),
                            ],
                          ),
                          ),
                          InkWell(
                            onTap: () => _showAllHistoryModal(context, recentAttendance, state),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(
                                'View all',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // List of Logs
                      if (recentAttendance.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text('No attendance records logged yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          ),
                        )
                      else
                        ...recentAttendance.take(5).map((rec) {
                          final emp = state.employeeById(rec.employeeId);
                          return _buildLogTile(rec, emp, branches: state.branches);
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

