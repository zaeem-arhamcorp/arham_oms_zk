import 'package:arham_corporation/views/reimbursement/create_expense_request.dart';
import 'package:arham_corporation/views/reimbursement/my_reimbursements_view.dart';
import 'package:arham_corporation/views/reimbursement/reimbursement_approvals_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GetExpenseView extends StatefulWidget {
  const GetExpenseView({super.key});

  @override
  State<GetExpenseView> createState() => _GetExpenseViewState();
}

class _GetExpenseViewState extends State<GetExpenseView> {
  @override
  void initState() {
    super.initState();
    debugPrint('[Reimbursement][GetExpense] Screen initialized');
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
            IconButton(
              onPressed: () {
                Get.to(() => CreateExpenseRequest());
              },
              icon: Icon(
                Icons.add,
              ),
            ),
          ],
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
        body: const TabBarView(
          children: [
            MyReimbursementsView(),
            ReimbursementApprovalsView(),
          ],
        ),
      ),
    );
  }
}
