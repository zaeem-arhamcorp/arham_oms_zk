import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../helper/helper.dart';
import '../model/product_model.dart';

class ProductDetailPages extends StatefulWidget {
  final ProductItem data;

  const ProductDetailPages({super.key, required this.data});

  @override
  State<ProductDetailPages> createState() => _ProductDetailPagestate();
}

class _ProductDetailPagestate extends State<ProductDetailPages> {
  @override
  Widget build(BuildContext context) {
    final UserProvider ub = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: CustomAppBar(title: widget.data.itemName),
      // appBar: AppBar(
      //   elevation: 4,
      //   backgroundColor: Colors.white,
      //   iconTheme: const IconThemeData(color: Colors.black),
      //   title: Text(
      //     widget.data.itemName,
      //     style: TextStyle(
      //       color: Colors.black,
      //       fontWeight: FontWeight.bold,
      //       fontSize: 18.sp,
      //       letterSpacing: 0.5,
      //     ),
      //   ),
      //   centerTitle: true,
      //   shape: const RoundedRectangleBorder(
      //     borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      //   ),
      // ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSlideshow(),
              SizedBox(height: 10.h),

              /// **Basic Information**
              _buildInfoCard("Basic Information", [
                Row(
                  children: [
                    Text(
                      widget.data.itemCd,
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      " - ${widget.data.deptment.deptName}",
                      style: TextStyle(color: Colors.grey),
                    )
                  ],
                ),
                SizedBox(
                  height: 3.h,
                ),
                Text(
                  widget.data.itemName,
                  style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0),
                ),
                SizedBox(
                  height: 10,
                ),
                _buildDetailRow(Icons.code, "Item Code", widget.data.itemCd),
                _buildDetailRow(
                    Icons.qr_code_2, "Alternate Code", widget.data.itemCd2),
                _buildDetailRow(
                    Icons.category, "Category", widget.data.itemCat),
                _buildDetailRow(Icons.apartment, "Department",
                    widget.data.deptment.deptName),
                _buildDetailRow(
                    Icons.widgets, "Sub-Category", widget.data.subCat),
                _buildDetailRow(
                    Icons.branding_watermark, "Brand", widget.data.itemBrand),
                _buildDetailRow(Icons.medical_information, "Drug Contain",
                    widget.data.itemLname),
                _buildDetailRow(Icons.sync, "HSN Code", widget.data.hsnNo),
              ]),
              SizedBox(height: 8.h),

              /// **Pricing Details**
              _buildInfoCard("Pricing Details", [
                _buildConditionalRow(
                  Icons.attach_money,
                  "MRP",
                  Helper.parseNumericValue(widget.data.srate3),
                ),
                _buildConditionalRow(Icons.price_check, "Rate",
                    Helper.parseNumericValue(widget.data.srate1)),
                if (_canLabelSettings(context.read<ProfileProvider>()))
                  _buildConditionalRow(Icons.discount, "Discount",
                      Helper.parseNumericValue(widget.data.sdisc)),
                if (_canLabelSettings(context.read<ProfileProvider>()))
                  _buildConditionalRow(Icons.discount, "CD%",
                      Helper.parseNumericValue(widget.data.sdisc1)),
                _buildConditionalRow(
                    Icons.percent, "GST%", widget.data.gstPerc),
                if (_canLabelSettings(context.read<ProfileProvider>()))
                  _buildConditionalRow(Icons.local_offer, "Net Rate",
                      Helper.parseNumericValue(widget.data.nrate)),
                if (ub.role == AppConfig.masteruser) ...[
                  _buildConditionalRow(Icons.price_change, "Purch Rate",
                      Helper.parseNumericValue(widget.data.prate)),
                  _buildConditionalRow(Icons.percent, "Purch Disc",
                      Helper.parseNumericValue(widget.data.pdisc)),
                  _buildConditionalRow(
                      Icons.rate_review,
                      "Net Landing",
                      widget.data.tLAND!.isNotEmpty
                          ? Helper.parseNumericValue(widget.data.tLAND)
                          : 0),
                ],
              ]),
              SizedBox(height: 8.h),

              /// **Stock Details**
              _buildInfoCard("Stock and Other Details", [
                _buildDetailRow(Icons.inventory, "Closing Stk",
                    Helper.parseNumericValue(widget.data.cStk)),
                _buildDetailRow(Icons.inventory_2, "Available Stk",
                    Helper.parseNumericValue(widget.data.avlStk)),
                _buildDetailRow(Icons.storage, "Opening Stk",
                    Helper.parseNumericValue(widget.data.orStk)),
                if (widget.data.exDt != null)
                  _buildDetailRow(Icons.date_range, "Expiry Date",
                      Helper.toUi(widget.data.exDt.toString())),
                _buildDetailRow(Icons.view_list, "Rack", widget.data.rackNo),
                _buildDetailRow(Icons.grade, "Grade", widget.data.itemGrade),
                _buildDetailRow(
                    Icons.card_giftcard, "Bulk Scheme", widget.data.itemDesc),
                _buildDetailRow(
                    Icons.local_shipping, "Pack", widget.data.itemSname),
                _buildDetailRow(Icons.local_shipping, "Box Packing",
                    widget.data.itemBoxPacking),
                if (_canLabelSettings(context.read<ProfileProvider>()))
                  _buildDetailRow(
                      Icons.science, "Margin", widget.data.frmlSrt1),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// **Image Slideshow**
  Widget _buildImageSlideshow() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          widget.data.itemImages.isEmpty
              ? Image.asset(
                  'assets/nopreview.jpeg',
                  height: 250.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : ImageSlideshow(
                  height: 250.h,
                  indicatorColor: Colors.blueAccent,
                  autoPlayInterval: 3000,
                  isLoop: true,
                  children: widget.data.itemImages.map((image) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(image, fit: BoxFit.fitHeight),
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.white10,
                              // gradient: LinearGradient(
                              //   colors: [
                              //     Colors.black.withValues(alpha: 0.2),
                              //     Colors.transparent
                              //   ],
                              //   begin: Alignment.bottomCenter,
                              //   end: Alignment.topCenter,
                              // ),
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  /// **Info Card**
  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            Divider(color: Colors.grey[300]),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildConditionalRow(IconData icon, String label, dynamic value) {
    // Convert value to double for proper number comparison
    double? numValue = value == null ? null : double.tryParse(value.toString());

    if (value == null || value.toString().trim().isEmpty || numValue == 0) {
      return const SizedBox.shrink();
    }
    return _buildDetailRow(icon, label, value);
  }

  /// **Detail Row**
  Widget _buildDetailRow(IconData icon, String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty || value == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
          ),
          Flexible(
            child: Text(
              value.toString(),
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  /// **Conditional Row**
  /// **Conditional Row**
  ///

  bool _canLabelSettings(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            (element.variable == 'labelSettings' && element.value == 'Y')) ??
        false;
  }
}
