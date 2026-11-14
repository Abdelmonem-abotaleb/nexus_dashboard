import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

class TodoWidget extends StatefulWidget {
  const TodoWidget({super.key});

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todos = context.select<DashboardProvider, List<TodoItem>>(
      (dashboard) => dashboard.todos,
    );
    final dashboard = context.read<DashboardProvider>();
    final pending = todos.where((todo) => !todo.completed).toList();
    final completed = todos.where((todo) => todo.completed).toList();
    final todoItems = <Widget>[
      ...pending.map(
        (todo) => _TodoTile(
          key: ValueKey(todo.id),
          todo: todo,
          onToggle: () => dashboard.toggleTodo(todo.id),
          onDelete: () => dashboard.deleteTodo(todo.id),
        ),
      ),
      if (completed.isNotEmpty) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'COMPLETED',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
              fontSize: 9,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...completed.map(
          (todo) => _TodoTile(
            key: ValueKey(todo.id),
            todo: todo,
            onToggle: () => dashboard.toggleTodo(todo.id),
            onDelete: () => dashboard.deleteTodo(todo.id),
          ),
        ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
        context,
        borderRadius: 20,
        borderColor: const Color(0xFFFFBD2E).withValues(alpha: 0.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: Color(0xFFFFBD2E), size: 14),
              const SizedBox(width: 8),
              Text(
                'TO-DO',
                style: TextStyle(
                  color: Color(0xFFFFBD2E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              if (completed.isNotEmpty)
                TextButton(
                  onPressed: dashboard.clearCompletedTodos,
                  child: const Text('CLEAR DONE'),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Input field
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a task...',
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (text) {
                      dashboard.addTodo(text);
                      _controller.clear();
                      _focusNode.requestFocus();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Task with due date & priority',
                  onPressed: () => _showRichAddDialog(context, dashboard),
                  icon: const Icon(Icons.event_note_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Add to-do',
                  onPressed: () {
                    dashboard.addTodo(_controller.text);
                    _controller.clear();
                    _focusNode.requestFocus();
                  },
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats
          if (pending.isNotEmpty || completed.isNotEmpty) ...[
            Row(
              children: [
                _StatBadge(
                  label: '${pending.length} pending',
                  color: const Color(0xFFFFBD2E),
                ),
                const SizedBox(width: 8),
                _StatBadge(
                  label: '${completed.length} done',
                  color: AppTheme.neonGreen,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Todo list
          if (todoItems.isNotEmpty)
            Flexible(
              fit: FlexFit.loose,
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: todoItems,
              ),
            ),
        ],
      ),
    );
  }

  void _showRichAddDialog(BuildContext context, DashboardProvider dashboard) {
    final textController = TextEditingController(text: _controller.text);
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    TodoPriority selectedPriority = TodoPriority.none;
    var remind = true;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2630),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppTheme.accent(context).withValues(alpha: 0.3),
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.add_task_rounded, color: AppTheme.accent(context), size: 20),
              const SizedBox(width: 8),
              const Text(
                'New Task',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'What needs to be done?',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Priority
                const Text(
                  'PRIORITY',
                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: TodoPriority.values.map((priority) {
                    final isSelected = selectedPriority == priority;
                    final (label, color) = switch (priority) {
                      TodoPriority.none => ('None', Colors.white54),
                      TodoPriority.low => ('Low', AppTheme.neonBlue),
                      TodoPriority.medium => ('Med', const Color(0xFFFFBD2E)),
                      TodoPriority.high => ('High', AppTheme.neonPink),
                    };

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: color.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          color: isSelected ? color : Colors.white60,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? color : Colors.white24,
                        ),
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedPriority = priority);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Due date & time
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 14),
                        label: Text(
                          selectedDate != null
                              ? DateFormat('MMM d, y').format(selectedDate!)
                              : 'Due Date',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_rounded, size: 14),
                        label: Text(
                          selectedTime != null
                              ? selectedTime!.format(ctx)
                              : 'Time',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Remind toggle
                if (selectedDate != null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: remind,
                    dense: true,
                    title: const Text(
                      'Desktop Notification Reminder',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    onChanged: (val) => setDialogState(() => remind = val ?? false),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent(context),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final text = textController.text.trim();
                if (text.isEmpty) return;

                DateTime? dueDateTime;
                if (selectedDate != null) {
                  dueDateTime = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    selectedTime?.hour ?? 9,
                    selectedTime?.minute ?? 0,
                  );
                }

                dashboard.addTodo(
                  text,
                  dueAt: dueDateTime,
                  priority: selectedPriority,
                  remind: remind && dueDateTime != null,
                );
                _controller.clear();
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('ADD TASK'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TodoTile extends StatefulWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<_TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<_TodoTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final todo = widget.todo;
    final isOverdue = !todo.completed &&
        todo.dueAt != null &&
        todo.dueAt!.isBefore(DateTime.now());

    final priorityColor = switch (todo.priority) {
      TodoPriority.high => AppTheme.neonPink,
      TodoPriority.medium => const Color(0xFFFFBD2E),
      TodoPriority.low => AppTheme.neonBlue,
      TodoPriority.none => Colors.transparent,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _hovered
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: priorityColor,
              width: todo.priority != TodoPriority.none ? 3.5 : 0,
            ),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Tooltip(
              message: todo.completed ? 'Mark incomplete' : 'Mark complete',
              child: Checkbox(
                value: todo.completed,
                onChanged: (_) => widget.onToggle(),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),

            // Text & details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    todo.text,
                    style: TextStyle(
                      color: todo.completed
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72)
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      decoration: todo.completed
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (todo.dueAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.access_time_rounded,
                          size: 11,
                          color: isOverdue ? AppTheme.neonPink : Colors.white60,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, h:mm a').format(todo.dueAt!),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                            color: isOverdue ? AppTheme.neonPink : Colors.white60,
                          ),
                        ),
                        if (todo.remind && !todo.completed) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 10,
                            color: AppTheme.accent(context),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Delete button
            if (_hovered)
              IconButton(
                onPressed: widget.onDelete,
                tooltip: 'Delete to-do',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 16,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
