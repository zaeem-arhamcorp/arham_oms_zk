import 'package:arham_corporation/views/referral/controllers/referral_earnings_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReferralEarningsView extends StatefulWidget {
  const ReferralEarningsView({super.key});

  @override
  State<ReferralEarningsView> createState() => _ReferralEarningsViewState();
}

class _ReferralEarningsViewState extends State<ReferralEarningsView> {
  final ReferralEarningsController controller =
      Get.put(ReferralEarningsController());

  Future<void> _onClaimPressed(int pendingAmount) async {
    String paymentMethod = 'upi';

    final selectedMethod = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Payment Method'),
          content: DropdownButtonFormField<String>(
            value: paymentMethod,
            items: const [
              DropdownMenuItem(value: 'upi', child: Text('UPI')),
              DropdownMenuItem(value: 'bank', child: Text('Bank')),
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
            ],
            onChanged: (value) {
              if (value != null) {
                paymentMethod = value;
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(paymentMethod),
              child: const Text('Claim'),
            ),
          ],
        );
      },
    );

    if (selectedMethod == null) return;

    await controller.claimReward(
      amount: pendingAmount.toString(),
      paymentMethod: selectedMethod,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchReferralEarnings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Referral Earnings',
          style: TextStyle(color: Colors.white),
        ),
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
      ),
      body: SafeArea(
        child: Obx(
          () {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = controller.earningsResponse.value?.data;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.white,
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.2),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    // color: Color(0xfffafafa),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    // boxShadow: const [
                    //   BoxShadow(
                    //     color: Colors.black26,
                    //     blurRadius: 10,
                    //     offset: Offset(0, 6),
                    //   ),
                    // ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Earnings',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data != null ? '₹${data.totalEarnings}' : '--',
                        style: const TextStyle(
                          // color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data != null
                            ? 'Paid: ₹${data.paidEarnings} | Pending: ₹${data.pendingEarnings}'
                            : 'No earnings yet',
                        style: const TextStyle(
                          // color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data != null
                            ? 'Total referrals: ${data.totalReferrals} | Successful: ${data.successfulReferrals}'
                            : '',
                        style: const TextStyle(
                          // color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
