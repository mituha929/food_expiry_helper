import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final _db = FirebaseDatabase.instance.ref();
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? "test_user_id";

  Future<void> saveUserData(String email, String username) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _db.child('users').child(user.uid).update({
        'email': email,
        'username': username,
      });
    }
  }

  // 新增物品至 users/{uid}/items
  Future<String> addFoodItem(Map<String, dynamic> itemData) async {
    final newItemRef = _db.child('users').child(_uid).child('items').push();
    await newItemRef.set(itemData);
    return newItemRef.key ?? '';
  }

  Future<Map<String, dynamic>> getFoodItemsOnce() async {
    final snapshot = await _db.child('users').child(_uid).child('items').get();
    final value = snapshot.value;
    if (value is! Map) return {};

    final items = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.value is Map) {
        items[entry.key.toString()] = Map<String, dynamic>.from(entry.value as Map);
      }
    }
    return items;
  }

  // 💡 需求 8: 新增修改物品的方法
  Future<void> updateFoodItem(String itemId, Map<String, dynamic> itemData) async {
    await _db.child('users').child(_uid).child('items').child(itemId).update(itemData);
  }

  // 讀取該使用者的資料串流
  Stream<DatabaseEvent> getFoodStream() {
    return _db.child('users').child(_uid).child('items').onValue;
  }

  // 刪除特定物品
  Future<void> deleteItem(String itemId) async {
    await _db.child('users').child(_uid).child('items').child(itemId).remove();
  }
}
