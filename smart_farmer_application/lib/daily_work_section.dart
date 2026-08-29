import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'daily_work_service.dart';

const Color _bg = Color(0xFF0F130D);
const Color _card = Color(0xFF1A2117);
const Color _card2 = Color(0xFF20291B);
const Color _green = Color(0xFFB7D83D);
const Color _darkGreen = Color(0xFF17200F);
const Color _grey = Color(0xFF899181);

class DailyTimeWorkSection extends StatefulWidget {
  const DailyTimeWorkSection({super.key});

  @override
  State<DailyTimeWorkSection> createState() => _DailyTimeWorkSectionState();
}

class _DailyTimeWorkSectionState extends State<DailyTimeWorkSection> {
  DateTime _selectedDate = DateTime.now();

  String get _dateKey => DailyWorkService.dateKeyFor(_selectedDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _green,
              onPrimary: _darkGreen,
              surface: _card,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _shiftDay(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _openWorkSheet({DailyWorkItem? existing}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Please log in to manage daily work.', isError: true);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WorkFormSheet(
        existing: existing,
        date: _selectedDate,
        onSave: (name, start, end) async {
          await DailyWorkService.saveWork(
            workId: existing?.id,
            name: name,
            start: start,
            end: end,
            date: _selectedDate,
          );
        },
      ),
    );
  }

  Future<void> _deleteWork(DailyWorkItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Work',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove "${item.name}" from this day?',
          style: const TextStyle(color: _grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DailyWorkService.deleteWork(item.id);
    } catch (e) {
      if (mounted) _snack('Unable to delete work. Please try again.', isError: true);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : _green,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: TextStyle(
            color: isError ? Colors.white : _darkGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _green.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _darkGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.schedule_outlined,
                  color: _green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Daily Time & Work',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _openWorkSheet(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: _darkGreen, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Add Work',
                        style: TextStyle(
                          color: _darkGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Selected Day',
            style: TextStyle(
              color: _grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _roundIconButton(Icons.chevron_left, () => _shiftDay(-1)),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _card2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _green.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: _green,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DailyWorkService.formatDisplayDate(_selectedDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _roundIconButton(Icons.chevron_right, () => _shiftDay(1)),
            ],
          ),
          const SizedBox(height: 18),
          if (user == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Please log in to manage daily work.',
                style: TextStyle(color: _grey, fontSize: 13),
              ),
            )
          else
            StreamBuilder<List<DailyWorkItem>>(
              stream: DailyWorkService.watchForDate(_dateKey),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Unable to load daily work. Please try again.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _green,
                          strokeWidth: 2.2,
                        ),
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No work added for this day.',
                      style: TextStyle(color: _grey, fontSize: 13),
                    ),
                  );
                }

                final total = items.fold<int>(
                  0,
                  (sum, item) => sum + item.durationMinutes,
                );

                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'WORK',
                              style: TextStyle(
                                color: _grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'START',
                              style: TextStyle(
                                color: _grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'END',
                              style: TextStyle(
                                color: _grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'TIME',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: _grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...items.map((item) => _workRow(item)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Total Time:',
                          style: TextStyle(
                            color: _grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DailyWorkService.formatTotalDuration(total),
                          style: const TextStyle(
                            color: _green,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _darkGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _green, size: 22),
      ),
    );
  }

  Widget _workRow(DailyWorkItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        decoration: BoxDecoration(
          color: _card2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.startTime,
                style: const TextStyle(color: _grey, fontSize: 11),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.endTime,
                style: const TextStyle(color: _grey, fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                DailyWorkService.formatDuration(item.durationMinutes),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _green,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            PopupMenuButton<String>(
              color: _card,
              icon: const Icon(Icons.more_vert, color: _grey, size: 18),
              onSelected: (value) {
                if (value == 'edit') _openWorkSheet(existing: item);
                if (value == 'delete') _deleteWork(item);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkFormSheet extends StatefulWidget {
  final DailyWorkItem? existing;
  final DateTime date;
  final Future<void> Function(String name, TimeOfDay start, TimeOfDay end)
      onSave;

  const _WorkFormSheet({
    required this.existing,
    required this.date,
    required this.onSave,
  });

  @override
  State<_WorkFormSheet> createState() => _WorkFormSheetState();
}

class _WorkFormSheetState extends State<_WorkFormSheet> {
  late final TextEditingController _nameController;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _start = widget.existing?.startTimeOfDay;
    _end = widget.existing?.endTimeOfDay;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = (isStart ? _start : _end) ??
        const TimeOfDay(hour: 7, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _green,
              onPrimary: _darkGreen,
              surface: _card,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _start == null || _end == null) {
      setState(() => _error = 'Enter work name, start time, and end time.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSave(name, _start!, _end!);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to save work. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = (_start != null && _end != null)
        ? DailyWorkService.formatDuration(
            DailyWorkService.durationMinutes(_start!, _end!),
          )
        : '--';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null ? 'Add Work' : 'Edit Work',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DailyWorkService.formatDisplayDate(widget.date),
              style: const TextStyle(color: _grey, fontSize: 12),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Work name (e.g. Watering)',
                hintStyle: const TextStyle(color: _grey),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _timeButton(
                    label: 'Start time',
                    value: _start == null
                        ? 'Select'
                        : DailyWorkService.formatTimeOfDay(_start!),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _timeButton(
                    label: 'End time',
                    value: _end == null
                        ? 'Select'
                        : DailyWorkService.formatTimeOfDay(_end!),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Duration: $duration',
              style: const TextStyle(
                color: _green,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: _darkGreen,
                  disabledBackgroundColor: _grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _darkGreen,
                        ),
                      )
                    : Text(
                        widget.existing == null ? 'Save Work' : 'Update Work',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: _grey, fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
