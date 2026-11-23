import 'package:flutter/material.dart';

import '../domain/calendar_date.dart';
import '../domain/grave_rejection.dart';
import 'grave_list_controller.dart';
import 'graveyard_copy.dart';

/// The "Bury by hand" option of the add sheet.
///
/// A name field, a read-only date field that opens a date picker, and a submit
/// button. Enter in the name field submits. A rejection shows its reason under
/// the field it belongs to, and the typed text stays.
class BuryByHandForm extends StatefulWidget {
  /// Creates the form. [onBuried] runs after the grave was added.
  const BuryByHandForm({
    super.key,
    required this.controller,
    required this.onBuried,
  });

  /// The controller that validates and stores the grave.
  final GraveListController controller;

  /// Called once, after a grave was added.
  final VoidCallback onBuried;

  @override
  State<BuryByHandForm> createState() => _BuryByHandFormState();
}

class _BuryByHandFormState extends State<BuryByHandForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _dateText = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  CalendarDate? _date;
  GraveRejection? _rejection;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _dateText.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _isDateProblem =>
      _rejection == GraveRejection.dateMissing ||
      _rejection == GraveRejection.dateNotReal ||
      _rejection == GraveRejection.dateInFuture ||
      _rejection == GraveRejection.dateTooEarly;

  Future<void> _pickDate() async {
    final CalendarDate today = widget.controller.today;
    final CalendarDate initial = _date ?? today;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(
        CalendarDate.earliest.year,
        CalendarDate.earliest.month,
        CalendarDate.earliest.day,
      ),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final CalendarDate chosen = CalendarDate(
        picked.year,
        picked.month,
        picked.day,
      );
      _date = chosen;
      _dateText.text = GraveyardCopy.date(chosen);
      if (_isDateProblem) _rejection = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    _busy = true;
    final CalendarDate? date = _date;
    final GraveRejection? reason = await widget.controller.addManual(
      rawName: _name.text,
      year: date?.year,
      month: date?.month,
      day: date?.day,
    );
    _busy = false;
    if (!mounted) return;
    if (reason == null) {
      widget.onBuried();
    } else {
      setState(() => _rejection = reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GraveRejection? reason = _rejection;
    final String? nameError = reason != null && !_isDateProblem
        ? GraveyardCopy.rejection(reason)
        : null;
    final String? dateError = reason != null && _isDateProblem
        ? GraveyardCopy.rejection(reason)
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('bury-name'),
          controller: _name,
          focusNode: _nameFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: GraveyardCopy.nameLabel,
            hintText: GraveyardCopy.nameHint,
            errorText: nameError,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('bury-date'),
          controller: _dateText,
          readOnly: true,
          onTap: _pickDate,
          decoration: InputDecoration(
            labelText: GraveyardCopy.dateLabel,
            hintText: GraveyardCopy.dateHint,
            suffixIcon: const Icon(Icons.calendar_today_outlined),
            errorText: dateError,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey<String>('bury-submit'),
          onPressed: _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text(GraveyardCopy.buryButton),
        ),
      ],
    );
  }
}
