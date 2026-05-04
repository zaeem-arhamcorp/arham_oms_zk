import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/views/party_managment/bindings/account_bindings.dart';
import 'package:arham_corporation/views/party_managment/screens/add_account_screen.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadParties());
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    final partyProvider = context.read<PartyProvider>();
    // Load all parties across beats using report/party?groupCd=85
    await partyProvider.getPartyNameReportGroup85(context);
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  List get _filteredData {
    final partyProvider = context.read<PartyProvider>();
    if (_searchQuery.isEmpty) {
      return partyProvider.data;
    }
    return partyProvider.data
        .where((party) =>
            party.accName.toLowerCase().contains(_searchQuery) ||
            party.accCd.toLowerCase().contains(_searchQuery) ||
            (party.person_nm?.toLowerCase().contains(_searchQuery) ?? false) ||
            party.mobile.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final partyProvider = context.watch<PartyProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final canEditParty = Helper.canEditParty(profileProvider);
    final canAddParty = Helper.canAddParty(profileProvider);
    final filteredData = _filteredData;

    return Scaffold(
      appBar: CustomAppBar(
        title: "Accounts",
        actions: [
          if (canAddParty)
            IconButton(
              onPressed: () {
                Get.to(() => AddAccountScreen(), binding: AccountBindings());
              },
              icon: Icon(Icons.add),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, code, contact...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadParties,
                    child: filteredData.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: 120),
                              Center(
                                child: Text(_searchQuery.isEmpty
                                    ? 'No parties found'
                                    : 'No parties match your search'),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredData.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              return Helper.showPartyBottomSheetWithSearch(
                                index,
                                filteredData,
                                showEditButton: canEditParty,
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
