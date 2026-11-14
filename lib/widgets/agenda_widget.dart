import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/agenda_provider.dart';
import '../theme/app_theme.dart';

class AgendaWidget extends StatelessWidget {
  const AgendaWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<AgendaProvider>().events;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visible = events
        .where(
          (event) =>
              !event.startsAt.isBefore(today) &&
              event.startsAt.isBefore(today.add(const Duration(days: 8))),
        )
        .toList(growable: false);
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(context, borderRadius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: accent, size: 18),
              const SizedBox(width: 8),
              Text('AGENDA', style: _headingStyle(context, accent)),
              const Spacer(),
              Tooltip(
                message: 'View all events',
                child: IconButton(
                  onPressed: () => _showAllEvents(context),
                  icon: const Icon(Icons.open_in_full_rounded),
                  iconSize: 18,
                ),
              ),
              Tooltip(
                message: 'Add event',
                child: IconButton.filledTonal(
                  onPressed: () => showAgendaEventDialog(context),
                  icon: const Icon(Icons.add_rounded),
                  iconSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your next seven days are clear',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => showAgendaEventDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add an event'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _AgendaEventTile(
                  event: visible[index],
                  onEdit: () =>
                      showAgendaEventDialog(context, event: visible[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAllEvents(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const _AllEventsDialog(),
  );
}

TextStyle _headingStyle(BuildContext context, Color color) => TextStyle(
  color: color,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.4,
);

class _AgendaEventTile extends StatelessWidget {
  final AgendaEvent event;
  final VoidCallback onEdit;

  const _AgendaEventTile({required this.event, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(
      event.startsAt.year,
      event.startsAt.month,
      event.startsAt.day,
    );
    final dayLabel = eventDay == today
        ? 'TODAY'
        : eventDay == today.add(const Duration(days: 1))
        ? 'TOMORROW'
        : DateFormat('EEE, MMM d').format(event.startsAt).toUpperCase();
    final time = event.isAllDay
        ? 'ALL DAY'
        : event.endsAt == null
        ? DateFormat.jm().format(event.startsAt)
        : '${DateFormat.jm().format(event.startsAt)} – ${DateFormat.jm().format(event.endsAt!)}';

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.56),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$dayLabel  ·  $time',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllEventsDialog extends StatelessWidget {
  const _AllEventsDialog();

  @override
  Widget build(BuildContext context) {
    final events = context.watch<AgendaProvider>().events;
    final now = DateTime.now();
    final upcoming = events
        .where((event) => !event.startsAt.isBefore(now))
        .toList();
    final past = events
        .where((event) => event.startsAt.isBefore(now))
        .toList()
        .reversed
        .toList();

    return AlertDialog(
      title: const Text('Agenda'),
      content: SizedBox(
        width: 620,
        height: 520,
        child: events.isEmpty
            ? const Center(child: Text('No events yet.'))
            : ListView(
                children: [
                  if (upcoming.isNotEmpty) ...[
                    const _DialogSectionLabel('UPCOMING'),
                    ...upcoming.map(
                      (event) => ListTile(
                        title: Text(event.title),
                        subtitle: Text(_eventSubtitle(event)),
                        onTap: () =>
                            showAgendaEventDialog(context, event: event),
                        trailing: IconButton(
                          tooltip: 'Delete ${event.title}',
                          onPressed: () =>
                              context.read<AgendaProvider>().remove(event.id),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
                  ],
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _DialogSectionLabel('PAST'),
                    ...past.map(
                      (event) => ListTile(
                        title: Text(event.title),
                        subtitle: Text(_eventSubtitle(event)),
                        onTap: () =>
                            showAgendaEventDialog(context, event: event),
                        trailing: IconButton(
                          tooltip: 'Delete ${event.title}',
                          onPressed: () =>
                              context.read<AgendaProvider>().remove(event.id),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () => showAgendaEventDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add event'),
        ),
      ],
    );
  }

  static String _eventSubtitle(AgendaEvent event) => event.isAllDay
      ? '${DateFormat.yMMMd().format(event.startsAt)} · All day'
      : '${DateFormat.yMMMd().format(event.startsAt)} · ${DateFormat.jm().format(event.startsAt)}';
}

class _DialogSectionLabel extends StatelessWidget {
  final String label;
  const _DialogSectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

Future<void> showAgendaEventDialog(
  BuildContext context, {
  AgendaEvent? event,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _AgendaEventDialog(event: event),
  );
}

class _AgendaEventDialog extends StatefulWidget {
  final AgendaEvent? event;
  const _AgendaEventDialog({this.event});

  @override
  State<_AgendaEventDialog> createState() => _AgendaEventDialogState();
}

class _AgendaEventDialogState extends State<_AgendaEventDialog> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _date;
  late TimeOfDay _startTime;
  TimeOfDay? _endTime;
  late bool _allDay;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.event;
    final initial =
        existing?.startsAt ?? DateTime.now().add(const Duration(hours: 1));
    _title = TextEditingController(text: existing?.title ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _date = DateTime(initial.year, initial.month, initial.day);
    _startTime = TimeOfDay.fromDateTime(initial);
    _endTime = existing?.endsAt == null
        ? null
        : TimeOfDay.fromDateTime(existing!.endsAt!);
    _allDay = existing?.isAllDay ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Add event' : 'Edit event'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(DateFormat.yMMMMd().format(_date)),
                onTap: _pickDate,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All day'),
                value: _allDay,
                onChanged: (value) => setState(() {
                  _allDay = value;
                  if (value) _endTime = null;
                }),
              ),
              if (!_allDay)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickTime(isEnd: false),
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text('Start ${_startTime.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickTime(isEnd: true),
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(
                          _endTime == null
                              ? 'Add end time'
                              : 'End ${_endTime!.format(context)}',
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickTime({required bool isEnd}) async {
    final value = await showTimePicker(
      context: context,
      initialTime: isEnd ? (_endTime ?? _startTime) : _startTime,
    );
    if (value == null) return;
    setState(() {
      if (isEnd) {
        _endTime = value;
      } else {
        _startTime = value;
      }
    });
  }

  Future<void> _save() async {
    final startsAt = _allDay
        ? _date
        : DateTime(
            _date.year,
            _date.month,
            _date.day,
            _startTime.hour,
            _startTime.minute,
          );
    final endsAt = _allDay || _endTime == null
        ? null
        : DateTime(
            _date.year,
            _date.month,
            _date.day,
            _endTime!.hour,
            _endTime!.minute,
          );
    final provider = context.read<AgendaProvider>();
    final value = AgendaEvent(
      id: widget.event?.id ?? provider.generateId(),
      title: _title.text.trim(),
      startsAt: startsAt,
      endsAt: endsAt,
      notes: _notes.text.trim(),
      isAllDay: _allDay,
    );
    final error = widget.event == null
        ? await provider.add(value)
        : await provider.update(value);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
  }
}
