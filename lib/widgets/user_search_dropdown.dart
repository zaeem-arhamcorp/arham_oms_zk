import 'package:flutter/material.dart';

class UserSearchDropdown extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final String? selectedUserCode;
  final ValueChanged<String?> onChanged;
  final bool loading;
  final String? hint;

  const UserSearchDropdown({
    Key? key,
    required this.users,
    required this.selectedUserCode,
    required this.onChanged,
    this.loading = false,
    this.hint,
  }) : super(key: key);

  @override
  State<UserSearchDropdown> createState() => _UserSearchDropdownState();
}

class _UserSearchDropdownState extends State<UserSearchDropdown> {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  late OverlayEntry _overlayEntry;
  bool _isDropdownOpen = false;
  late List<Map<String, dynamic>> _filteredUsers;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
    _filteredUsers = widget.users;

    _focusNode.addListener(_onFocusChange);
    _searchController.addListener(_onSearchChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_isDropdownOpen) {
      _showDropdown();
    } else if (!_focusNode.hasFocus && _isDropdownOpen) {
      _hideDropdown();
    }
  }

  void _onSearchChange() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = widget.users;
      } else {
        _filteredUsers = widget.users.where((user) {
          final name = (user['userName'] ?? '').toString().toLowerCase().trim();
          final phone = (user['phone'] ?? '').toString().toLowerCase().trim();
          return name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  void _showDropdown() {
    if (_isDropdownOpen) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry);
    _isDropdownOpen = true;
  }

  void _hideDropdown() {
    if (!_isDropdownOpen) return;
    _overlayEntry.remove();
    _isDropdownOpen = false;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height,
        width: size.width,
        child: Material(
          elevation: 4,
          child: ValueListenableBuilder(
            valueListenable: _searchController,
            builder: (context, text, child) {
              // Calculate dynamic height based on current filtered users
              final itemHeight = 40.0; // Height per item including padding
              final numberOfItems =
                  _filteredUsers.length + 1; // +1 for "All Users"
              final calculatedHeight =
                  (numberOfItems * itemHeight) + 12; // +12 for padding
              final maxScreenHeight = MediaQuery.of(context).size.height / 2;
              final maxHeight = calculatedHeight > maxScreenHeight
                  ? maxScreenHeight
                  : calculatedHeight;

              return Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _filteredUsers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('No users found'),
                      )
                    : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            child: GestureDetector(
                              onTap: widget.loading
                                  ? null
                                  : () {
                                      _searchController.clear();
                                      widget.onChanged('');
                                      _focusNode.unfocus();
                                    },
                              child: Text('All Users',
                                  style: TextStyle(
                                    fontWeight:
                                        widget.selectedUserCode?.isEmpty == true
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  )),
                            ),
                          ),
                          ..._filteredUsers.map((user) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 8.0),
                              child: GestureDetector(
                                onTap: widget.loading
                                    ? null
                                    : () {
                                        _searchController.text =
                                            user['userName'] ?? '';
                                        widget.onChanged(user['userCode']);
                                        _focusNode.unfocus();
                                      },
                                child: Text(
                                  '${user['userName']} (${user['phone']})',
                                  style: TextStyle(
                                    fontWeight: widget.selectedUserCode ==
                                            user['userCode']
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    if (_isDropdownOpen) {
      _overlayEntry.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _searchController,
      builder: (context, text, child) {
        return TextField(
          controller: _searchController,
          focusNode: _focusNode,
          enabled: !widget.loading,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint ?? 'Search and select user',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _focusNode.unfocus();
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}
