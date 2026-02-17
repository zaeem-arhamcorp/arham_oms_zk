import 'package:arham_corporation/views/narration/narration_controller.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NarrationView extends StatefulWidget {
  @override
  State<NarrationView> createState() => _NarrationViewState();
}

class _NarrationViewState extends State<NarrationView> {
  NarrationController controller = Get.put(NarrationController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBar(
        title: 'Narration ',
        actions: [
          IconButton(
            onPressed: () {
              controller.addNarration(context);
            },
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() => Column(
              children: [
                Expanded(child: _narrationView(context)),
              ],
            )),
      ),
    );
  }

  Widget _narrationView(BuildContext context) {
    return controller.isLoading.isTrue
        ? Center(
            child: CircularProgressIndicator(),
          )
        : controller.narrationList.value.data != null
            ? _narrationListUI(context)
            : Center(
                child: CommonText(
                  text: controller.narrationList.value.message != null
                      ? controller.narrationList.value.message!
                      : controller.errorMsg.value,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: Colors.black,
                ),
              );
  }

  Widget _narrationListUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: ListView.builder(
        itemCount: controller.narrationList.value.data!.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            //padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0X1C1F370D),
                  blurRadius: 4.0,
                  spreadRadius: 1.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(0XFF2c9ed9),
                child: CommonText(
                  text: controller.narrationList.value.data![index].nARRNAME!
                      .substring(0, 1)
                      .toUpperCase(),
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommonText(
                    //'${controller.narrationList.value.data![index].nARRNAME!} (${controller.narrationList.value.data![index].nARRID!})',
                    text: controller.narrationList.value.data![index].nARRNAME!,
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  CommonText(
                    text:
                        controller.narrationList.value.data![index].nARRTYPE ??
                            '',
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ],
              ),
              trailing: Visibility(
                visible: controller.updateRights.value ||
                    controller.deleteRights.value,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Visibility(
                      visible: controller.updateRights.value,
                      child: IconButton(
                        highlightColor: Colors.transparent,
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          controller.editDepartment(context, index);
                        },
                      ),
                    ),
                    Visibility(
                      visible: controller.deleteRights.value,
                      child: IconButton(
                        highlightColor: Colors.transparent,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context:
                            context,
                            builder:
                                (BuildContext
                            context) {
                              return AlertDialog(
                                title:
                                Text('Delete Confirmation'),
                                content:
                                Text('Are you sure you want to delete narration? - ${controller
                                    .narrationList.value.data![index].nARRNAME!
                                    .toString()}'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      // Cancel button: Close the dialog
                                      Get.back();
                                    },
                                    child: Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // Confirm logout
                                      controller.deleteNarration(
                                          context,
                                          controller
                                              .narrationList.value.data![index].nARRID!
                                              .toString(),
                                          controller
                                              .narrationList.value.data![index].nARRNAME!
                                              .toString());
                                    },
                                    child: Text('Yes'),
                                  ),
                                ],
                              );
                            },
                          );

                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
