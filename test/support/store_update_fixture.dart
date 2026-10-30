import 'package:histae_app/features/updates/data/store_update_gateway.dart';

class FakeStoreUpdateGateway implements StoreUpdateGateway {
  StoreUpdate? available;
  bool failCheck = false, opens = true, disposed = false;
  int checks = 0, launches = 0;

  @override
  Future<StoreUpdate?> check() async {
    checks++;
    if (failCheck) throw StateError('Synthetic store outage');
    return available;
  }

  @override
  Future<bool> open(StoreUpdate update) async {
    launches++;
    return opens;
  }

  @override
  void dispose() => disposed = true;
}
