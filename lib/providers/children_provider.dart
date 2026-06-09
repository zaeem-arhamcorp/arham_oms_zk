import 'dart:convert';

import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/children_model.dart';

class ChildrenProvider extends ChangeNotifier {
  final List<Data> _users = [];

  List<Data> get users => _users;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  int _currentPage = 1;
  int _lastPage = 1;

  bool get hasMore => _currentPage < _lastPage;

  Future<void> loadUsers(
    BuildContext context, {
    bool refresh = false,
  }) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      if (refresh) {
        _currentPage = 1;
        _users.clear();
      }

      final ub = Provider.of<UserProvider>(
        context,
        listen: false,
      );

      final uri = Uri.parse(
        '${AppConfig.baseURL}users/children',
      ).replace(
        queryParameters: {
          'page': '1',
          'items_per_page': '20',
        },
      );
      print(uri);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${ub.token}',
          'x-app-type': 'oms',
        },
      );
      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;

        final model = ChildrenModel.fromJson(jsonMap);

        _users
          ..clear()
          ..addAll(model.data);

        final pagination = jsonMap['payload']?['pagination'];

        _currentPage = pagination?['page'] ?? 1;

        _lastPage = pagination?['last_page'] ?? 1;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(
    BuildContext context,
  ) async {
    if (_isLoadingMore || !hasMore) return;

    try {
      _isLoadingMore = true;
      notifyListeners();

      final nextPage = _currentPage + 1;

      final ub = Provider.of<UserProvider>(
        context,
        listen: false,
      );

      final uri = Uri.parse(
        '${AppConfig.baseURL}users/children',
      ).replace(
        queryParameters: {
          'page': nextPage.toString(),
          'items_per_page': '20',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${ub.token}',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body);

        final model = ChildrenModel.fromJson(jsonMap);

        _users.addAll(model.data);

        final pagination = jsonMap['payload']?['pagination'];

        _currentPage = pagination?['page'] ?? nextPage;

        _lastPage = pagination?['last_page'] ?? _lastPage;
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
