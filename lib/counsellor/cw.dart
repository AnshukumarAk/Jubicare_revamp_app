import 'package:flutter/material.dart';

/// JubiCare 2.0 palette + UI kit, scoped to the Counsellor module.
/// (Kept separate from the login's widgets so the login/logo are untouched.)
class C2 {
  static const navy = Color(0xFF003087);
  static const cyan = Color(0xFF00B4D8);
  static const green = Color(0xFF7BC63E);
  static const yellow = Color(0xFFF5C518);
  static const cyanLight = Color(0xFFE0F5FC);
  static const navyLight = Color(0xFFE8EDF8);
  static const bg = Color(0xFFF0F7FB);
  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A2D42);
  static const text2 = Color(0xFF6B8099);
  static const text3 = Color(0xFF8FA4BC);
  static const border = Color(0xFFD0E8F5);
  static const danger = Color(0xFFE53935);

  static const headerGrad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [navy, cyan]);
  static List<BoxShadow> get shadow =>
      const [BoxShadow(color: Color(0x12003087), blurRadius: 12, offset: Offset(0, 2))];
}

TextStyle _t(double size, FontWeight w, Color c) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c);

/// White-card with cyan-light border.
class CCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  const CCard({super.key, required this.child, this.padding, this.onTap});
  @override
  Widget build(BuildContext context) {
    final inner = Padding(padding: padding ?? const EdgeInsets.all(14), child: child);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: C2.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C2.cyanLight),
        boxShadow: C2.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? inner : InkWell(onTap: onTap, child: inner),
    );
  }
}

/// Section header: cyan dot + navy bold title + cyan-light underline.
class SecBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SecBar(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight, width: 2))),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: C2.cyan, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(title, style: _t(13, FontWeight.w700, C2.navy))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class GradGreeting extends StatelessWidget {
  final String name, sub, initials;
  const GradGreeting({super.key, required this.name, required this.sub, required this.initials});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: C2.headerGrad, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(initials, style: _t(14, FontWeight.w700, Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: _t(15, FontWeight.w700, Colors.white)),
          Text(sub, style: _t(11.5, FontWeight.w400, Colors.white70)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: C2.green, borderRadius: BorderRadius.circular(4)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.circle, size: 6, color: Colors.white), const SizedBox(width: 3),
              Text('Online', style: _t(9, FontWeight.w700, Colors.white)),
            ]),
          ),
        ])),
      ]),
    );
  }
}

class StatTile extends StatelessWidget {
  final String value, label;
  final Color color;
  const StatTile(this.value, this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C2.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C2.cyanLight), boxShadow: C2.shadow),
      child: Column(children: [
        Text(value, style: _t(22, FontWeight.w800, color)),
        const SizedBox(height: 3),
        Text(label.toUpperCase(), textAlign: TextAlign.center, style: _t(10, FontWeight.w600, C2.text2)),
      ]),
    );
  }
}

class CBadge extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const CBadge(this.text, {super.key, this.bg = C2.cyanLight, this.fg = C2.cyan});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: _t(10, FontWeight.w600, fg)),
      );
}

/// Labelled form field wrapper (uppercase muted label, optional required *).
class CField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool required;
  const CField(this.label, this.child, {super.key, this.required = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(text: TextSpan(
            text: label.toUpperCase(),
            style: _t(11.5, FontWeight.w600, C2.text2),
            children: required ? [TextSpan(text: ' *', style: _t(11.5, FontWeight.w700, C2.danger))] : null,
          )),
        ),
        child,
      ]),
    );
  }
}

InputDecoration cInput([String? hint]) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: C2.white,
      hintStyle: _t(13.5, FontWeight.w400, C2.text3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C2.border, width: 1.5)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C2.border, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C2.cyan, width: 1.6)),
    );

class CPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const CPrimaryButton(this.label, {super.key, this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(gradient: C2.headerGrad, borderRadius: BorderRadius.circular(8)),
          child: Container(
            height: 46, alignment: Alignment.center,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 6)],
              Text(label, style: _t(14, FontWeight.w600, Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}

class COutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const COutlineButton(this.label, {super.key, this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon ?? Icons.add, size: 16, color: C2.navy),
        label: Text(label, style: _t(13, FontWeight.w600, C2.navy)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: C2.navy, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        ),
      );
}

TextStyle ct(double size, FontWeight w, Color c) => _t(size, w, c);

// dd-MM-yyyy (Indian numeric) — flipped from dd-MMM-yyyy on 2026-07-29 per
// user rule. Keep in sync with `_parseDate` in screens_misc.dart, which
// reads this format back for report filters.
String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

/// 12-hour clock with AM/PM (e.g. "09:05 AM", "01:30 PM").
String fmtTime12(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

/// A tappable field that opens a date picker and shows the chosen date.
class DateField extends StatefulWidget {
  final String hint;
  final DateTime? initial;
  final DateTime? first;
  final DateTime? last;
  final ValueChanged<DateTime>? onPicked;
  const DateField({super.key, this.hint = 'Select date', this.initial, this.first, this.last, this.onPicked});
  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  DateTime? _val;
  @override
  void initState() {
    super.initState();
    _val = widget.initial;
  }

  @override
  void didUpdateWidget(covariant DateField old) {
    super.didUpdateWidget(old);
    // Keep the visible value in sync with the parent's `initial` so a
    // reset-to-today (or reset-to-null on DOB) actually shows through.
    // The DateField is otherwise controlled by user picks via onPicked,
    // and _val already matches parent state between picks.
    if (old.initial != widget.initial) {
      setState(() => _val = widget.initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        // Root cause of the "scroll jumps to symptoms" bug:
        //   1. User has symptoms text field focused, its suggestion panel is
        //      showing.
        //   2. User taps this DateField -> showDatePicker opens a Dialog.
        //   3. When the Dialog closes, Flutter restores focus to whatever
        //      had it BEFORE the Dialog opened -> the symptoms field.
        //   4. Symptoms panel re-expands (~240 px) and the enclosing
        //      SingleChildScrollView auto-scrolls to keep the newly-focused
        //      field visible -> user lands on the symptoms section.
        // Two-part fix (both needed):
        //   (a) After the picker closes, unfocus again so focus does NOT
        //       return to the symptoms field on the next frame.
        //   (b) In a post-frame callback, ensureVisible on THIS DateField so
        //       the scroll view snaps back to where the user tapped, even if
        //       a stray auto-scroll fired first.
        FocusManager.instance.primaryFocus?.unfocus();
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _val ?? widget.initial ?? now,
          firstDate: widget.first ?? DateTime(1920),
          lastDate: widget.last ?? DateTime(2030),
        );
        if (picked != null) {
          setState(() => _val = picked);
          widget.onPicked?.call(picked);
        }
        // (a) Prevent focus from returning to the symptoms field.
        FocusManager.instance.primaryFocus?.unfocus();
        if (!mounted) return;
        // (b) Anchor the scroll view on this DateField after the frame settles.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        });
      },
      child: InputDecorator(
        decoration: cInput().copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16, color: C2.cyan)),
        child: Text(_val == null ? widget.hint : fmtDate(_val!),
            style: ct(13.5, _val == null ? FontWeight.w400 : FontWeight.w600, _val == null ? C2.text3 : C2.text)),
      ),
    );
  }
}

/// A dropdown-style field that opens a bottom sheet with a search box and a
/// scrollable filtered list. Looks identical to the plain DropdownButtonFormField
/// when closed; used for pickers with long lists (block, village) where the
/// default picker becomes unusable. Empty [items] disables interaction.
class SearchDropdown extends StatelessWidget {
  final List<String> items;
  final String? value;
  final String hint;
  final String? searchLabel;
  final ValueChanged<String?> onChanged;
  const SearchDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint = 'Select',
    this.searchLabel,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = items.isEmpty;
    return InkWell(
      onTap: disabled ? null : () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _SearchSheet(items: items, current: value, hint: searchLabel ?? 'Search $hint'),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: cInput().copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down, color: C2.text2),
        ),
        child: Text(
          value ?? hint,
          overflow: TextOverflow.ellipsis,
          style: ct(13.5, value == null ? FontWeight.w400 : FontWeight.w600,
              value == null ? C2.text3 : C2.text),
        ),
      ),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  final List<String> items;
  final String? current;
  final String hint;
  const _SearchSheet({required this.items, required this.current, required this.hint});
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late final TextEditingController _q = TextEditingController();
  List<String> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.items);
    _q.addListener(_apply);
  }

  void _apply() {
    final q = _q.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(widget.items)
          : widget.items.where((e) => e.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() { _q.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: C2.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          TextField(
            controller: _q,
            autofocus: true,
            decoration: cInput(widget.hint).copyWith(
              prefixIcon: const Icon(Icons.search, size: 18, color: C2.text2),
            ),
            style: ct(13.5, FontWeight.w500, C2.text),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No matches', style: ct(13, FontWeight.w400, C2.text2)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: C2.border),
                    itemBuilder: (_, i) {
                      final it = _filtered[i];
                      final selected = it == widget.current;
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(it),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          child: Row(children: [
                            Expanded(child: Text(it, style: ct(13.5, selected ? FontWeight.w700 : FontWeight.w500, C2.text))),
                            if (selected) const Icon(Icons.check, size: 18, color: C2.cyan),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// A tappable field that opens a time picker and shows the chosen time.
class TimeField extends StatefulWidget {
  final String hint;
  final TimeOfDay? initial;
  final ValueChanged<TimeOfDay>? onPicked;
  const TimeField({super.key, this.hint = '--:--', this.initial, this.onPicked});
  @override
  State<TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<TimeField> {
  TimeOfDay? _val;
  @override
  void initState() {
    super.initState();
    _val = widget.initial;
  }

  @override
  void didUpdateWidget(covariant TimeField old) {
    super.didUpdateWidget(old);
    // Keep the visible time in sync with the parent's `initial` so an
    // auto-fill (e.g. counsellor Check-in) actually shows through.
    if (old.initial != widget.initial) {
      setState(() => _val = widget.initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context, initialTime: _val ?? TimeOfDay.now(),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false), child: child!),
        );
        if (picked != null) { setState(() => _val = picked); widget.onPicked?.call(picked); }
      },
      child: InputDecorator(
        decoration: cInput().copyWith(suffixIcon: const Icon(Icons.access_time, size: 16, color: C2.cyan)),
        child: Text(_val == null ? widget.hint : fmtTime12(_val!),
            style: ct(13.5, _val == null ? FontWeight.w400 : FontWeight.w600, _val == null ? C2.text3 : C2.text)),
      ),
    );
  }
}
