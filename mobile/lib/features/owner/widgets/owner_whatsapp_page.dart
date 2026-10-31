import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data_provider.dart';
import '../../../data/insights_provider.dart';
import '../../../data/models.dart';
import '../../../data/money.dart';
import '../../../data/whatsapp_tasks.dart';
import '../../../theme.dart';
import '../../../widgets/app_sub_page.dart';
import '../../../widgets/ds.dart';
import 'insight_charts.dart';
import 'owner_whatsapp_settings.dart';

/// Menu > WhatsApp: the owner's control room for the automatic messages.
///
/// One switch for all of it, then each message as a job of its own - when
/// it goes, how many went this month - opening onto that job's page with
/// its settings, its months and its recent sends. The sending itself is
/// done by the Cloud Functions (functions/index.js), which read the same
/// settings/main fields this page writes.
class OwnerWhatsAppPage extends ConsumerWidget {
  const OwnerWhatsAppPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider).valueOrNull;
    final settings = data?.settings;
    if (data == null || settings == null) return const Center(child: CircularProgressIndicator());

    return _PageColumn(
      children: [
        // Not set up for this salon: there's nothing to control yet.
        if (!settings.whatsappReady)
          const WhatsAppNotSetUpCard()
        else ...[
          _MasterSwitchCard(settings: settings, data: data),
          const SizedBox(height: 12),
          _ThisMonthLine(settings: settings),
          const SizedBox(height: 20),
          const DsSectionLabel('What gets sent'),
          _TaskList(settings: settings),
          const SizedBox(height: 20),
          const DsSectionLabel('Check the setup'),
          const WhatsAppSetupChecks(),
        ],
      ],
    );
  }
}

/// Opens one task's page.
void openWhatsAppTask(BuildContext context, WhatsAppTask task) {
  openAppSubPage(
    context,
    title: task.title,
    subtitle: 'WhatsApp message',
    child: OwnerWhatsAppTaskPage(task: task),
  );
}

// ---------------------------------------------------------------------------
// Main page pieces
// ---------------------------------------------------------------------------

class _PageColumn extends StatelessWidget {
  final List<Widget> children;
  const _PageColumn({required this.children});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: children,
        ),
      ),
    );
  }
}

/// The one switch that stops or starts every message.
class _MasterSwitchCard extends ConsumerStatefulWidget {
  final SalonSettings settings;
  final AppData data;
  const _MasterSwitchCard({required this.settings, required this.data});

  @override
  ConsumerState<_MasterSwitchCard> createState() => _MasterSwitchCardState();
}

class _MasterSwitchCardState extends ConsumerState<_MasterSwitchCard> {
  bool _saving = false;

