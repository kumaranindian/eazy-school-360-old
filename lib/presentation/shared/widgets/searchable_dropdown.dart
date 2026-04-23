import 'package:flutter/material.dart';

/// A searchable dropdown widget that allows users to search items by typing
/// Replaces standard dropdowns throughout the app
class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? hint;
  final bool enabled;
  final String? Function(T?)? validator;
  final InputDecoration? decoration;
  final double? maxHeight;

  const SearchableDropdown({
    super.key,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
    this.hint,
    this.enabled = true,
    this.validator,
    this.decoration,
    this.maxHeight,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SearchDialog<T>(
        items: widget.items,
        itemLabel: widget.itemLabel,
        currentValue: widget.value,
        onSelected: (value) {
          widget.onChanged(value);
          Navigator.pop(ctx);
        },
        maxHeight: widget.maxHeight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.value != null
        ? widget.itemLabel(widget.value as T)
        : (widget.hint ?? 'Select...');

    return FormField<T>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.enabled ? _showSearchDialog : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.enabled ? _bgDark : _bgDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: field.hasError ? Colors.red : _borderColor,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayText,
                        style: TextStyle(
                          color: widget.value != null ? _textPrimary : _textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: widget.enabled ? _textSecondary : _textSecondary.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SearchDialog<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) itemLabel;
  final T? currentValue;
  final void Function(T?) onSelected;
  final double? maxHeight;

  const _SearchDialog({
    required this.items,
    required this.itemLabel,
    required this.currentValue,
    required this.onSelected,
    this.maxHeight,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final _searchController = TextEditingController();
  List<T> _filteredItems = [];

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) => widget.itemLabel(item).toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = widget.maxHeight ?? screenHeight * 0.6;

    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with search
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Search & Select',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _textSecondary),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: _textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type to search...',
                      hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.5)),
                      prefixIcon: const Icon(Icons.search, color: _textSecondary, size: 20),
                      filled: true,
                      fillColor: _bgDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _accentBlue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Results count
            if (_filteredItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filteredItems.length} item(s) found',
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ),
            // Items list
            Flexible(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: _textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'No items found',
                              style: TextStyle(color: _textSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = item == widget.currentValue;
                        final label = widget.itemLabel(item);

                        return InkWell(
                          onTap: () => widget.onSelected(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? _accentBlue.withValues(alpha: 0.15) : null,
                              border: const Border(bottom: BorderSide(color: _borderColor, width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected ? _accentBlue : _textPrimary,
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: _accentBlue, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Clear button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _borderColor)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => widget.onSelected(null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textSecondary,
                    side: const BorderSide(color: _borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Clear Selection'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
