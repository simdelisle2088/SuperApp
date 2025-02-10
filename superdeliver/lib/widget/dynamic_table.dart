import 'package:flutter/material.dart';

class CustomDataTable extends StatefulWidget {
  final List<String> columnNames;
  final List<Map<String, dynamic>> rowsData;
  final void Function(Set<int>)? onSelectionChanged;
  final VoidCallback? onDelete;

  const CustomDataTable({
    super.key,
    required this.columnNames,
    required this.rowsData,
    this.onSelectionChanged,
    this.onDelete,
  });

  @override
  _CustomDataTableState createState() => _CustomDataTableState();

  void unselect() {
    _selectedRowsNotifier.value.clear();
  }

  void handleDeletion() {
    var selected = _selectedRowsNotifier.value.toList()
      ..sort((a, b) => b.compareTo(a));
    for (int index in selected) {
      if (index >= 0 && index < rowsData.length) rowsData.removeAt(index);
    }
    _selectedRowsNotifier.value.clear();
  }

  Set<int> getSelectedIndices() {
    final state = _CustomDataTableState();
    return state.getSelectedIndices();
  }
}

ValueNotifier<Set<int>> _selectedRowsNotifier = ValueNotifier<Set<int>>({});

class _CustomDataTableState extends State<CustomDataTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(CustomDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to bottom whenever data changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Set<int> getSelectedIndices() => Set.from(_selectedRowsNotifier.value);

  void _handleRowSelection(int index, bool? selected) {
    setState(() {
      final selectedRows = _selectedRowsNotifier.value;
      if (selected == true) {
        selectedRows.add(index);
      } else {
        selectedRows.remove(index);
      }
      _selectedRowsNotifier.value = Set.from(selectedRows);
      widget.onSelectionChanged?.call(_selectedRowsNotifier.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalRows = widget.rowsData.length;
    final selectedRowsCount = _selectedRowsNotifier.value.length;

    final columns = <DataColumn>[
      const DataColumn(label: Text('#')), // Add an Index column
      ...widget.columnNames.map((name) => DataColumn(
            label: Text(name),
          )),
    ];

    final rows = widget.rowsData.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> row = entry.value;

      return DataRow(
        cells: [
          DataCell(
            Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 18),
            ),
          ), // Add the index cell
          ...widget.columnNames.map(
            (columnName) => DataCell(
              Text(
                row[columnName]?.toString() ?? '',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
        selected: _selectedRowsNotifier.value.contains(index),
        onSelectChanged: (bool? selected) =>
            _handleRowSelection(index, selected),
      );
    }).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && widget.rowsData.isNotEmpty) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(
            minHeight: 250,
            maxHeight: 275,
            minWidth: double.infinity,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(10.0)),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.vertical,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dataTableTheme: const DataTableThemeData(
                    headingRowHeight: 48,
                    dataRowHeight: 48,
                    dividerThickness: 1,
                  ),
                ),
                child: DataTable(
                  horizontalMargin: 12.0,
                  columnSpacing: 12.0,
                  headingTextStyle: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  columns: columns,
                  rows: rows,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Total des éléments: $totalRows${selectedRowsCount > 0 ? ' | Sélectionné: $selectedRowsCount' : ''}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              backgroundColor: Colors.grey[300],
            ),
          ),
        ),
      ],
    );
  }
}