  Future<void> _toggle(bool on) async {
    setState(() => _saving = true);
    try {
      await ref.read(appDataProvider.notifier).updateSettings({'whatsappEnabled': on});
    } catch (e) {
      if (mounted) _snack(context, e.toString(), failed: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.settings.whatsappEnabled;
    final optedIn = widget.data.customers.where((c) => c.whatsappOptIn).length;
    final total = widget.data.customers.length;

    return DsCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The WhatsApp mark keeps its own green - the one place it's used.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppTheme.accentGreenBg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(PhosphorIconsFill.whatsappLogo, size: 22, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Automatic messages',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                    const SizedBox(height: 2),
                    Text(
                      on ? 'On - messages go out as set below' : 'Off - nothing is being sent',
                      style: TextStyle(fontSize: 12.5, color: on ? AppTheme.accentGreen : AppTheme.slateLight, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('whatsappEnabledSwitch'),
                value: on,
                onChanged: _saving ? null : _toggle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          const SizedBox(height: 12),
          Text(
            "Sent from your salon's WhatsApp Business number, only to clients who said OK to WhatsApp messages - "
            '$optedIn of $total clients so far.',
            style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.slateMedium),
          ),
          if (!on) ...[
            const SizedBox(height: 6),
            const Text(
              'Your choices below are kept while this is off.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// This month in one sentence, plus a warning when messages failed lately.
/// Deliberately a line, not a big-number banner: the page is for setting
/// things, and each task's page carries its own figures.
class _ThisMonthLine extends ConsumerWidget {
  final SalonSettings settings;
  const _ThisMonthLine({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider).valueOrNull;
    final log = ref.watch(whatsAppLogProvider(null)).valueOrNull ?? const [];
    final now = DateTime.now();

    final weekAgo = now.subtract(const Duration(days: 7));
    final failed = log.where((e) => e.failed && e.at != null && e.at!.isAfter(weekAgo)).toList();

    final children = <Widget>[];
    if (insights != null) {
      final m = insights.month(DateTime(now.year, now.month, 1));
      final sent = WhatsAppTask.values.fold<double>(0, (s, t) => s + m['wa.${t.counter}']).round();
      final back = m.reminderReturns;
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'This month  ', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
            TextSpan(text: '$sent message${sent == 1 ? '' : 's'} sent'),
            if (back > 0)
              TextSpan(
                text: '  ·  $back client${back == 1 ? '' : 's'} came back after a reminder '
                    '(${formatInr(m.reminderReturnSales)})',
              ),
          ]),
          style: const TextStyle(fontSize: 13, color: AppTheme.slateMedium, height: 1.4),
        ),
      ));
    }
    if (failed.isNotEmpty) {
      final task = failed.first.task;
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(_StatusNote(
        color: AppTheme.accentRed,
        background: AppTheme.accentRedBg,
        icon: PhosphorIconsRegular.warningCircle,
        text: "${failed.length} message${failed.length == 1 ? '' : 's'} didn't go out this week. "
            '${whatsAppErrorText(failed.first.error)}',
        action: task == null ? null : 'See ${task.title.toLowerCase()}',
        onAction: task == null ? null : () => openWhatsAppTask(context, task),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// The three messages as rows of one card: icon, name, when it goes, how
/// many went this month, its switch. Tap a row for its page.
class _TaskList extends ConsumerStatefulWidget {
  final SalonSettings settings;
  const _TaskList({required this.settings});

  @override
  ConsumerState<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends ConsumerState<_TaskList> {
  WhatsAppTask? _saving;

  Future<void> _toggle(WhatsAppTask task, bool on) async {
    setState(() => _saving = task);
    try {
      await ref.read(appDataProvider.notifier).updateWhatsAppTasks({task.settingKey: on});
    } catch (e) {
      if (mounted) _snack(context, e.toString(), failed: true);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(insightsProvider).valueOrNull;
    final now = DateTime.now();
    final month = insights?.month(DateTime(now.year, now.month, 1));
    final masterOn = widget.settings.whatsappEnabled;

    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final task in WhatsAppTask.values) ...[
            if (task.index > 0) const Divider(height: 1, color: AppTheme.borderSubtle, indent: 68),
            _TaskRow(
              task: task,
              settings: widget.settings,
              sentThisMonth: month == null ? null : month['wa.${task.counter}'].round(),
              cameBack: task == WhatsAppTask.reminder ? month?.reminderReturns : null,
              masterOn: masterOn,
              saving: _saving == task,
              onToggle: (on) => _toggle(task, on),
              onOpen: () => openWhatsAppTask(context, task),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _taskIcon(WhatsAppTask task) => switch (task) {
      WhatsAppTask.bill => PhosphorIconsRegular.receipt,
      WhatsAppTask.birthday => PhosphorIconsRegular.cake,
      WhatsAppTask.reminder => PhosphorIconsRegular.clockCounterClockwise,
    };

class _TaskRow extends StatelessWidget {
  final WhatsAppTask task;
  final SalonSettings settings;
  final int? sentThisMonth;
  final int? cameBack;
  final bool masterOn;
  final bool saving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  const _TaskRow({
    required this.task,
    required this.settings,
    required this.sentThisMonth,
    required this.cameBack,
    required this.masterOn,
    required this.saving,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final on = task.isOn(settings);
    final live = on && masterOn;
    // Null when the month's numbers aren't available (still loading, or
    // this salon's rules don't allow them yet) - the line is left out.
    final String? countText;
    if (!on) {
      countText = 'Switched off';
    } else if (!masterOn) {
      countText = 'Paused - automatic messages are off';
    } else if (sentThisMonth == null) {
      countText = null;
    } else {
      countText = '$sentThisMonth sent this month'
          '${cameBack != null && cameBack! > 0 ? ' · $cameBack came back' : ''}';
    }

    return InkWell(
      key: Key('whatsappTask_${task.name}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: live ? AppTheme.primaryLight : AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_taskIcon(task), size: 19, color: live ? AppTheme.primaryBlue : AppTheme.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: on ? AppTheme.slateDark : AppTheme.slateLight,
                      )),
                  const SizedBox(height: 2),
                  Text(task.rule(settings), style: const TextStyle(fontSize: 12.5, color: AppTheme.slateMedium)),
                  if (countText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    countText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: live ? AppTheme.slateDark : AppTheme.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  ],
                ],
              ),
            ),
            Switch(
              key: Key('whatsappTaskSwitch_${task.name}'),
              value: on,
              onChanged: saving ? null : onToggle,
            ),
            const Icon(PhosphorIconsRegular.caretRight, size: 15, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One task's page
// ---------------------------------------------------------------------------

class OwnerWhatsAppTaskPage extends ConsumerStatefulWidget {
  final WhatsAppTask task;
  const OwnerWhatsAppTaskPage({super.key, required this.task});

  @override
  ConsumerState<OwnerWhatsAppTaskPage> createState() => _OwnerWhatsAppTaskPageState();
}

class _OwnerWhatsAppTaskPageState extends ConsumerState<OwnerWhatsAppTaskPage> {
  bool _saving = false;

  WhatsAppTask get task => widget.task;

  Future<void> _save(Map<String, dynamic> changes, {String? done}) async {
    setState(() => _saving = true);
    try {
      await ref.read(appDataProvider.notifier).updateWhatsAppTasks(changes);
      if (mounted && done != null) _snack(context, done);
    } catch (e) {
      if (mounted) _snack(context, e.toString(), failed: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider).valueOrNull;
    final settings = data?.settings;
    if (data == null || settings == null) return const Center(child: CircularProgressIndicator());
    final on = task.isOn(settings);

    return _PageColumn(
      children: [
        _switchCard(settings, data, on),
        const SizedBox(height: 12),
        if (task != WhatsAppTask.bill) ...[
          _timingCard(settings),
          const SizedBox(height: 12),
        ],
        if (task == WhatsAppTask.reminder) ...[
          _ServiceGapsCard(services: data.services, generalDays: settings.whatsappReminderDays),
          const SizedBox(height: 12),
        ],
        _PreviewCard(task: task, settings: settings),
        const SizedBox(height: 20),
        const DsSectionLabel('Results'),
        _ResultsCard(task: task),
        const SizedBox(height: 20),
        const DsSectionLabel('Recent messages'),
        _RecentMessages(task: task),
      ],
    );
  }

  Widget _switchCard(SalonSettings settings, AppData data, bool on) {
    final optedIn = data.customers.where((c) => c.whatsappOptIn);
    final reach = switch (task) {
      WhatsAppTask.birthday =>
        '${optedIn.where((c) => (c.birthday ?? '').isNotEmpty).length} clients have a birthday saved and said OK to WhatsApp.',
      _ => '${optedIn.length} clients said OK to WhatsApp messages.',
    };
    return DsCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Send ${task.title.toLowerCase()}s',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                    const SizedBox(height: 2),
                    Text(task.rule(settings), style: const TextStyle(fontSize: 12.5, color: AppTheme.slateMedium)),
                  ],
                ),
              ),
              Switch(
                key: const Key('whatsappTaskPageSwitch'),
                value: on,
                onChanged: _saving ? null : (v) => _save({task.settingKey: v}),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(reach, style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
          if (!settings.whatsappEnabled) ...[
            const SizedBox(height: 10),
            const _StatusNote(
              color: AppTheme.accentAmber,
              background: AppTheme.accentAmberBg,
              icon: PhosphorIconsRegular.pause,
              text: 'Automatic messages are off for the whole salon, so this is paused. Turn them on from the WhatsApp page.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _timingCard(SalonSettings settings) {
    final List<(String, Object)> options;
    final Object current;
    final String key;
    final String title;
    final String help;
    if (task == WhatsAppTask.birthday) {
      key = 'whatsappBirthdayDaysBefore';
      title = 'When it goes';
      options = const [('On the birthday', 0), ('The day before', 1)];
      current = settings.whatsappBirthdayDaysBefore;
      help = 'At 10:00 AM. The message wishes them a happy birthday, so "the day before" reads as an early wish.';
    } else {
      key = 'whatsappReminderDays';
      title = 'Send after (salon default)';
      options = [for (final d in kReminderDayChoices) ('$d days', d)];
      final days = settings.whatsappReminderDays;
      // A gap set outside the usual choices still shows as picked.
      if (!kReminderDayChoices.contains(days)) options.add(('$days days', days));
      current = days;
      help = 'Days since their last visit with no new bill, for services without a gap of their own. '
          'Goes at 10:00 AM, once per visit - a client who comes back starts the count again.';
    }

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, value) in options)
                _ChoiceChip(
                  key: Key('whatsappChoice_$value'),
                  label: label,
                  selected: value == current,
                  onTap: _saving || value == current
                      ? null
                      : () => _save({key: value}, done: '${task.title}: ${label.toLowerCase()}'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(help, style: const TextStyle(fontSize: 12, height: 1.45, color: AppTheme.slateLight)),
        ],
      ),
    );
  }
}

/// Which services remind on their own gap (set when adding or editing a
/// service). A bill's earliest gap wins - see earliestServiceReminderDays.
class _ServiceGapsCard extends StatelessWidget {
  final List<SalonService> services;
  final int generalDays;
  const _ServiceGapsCard({required this.services, required this.generalDays});

  @override
  Widget build(BuildContext context) {
    final own = services.where((s) => s.reminderDays != null).toList()
      ..sort((a, b) => a.reminderDays!.compareTo(b.reminderDays!));
    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Services with their own gap',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                const SizedBox(height: 4),
                Text(
                  own.isEmpty
                      ? 'None yet - every service uses the $generalDays-day default. '
                          'Set a gap when you add or edit a service (Menu > Services).'
                      : 'The reminder follows what the client had done. With several on one bill, '
                          'the earliest goes first. Change these by editing the service (Menu > Services). '
                          'A change applies from the next bill.',
                  style: const TextStyle(fontSize: 12, height: 1.45, color: AppTheme.slateLight),
                ),
              ],
            ),
          ),
          if (own.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < own.length; i++) ...[
              const Divider(height: 1, color: AppTheme.borderSubtle, indent: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        own[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${own[i].reminderDays} days',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slateMedium,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// A pill choice in the app's navy - picked is filled, the rest outlined.
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _ChoiceChip({super.key, required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primaryBlue : AppTheme.cardBg,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppTheme.primaryBlue : AppTheme.borderStrong)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.slateDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// What the client receives, with the suggested template wording from
/// functions/whatsapp.md. The approved template in the salon's WhatsApp
/// Manager is what really goes, so the card says so.
class _PreviewCard extends StatelessWidget {
  final WhatsAppTask task;
  final SalonSettings settings;
  const _PreviewCard({required this.task, required this.settings});

  @override
  Widget build(BuildContext context) {
    final salon = settings.salonName;
    final text = switch (task) {
      WhatsAppTask.bill => 'Hi Priya, thank you for visiting $salon!\n\n'
          'Bill no: INV-0042\nServices: Haircut, Hair spa\nTotal: ₹1,200\nPaid: ₹1,200\nBalance due: ₹0',
      WhatsAppTask.birthday => 'Happy Birthday, Priya!\n\n'
          'Everyone at $salon wishes you a wonderful year ahead. Treat yourself to a fresh new look '
          'this birthday month, we would love to see you!',
      WhatsAppTask.reminder => 'Hi Priya, it has been a few weeks since your last visit to $salon. '
          'Time for a refresh? Reply to this message to book your next appointment. '
          'We would love to see you again!',
    };
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What the client gets',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                  topLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45, color: AppTheme.slateDark)),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'An example, with a sample client. The exact words are the template approved for your WhatsApp number.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Sends per month (navy bars, one series), and for reminders who came back.
class _ResultsCard extends ConsumerWidget {
  final WhatsAppTask task;
  const _ResultsCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insightsProvider);
    return async.when(
      loading: () => const DsCard(child: _Skeleton(lines: 4)),
      error: (e, _) => DsCard(
        child: _LoadError(error: e, onRetry: () => ref.invalidate(insightsProvider)),
      ),
      data: (insights) {
        final now = DateTime.now();
        final series = monthlySent(task, (m, k) => insights.month(m)[k], now: now);
        final thisMonth = series.values.last.round();
        final total = series.values.fold<double>(0, (s, v) => s + v).round();
        final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
        final returns = [for (final m in months) insights.month(m)];
        final backNow = returns.last.reminderReturns;
        final back6 = returns.fold<int>(0, (s, r) => s + r.reminderReturns);
        final spent6 = returns.fold<double>(0, (s, r) => s + r.reminderReturnSales);

        return InsightCard(
          title: 'Sent per month',
          subtitle: 'Last 6 months. Tap a bar for its count.',
          headline: '$thisMonth',
          headlineCaption: 'this month',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (total == 0)
                InsightEmpty('No ${task.title.toLowerCase()}s sent in the last 6 months yet.')
              else
                ColumnChart(
                  labels: series.labels,
                  series: [ColumnSeries('Sent', kChartNavy, series.values)],
                  height: 130,
                  format: (v) => v.round().toString(),
                  describe: (i) {
                    final n = series.values[i].round();
                    return '$n sent';
                  },
                ),
              if (task == WhatsAppTask.reminder) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppTheme.borderSubtle),
                const SizedBox(height: 14),
                InsightFigures([
                  ('Came back this month', '$backNow', 'billed within 30 days of a reminder'),
                  ('Last 6 months', '$back6', back6 == 0 ? null : 'clients came back'),
                  ('They spent', formatInr(spent6), 'on those visits'),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The task's latest sends: who, when, and Sent / Failed with the reason.
class _RecentMessages extends ConsumerWidget {
  final WhatsAppTask task;
  const _RecentMessages({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(whatsAppLogProvider(task));
    return async.when(
      loading: () => const DsCard(child: _Skeleton(lines: 5)),
      error: (e, _) => DsCard(child: _LoadError(error: e, onRetry: () => ref.invalidate(whatsAppLogProvider(task)))),
      data: (entries) {
        if (entries.isEmpty) {
          return DsCard(
            child: Text(
              switch (task) {
                WhatsAppTask.bill => 'Nothing sent yet. A receipt goes out each time you bill a client who said OK to WhatsApp.',
                WhatsAppTask.birthday => 'Nothing sent yet. Wishes go to clients with a birthday saved who said OK to WhatsApp.',
                WhatsAppTask.reminder => 'Nothing sent yet. Reminders go to clients who said OK to WhatsApp and haven\'t been back.',
              },
              style: const TextStyle(fontSize: 13, height: 1.45, color: AppTheme.slateLight),
            ),
          );
        }
        final now = DateTime.now();
        return DsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppTheme.borderSubtle, indent: 16),
                _LogRow(entry: entries[i], now: now),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LogRow extends StatelessWidget {
  final WhatsAppLogEntry entry;
  final DateTime now;
  const _LogRow({required this.entry, required this.now});

  @override
  Widget build(BuildContext context) {
    final (label, color) = entry.failed
        ? ('Failed', AppTheme.accentRed)
        : entry.sent
            ? ('Sent', AppTheme.accentGreen)
            : ('Sending', AppTheme.slateLight);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
              ),
              const SizedBox(width: 10),
              DsPill(label, color: color),
            ],
          ),
          const SizedBox(height: 2),
          Text(entry.at == null ? 'Time not recorded' : whatsAppLogTime(entry.at!, now),
              style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
          if (entry.failed) ...[
            const SizedBox(height: 4),
            Text(whatsAppErrorText(entry.error),
                style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.accentRed)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared bits
// ---------------------------------------------------------------------------

class _StatusNote extends StatelessWidget {
  final Color color;
  final Color background;
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const _StatusNote({
    required this.color,
    required this.background,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: TextStyle(fontSize: 12.5, height: 1.4, color: color, fontWeight: FontWeight.w600)),
                if (action != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      foregroundColor: color,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('$action  ›', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey bars in place of content while it loads.
class _Skeleton extends StatelessWidget {
  final int lines;
  const _Skeleton({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          FractionallySizedBox(
            widthFactor: i.isEven ? 0.7 : 0.45,
            child: Container(
              height: 12,
              decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _LoadError({required this.error, required this.onRetry});

  /// A refused read or a missing index means this salon's Firestore rules or
  /// indexes haven't been deployed yet (CLAUDE.md, Deployment) - not
  /// something the owner's connection can fix, so say so.
  String get _text {
    final code = error is FirebaseException ? (error as FirebaseException).code : '';
    if (code == 'permission-denied' || code == 'failed-precondition') {
      return "This isn't switched on for your salon yet. Ask the Stylux team to update it.";
    }
    return "Couldn't load this. Check the connection and try again.";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(_text, style: const TextStyle(fontSize: 13, color: AppTheme.slateMedium)),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

void _snack(BuildContext context, String text, {bool failed = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text.replaceFirst('Exception: ', '')),
      backgroundColor: failed ? AppTheme.accentRed : AppTheme.accentGreen,
    ),
  );
}
