// lib/widgets/employee_search.dart

import 'package:flutter/material.dart';
import '../services/pb_service.dart';

class EmployeeSearch extends StatefulWidget {
  final Function(Map<String, dynamic> employee) onSelected;
  final String? label;

  const EmployeeSearch({
    super.key,
    required this.onSelected,
    this.label,
  });

  @override
  State<EmployeeSearch> createState() => _EmployeeSearchState();
}

class _EmployeeSearchState extends State<EmployeeSearch> {
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedEmployee;
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);
    final results = await _db.searchEmployees(query);
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  void _selectEmployee(Map<String, dynamic> employee) {
    setState(() {
      _selectedEmployee = employee;
      _results = [];
      _searchCtrl.clear();
    });
    widget.onSelected(employee);
  }

  void _clearSelection() {
    setState(() => _selectedEmployee = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

        if (_selectedEmployee != null)
          Card(
            color: Colors.blue.shade50,
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(
                _selectedEmployee!['name'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${_selectedEmployee!['employee_id'] ?? '—'} - ${_selectedEmployee!['department'] ?? '—'}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: _clearSelection,
              ),
            ),
          )
        else
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الرقم أو القسم...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : _searchCtrl.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _results = []);
                },
              )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: _search,
          ),

        if (_results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final emp = _results[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      (emp['name'] ?? '?')[0],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(emp['name'] ?? '—'),
                  subtitle: Text(
                    '${emp['employee_id'] ?? '—'} | ${emp['department'] ?? '—'}',
                  ),
                  onTap: () => _selectEmployee(emp),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}