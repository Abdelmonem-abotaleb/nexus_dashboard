import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final dashboard = context.watch<DashboardProvider>();
    final pending = dashboard.pendingTodos;
    final completed = dashboard.completedTodos;
    final todoItems = <Widget>[
      ...pending.map(
        (todo) => _TodoTile(
          key: ValueKey(todo.id),
          text: todo.text,
          completed: false,
          onToggle: () => dashboard.toggleTodo(todo.id),
          onDelete: () => dashboard.deleteTodo(todo.id),
        ),
      ),
      if (completed.isNotEmpty) ...[
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'COMPLETED',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...completed.map(
          (todo) => _TodoTile(
            key: ValueKey(todo.id),
            text: todo.text,
            completed: true,
            onToggle: () => dashboard.toggleTodo(todo.id),
            onDelete: () => dashboard.deleteTodo(todo.id),
          ),
        ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
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
                GestureDetector(
                  onTap: () => dashboard.clearCompletedTodos(),
                  child: Text(
                    'CLEAR DONE',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add a task...',
                      hintStyle: TextStyle(
                        color: AppTheme.textMuted,
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
                GestureDetector(
                  onTap: () {
                    dashboard.addTodo(_controller.text);
                    _controller.clear();
                    _focusNode.requestFocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.add_rounded,
                      color: Color(0xFFFFBD2E),
                      size: 18,
                    ),
                  ),
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
  final String text;
  final bool completed;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TodoTile({
    super.key,
    required this.text,
    required this.completed,
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _hovered
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: widget.onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: widget.completed
                      ? AppTheme.neonGreen.withValues(alpha: 0.3)
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.completed
                        ? AppTheme.neonGreen
                        : AppTheme.textMuted,
                    width: 1.5,
                  ),
                ),
                child: widget.completed
                    ? Icon(
                        Icons.check_rounded,
                        color: AppTheme.neonGreen,
                        size: 12,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),

            // Text
            Expanded(
              child: Text(
                widget.text,
                style: TextStyle(
                  color: widget.completed
                      ? AppTheme.textMuted
                      : AppTheme.textSecondary,
                  fontSize: 13,
                  decoration: widget.completed
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: AppTheme.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Delete button
            if (_hovered)
              GestureDetector(
                onTap: widget.onDelete,
                child: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textMuted,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
