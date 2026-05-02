import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/partynameModal.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/monthly_target/services/api_services.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../product/widget/app_snack_bar.dart';

class SecondaryTargetView extends StatefulWidget {
  const SecondaryTargetView({super.key});

  @override
  State<SecondaryTargetView> createState() => _SecondaryTargetViewState();
}

class _SecondaryTargetViewState extends State<SecondaryTargetView> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _stockistController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedStockistCd;
  final _formKey = GlobalKey<FormState>();
  bool _loadingStockists = false;
  List<DatumPartyname> _stockists = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // show date as dd-MM-yyyy in UI
    _dateController.text = Helper.toUi(Helper.toApi(DateTime.now().toString()));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _stockistController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _openStockistPicker() async {
    if (_stockists.isEmpty && !_loadingStockists) {
      await _fetchStockists();
    }

    String search = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateModal) {
          final filtered = _stockists
              .where((s) =>
                  search.isEmpty ||
                  s.accName.toLowerCase().contains(search.toLowerCase()) ||
                  s.accCd.toLowerCase().contains(search.toLowerCase()))
              .toList();

          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Container(
              height: 500,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search stockist',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setStateModal(() {
                          search = val;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _loadingStockists
                        ? Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final item = filtered[idx];
                              return ListTile(
                                title: Text(item.accName),
                                subtitle: Text(item.accCd),
                                onTap: () {
                                  setState(() {
                                    _selectedStockistCd = item.accCd;
                                    _stockistController.text = item.accName;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _fetchStockists() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    var token = userProvider.token ?? '';
    if (!token.startsWith('Bearer ')) {
      token = 'Bearer $token';
    }

    setState(() {
      _loadingStockists = true;
    });

    try {
      final response = await http.get(
        Uri.parse(AppConfig.getStockistsURL),
        headers: {
          'Authorization': token,
          'x-app-type': 'oms',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is List) {
          setState(() {
            _stockists = data
                .whereType<Map>()
                .map((e) =>
                    DatumPartyname.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stockists = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingStockists = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Secondary Target',
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Target Date
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Target Month (date)',
                  hintText: 'Select date',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _dateController.text =
                          Helper.toUi(Helper.toApi(picked.toString()));
                    });
                  }
                },
              ),

              SizedBox(height: 12),

              // Secondary Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Secondary Amount',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter amount';
                  final num? parsed = num.tryParse(v.replaceAll(',', ''));
                  if (parsed == null) return 'Enter valid number';
                  return null;
                },
              ),

              SizedBox(height: 12),

              // Stockist (editable + clearable + picker)
              TextFormField(
                controller: _stockistController,
                decoration: InputDecoration(
                  labelText: 'Stockist',
                  hintText: 'Select stockist',
                  border: OutlineInputBorder(),
                  suffixIcon: _stockistController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _stockistController.clear();
                              _selectedStockistCd = null;
                            });
                          },
                        )
                      : IconButton(
                          icon: Icon(Icons.arrow_drop_down),
                          onPressed: _openStockistPicker,
                        ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Select stockist';
                  return null;
                },
                onTap: _openStockistPicker,
                onChanged: (val) {
                  setState(() {
                    if (val.trim().isEmpty) {
                      _selectedStockistCd = null;
                    } else {
                      // typing clears selected code
                      _selectedStockistCd = null;
                    }
                  });
                },
              ),

              SizedBox(height: 12),

              // Description (optional)
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 16),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final userProvider =
                        Provider.of<UserProvider>(context, listen: false);
                    final token = userProvider.token;
                    final api = Get.isRegistered<MonthlyTargetApiService>()
                        ? Get.find<MonthlyTargetApiService>()
                        : Get.put(MonthlyTargetApiService());

                    final sendDate = Helper.toApi(_dateController.text);
                    final stockistCd = _selectedStockistCd ?? '';
                    final desc = _descController.text.trim();
                    final amount =
                        num.parse(_amountController.text.replaceAll(',', ''));

                    final success = await api.saveSecondaryTarget(
                      targetDate: sendDate,
                      stockistCd: stockistCd,
                      targetDesc: desc.isEmpty ? null : desc,
                      secondaryAmount: amount,
                      token: token,
                    );

                    if (success) {
                      AppSnackBar.showGetXCustomSnackBar(
                          message: 'Secondary target saved',
                          backgroundColor: Colors.green);
                      Navigator.pop(context, true);
                    } else {
                      AppSnackBar.showGetXCustomSnackBar(
                          message: 'Failed to save',
                          backgroundColor: Colors.red);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
