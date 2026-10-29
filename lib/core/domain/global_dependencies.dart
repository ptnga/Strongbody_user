import 'package:get_it/get_it.dart';

import 'storages/global_storage.dart';

/// Truy cập nhanh storage toàn cục: `gs.accessToken`, `gs.isLoggedIn`...
GlobalStorage get gs => GetIt.I<GlobalStorage>();
