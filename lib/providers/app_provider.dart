import 'package:flutter/cupertino.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
import 'package:arham_corporation/providers/item_list_provider.dart';
import 'package:arham_corporation/providers/order_fetch_provider.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/person_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:provider/provider.dart';

class AppProviders {
  static List<DisposableProvider> getDisposableProviders(BuildContext context) {
    return [
      Provider.of<CartListProvider>(context, listen: false),
      Provider.of<ItemListProvider>(context, listen: false),
      Provider.of<OrderFetchProvider>(context, listen: false),
      Provider.of<PartyProvider>(context, listen: false),
      Provider.of<PersonProvider>(context, listen: false),
      Provider.of<ProfileProvider>(context, listen: false)
    ];
  }

  static void disposeAllDisposableProviders(BuildContext context) {
    getDisposableProviders(context).forEach((disposableProvider) {
      disposableProvider.disposeValues();
    });
  }
}
