import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/views/reimbursement/create_expense_request.dart';
import 'package:arham_corporation/views/reimbursement/my_reimbursements_view.dart';
import 'package:arham_corporation/views/reimbursement/reimbursement_approvals_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class GetExpenseView extends StatefulWidget {
  const GetExpenseView({super.key});

  @override
  State<GetExpenseView> createState() => _GetExpenseViewState();
}

class _GetExpenseViewState extends State<GetExpenseView> {
  late ProfileProvider p;

  @override
  void initState() {
    super.initState();
    debugPrint('[Reimbursement][GetExpense] Screen initialized');
    p = Provider.of<ProfileProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Reimbursement][GetExpense] Building tab layout');
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reimbursement'),
          foregroundColor: Colors.white,
          actions: [
            if (p.data!.modulesList!.any((module) =>
                module.mODULENO == "231" && module.wRITERIGHT == true))
              IconButton(
                onPressed: () {
                  Get.to(() => CreateExpenseRequest());
                },
                icon: Icon(
                  Icons.add,
                ),
              ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF0057E7),
                ],
              ),
            ),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'My Requests'),
              Tab(text: 'Approvals'),
            ],
          ),
        ),
        body: SafeArea(
          child: const TabBarView(
            children: [
              MyReimbursementsView(),
              ReimbursementApprovalsView(),
            ],
          ),
        ),
      ),
    );
  }
}
