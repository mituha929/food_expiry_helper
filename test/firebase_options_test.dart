import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_helper/firebase_options.dart';

void main() {
  test('Firebase 設定指向正確專案與 Realtime Database', () {
    final options = DefaultFirebaseOptions.android;

    expect(options.projectId, 'food-expiry-helper');
    expect(options.databaseURL, 'https://food-expiry-helper-default-rtdb.firebaseio.com');
    expect(options.apiKey, isNotEmpty);
    expect(options.appId, isNotEmpty);
    expect(options.messagingSenderId, isNotEmpty);
  });
}
