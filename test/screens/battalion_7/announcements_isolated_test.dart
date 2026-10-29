import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/announcements/models/announcement_models.dart';
import 'package:gkk_flutter/screens/announcements/services/announcements_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('Sanity test for announcements models and repository', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AnnouncementsRepository repo = AnnouncementsRepository(prefs: prefs);
    await repo.init();
    expect(repo.isRead('test'), isFalse);
  });
}
