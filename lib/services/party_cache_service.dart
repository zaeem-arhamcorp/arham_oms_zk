import 'database_helper.dart';
import 'package:arham_corporation/models/partynameModal.dart';

class PartyCacheService {
  final DatabaseHelper db = DatabaseHelper();

  Future<void> cacheParties(List<DatumPartyname> partiesFromApi) async {
    List<Map<String, dynamic>> list = [];

    for (var p in partiesFromApi) {
      list.add({
        "server_id": p.accCd,
        "name": p.accName,
        "address": p.accAddress,
        "phone": p.mobile,
        "last_updated": DateTime.now().millisecondsSinceEpoch,
        "sync_status": 'synced'
      });
    }

    await db.insertParties(list);
  }

  Future<List<Map<String, dynamic>>> getParties() async {
    return await db.getParties();
  }

  Future<Map<String, dynamic>?> getPartyById(String serverId) async {
    final db = await DatabaseHelper().database;
    final results = await db.query(
      'parties',
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
    return results.isNotEmpty ? results.first : null;
  }
}
