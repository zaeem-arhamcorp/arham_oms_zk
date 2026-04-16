import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../models/productModal.dart';

class ProductDetailPage extends StatefulWidget {
  final DatumProduct data;

  const ProductDetailPage({Key? key, required this.data}) : super(key: key);

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final UserProvider ub = context.watch<UserProvider>();

    return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: CustomAppBar(title: "${widget.data.itemName}"),
        // appBar: AppBar(
        //   centerTitle: true,
        //   elevation: 0,
        //   backgroundColor: Colors.white,
        //   iconTheme: IconThemeData(color: Colors.black),
        //   title: Text(
        //     "${widget.data.itemName}",
        //     style: TextStyle(color: Colors.black),
        //   ),
        // ),
        // body: SafeArea(
        //   child: Container(
        //     height: size.height,
        //     width: size.width,
        //     child: ListView(
        //       padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 30),
        //       children: [
        //         GestureDetector(
        //           onTap: () {
        //             log(ub.token.toString());
        //           },
        //           child: ImageSlideshow(
        //               height: 280,
        //               indicatorColor: Colors.black,
        //               onPageChanged: (value) {},
        //               autoPlayInterval: 3000,
        //               isLoop: widget.data.itemImage == null ||
        //                       widget.data.itemImage!.itemImg.length == 1
        //                   ? false
        //                   : true,
        //               children: List.generate(
        //                   widget.data.itemImage != null
        //                       ? widget.data.itemImage!.itemImg.length
        //                       : 1, (index) {
        //                 return Container(
        //                   height: 400,
        //                   width: size.width,
        //                   decoration: BoxDecoration(
        //                     color: Colors.grey[200],
        //                     borderRadius: BorderRadius.circular(12),
        //                   ),
        //                   child: widget.data.itemImage == null
        //                       ? Image.asset(
        //                           Assets.assetsNopreview,
        //                           fit: BoxFit.cover,
        //                         )
        //                       : Image.network(
        //                           "${widget.data.itemImage!.itemImg[index]}",
        //                           fit: BoxFit.contain,
        //                         ),
        //                 );
        //               })),
        //         ),
        //         SizedBox(
        //           height: 20.h,
        //         ),
        //         SizedBox(
        //           height: 10.h,
        //         ),
        //         Row(
        //           children: [
        //             Text(
        //               "(${widget.data.itemCd})",
        //               style: TextStyle(color: Colors.grey),
        //             ),
        //             Text(
        //               " - ${widget.data.deptment?.DEPT_NAME}",
        //               style: TextStyle(color: Colors.grey),
        //             )
        //           ],
        //         ),
        //         SizedBox(
        //           height: 3.h,
        //         ),
        //         Text(
        //           "${widget.data.itemName}",
        //           style: TextStyle(
        //               fontSize: 19.sp,
        //               fontWeight: FontWeight.w800,
        //               letterSpacing: 1.0),
        //         ),
        //         SizedBox(
        //           height: 18.h,
        //         ),
        //         if (widget.data.itemCd2 != null)
        //           Row(
        //             children: [
        //               Text("Alternate Cd: "),
        //               Text(
        //                 "${widget.data.itemCd2}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.itemCd2 != null)
        //           SizedBox(
        //             height: 8.h,
        //           ),
        //         Row(
        //           children: [
        //             Row(
        //               children: [
        //                 Text("Closing Stock: "),
        //                 Text(
        //                   "${widget.data.cStk}",
        //                   style: TextStyle(color: Colors.grey),
        //                 ),
        //               ],
        //             ),
        //           ],
        //         ),
        //         SizedBox(
        //           height: 10.h,
        //         ),
        //         Row(
        //           children: [
        //             Text("Pack: "),
        //             Text(
        //               "${widget.data.itemSname}",
        //               style: TextStyle(color: Colors.grey),
        //             ),
        //           ],
        //         ),
        //         SizedBox(
        //           height: 10.h,
        //         ),
        //         Row(
        //           crossAxisAlignment: CrossAxisAlignment.start,
        //           children: [
        //             Text("Bulk Scheme: "),
        //             Flexible(
        //               child: Text(
        //                 "${widget.data.itemDesc}",
        //                 style: TextStyle(
        //                     color: Colors.grey, overflow: TextOverflow.visible),
        //               ),
        //             ),
        //           ],
        //         ),
        //         SizedBox(
        //           height: 10.h,
        //         ),
        //         Row(
        //           crossAxisAlignment: CrossAxisAlignment.start,
        //           children: [
        //             Text("Drug Contain: "),
        //             Flexible(
        //               child: Text(
        //                 "${widget.data.itemLname}",
        //                 style: TextStyle(
        //                     color: Colors.grey, overflow: TextOverflow.visible),
        //               ),
        //             ),
        //           ],
        //         ),
        //         if (widget.data.exDt != null)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.exDt != null)
        //           Row(
        //             children: [
        //               Text("Exp Dt: "),
        //               Text(
        //                 "${widget.data.exDt}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.gstPerc != null)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.gstPerc != null)
        //           Row(
        //             children: [
        //               Text("GST%: "),
        //               Text(
        //                 "${widget.data.gstPerc}%",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.srate3 != null && widget.data.srate3 != 0)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.srate3 != null && widget.data.srate3 != 0)
        //           Row(
        //             children: [
        //               Text("MRP: "),
        //               Text(
        //                 "${widget.data.srate3}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.srate1 != null && widget.data.srate1 != 0.0)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.srate1 != null && widget.data.srate1 != 0.0)
        //           Row(
        //             children: [
        //               Text("Rate: "),
        //               Text(
        //                 "${widget.data.srate1}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.sdisc != null && widget.data.sdisc != 0)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.sdisc != null && widget.data.sdisc != 0)
        //           Row(
        //             children: [
        //               Text("Disc: "),
        //               Text(
        //                 "${widget.data.sdisc}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.sdisc1 != null && widget.data.sdisc1 != 0)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.sdisc1 != null && widget.data.sdisc1 != 0)
        //           Row(
        //             children: [
        //               Text("Cd%: "),
        //               Text(
        //                 "${widget.data.sdisc1}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.nrate != null && widget.data.nrate != 0)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.nrate != null && widget.data.nrate != 0)
        //           Row(
        //             children: [
        //               Text("Net Rate: "),
        //               Text(
        //                 "${widget.data.nrate}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.frmlSrt1 != null)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.frmlSrt1 != null)
        //           Row(
        //             children: [
        //               Text("Margin: "),
        //               Text(
        //                 "${widget.data.frmlSrt1}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.prate != null &&
        //             ub.role == AppConfig.masteruser &&
        //             widget.data.prate != 0)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.prate != null &&
        //             ub.role == AppConfig.masteruser &&
        //             widget.data.prate != 0)
        //           Row(
        //             children: [
        //               Text("Pur. Rate: "),
        //               Text(
        //                 "${widget.data.prate}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.pDisc != null && widget.data.pDisc != 0)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.pDisc != null && widget.data.pDisc != 0)
        //           Row(
        //             children: [
        //               Text("P Disc: "),
        //               Text(
        //                 "${widget.data.pDisc}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.itemBrand != null)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.itemBrand != null)
        //           Row(
        //             children: [
        //               Text("Brand: "),
        //               Text(
        //                 "${widget.data.itemBrand}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.itemCat != null)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.itemCat != null)
        //           Row(
        //             children: [
        //               Text("Category: "),
        //               Text(
        //                 "${widget.data.itemCat}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.subCat != null)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.subCat != null)
        //           Row(
        //             children: [
        //               Text("Sub Category: "),
        //               Text(
        //                 "${widget.data.subCat}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.rackNo != null)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.rackNo != null)
        //           Row(
        //             children: [
        //               Text("Rack: "),
        //               Text(
        //                 "${widget.data.rackNo}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //         if (widget.data.itemGrade != null)
        //           SizedBox(
        //             height: 10.h,
        //           ),
        //         if (widget.data.itemGrade != null)
        //           Row(
        //             children: [
        //               Text("Grade: "),
        //               Text(
        //                 "${widget.data.itemGrade}",
        //                 style: TextStyle(color: Colors.grey),
        //               ),
        //             ],
        //           ),
        //       ],
        //     ),
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
                        "${widget.data.itemCd}",
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        " - ${widget.data.deptment?.DEPT_NAME ?? ''}",
                        style: TextStyle(color: Colors.grey),
                      )
                    ],
                  ),
                  SizedBox(
                    height: 3.h,
                  ),
                  Text(
                    "${widget.data.itemName}",
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
                      widget.data.deptment?.DEPT_NAME ?? ''),
                  _buildDetailRow(
                      Icons.widgets, "Sub-Category", widget.data.subCat),
                  _buildDetailRow(
                      Icons.branding_watermark, "Brand", widget.data.itemBrand),
                  _buildDetailRow(Icons.medical_information, "Drug Contain",
                      widget.data.itemLname),
                  _buildDetailRow(
                      Icons.sync, "HSN Code", widget.data.hsnNo ?? 'N/A'),
                ]),
                SizedBox(height: 8.h),

                /// **Pricing Details**
                _buildInfoCard("Pricing Details", [
                  _buildConditionalRow(
                    Icons.attach_money,
                    "MRP",
                    Helper.parseNumericValue(widget.data.srate3.toString()),
                  ),
                  _buildConditionalRow(Icons.price_check, "Rate",
                      Helper.parseNumericValue(widget.data.srate1.toString())),
                  if (_canLabelSettings(context.read<ProfileProvider>()))
                    _buildConditionalRow(Icons.discount, "Discount",
                        Helper.parseNumericValue(widget.data.sdisc.toString())),
                  if (_canLabelSettings(context.read<ProfileProvider>()))
                    _buildConditionalRow(
                        Icons.discount,
                        "CD%",
                        Helper.parseNumericValue(
                            widget.data.sdisc1.toString())),
                  _buildConditionalRow(
                      Icons.percent, "GST%", widget.data.gstPerc.toString()),
                  if (_canLabelSettings(context.read<ProfileProvider>()))
                    _buildConditionalRow(Icons.local_offer, "Net Rate",
                        Helper.parseNumericValue(widget.data.nrate.toString())),
                  if (ub.role == AppConfig.masteruser) ...[
                    _buildConditionalRow(Icons.price_change, "Purch Rate",
                        Helper.parseNumericValue(widget.data.prate.toString())),
                    _buildConditionalRow(Icons.percent, "Purch Disc",
                        Helper.parseNumericValue(widget.data.pDisc.toString())),
                    _buildConditionalRow(
                      Icons.rate_review,
                      "Net Landing",
                      widget.data.tLAND != null && widget.data.tLAND! > 0
                          ? Helper.parseNumericValue(
                              widget.data.tLAND!.toString())
                          : 0,
                    ),
                  ],
                ]),
                SizedBox(height: 8.h),

                /// **Stock Details**
                _buildInfoCard("Stock and Other Details", [
                  _buildDetailRow(Icons.inventory, "Closing Stk",
                      Helper.parseNumericValue(widget.data.cStk.toString())),
                  _buildDetailRow(Icons.inventory_2, "Available Stk",
                      Helper.parseNumericValue(widget.data.avlStk.toString())),
                  _buildDetailRow(Icons.storage, "Opening Stk",
                      Helper.parseNumericValue(widget.data.orStk.toString())),
                  if (widget.data.exDt != null)
                    _buildDetailRow(Icons.date_range, "Expiry Date",
                        Helper.toUi(widget.data.exDt.toString())),
                  _buildDetailRow(
                      Icons.view_list, "Rack", widget.data.rackNo.toString()),
                  _buildDetailRow(
                      Icons.grade, "Grade", widget.data.itemGrade.toString()),
                  _buildDetailRow(Icons.card_giftcard, "Bulk Scheme",
                      widget.data.itemDesc.toString()),
                  _buildDetailRow(Icons.local_shipping, "Pack",
                      widget.data.itemSname.toString()),
                  if (_canLabelSettings(context.read<ProfileProvider>()))
                    _buildDetailRow(Icons.science, "Margin",
                        widget.data.frmlSrt1.toString()),
                ]),
              ],
            ),
          ),
        ));
  }

  bool _canLabelSettings(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            (element.variable == 'labelSettings' && element.value == 'Y')) ??
        false;
  }

  /// **Image Slideshow**
  Widget _buildImageSlideshow() {
    final images = widget.data.itemImage?.itemImg;

    if (images == null || images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/nopreview.jpeg',
          height: 250.h,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ImageSlideshow(
        height: 250.h,
        indicatorColor: Colors.blueAccent,
        autoPlayInterval: 3000,
        isLoop: true,
        children: images.map((image) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(image, fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// **Info Card**
  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      color: Colors.white.withOpacity(0.95),
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
}
