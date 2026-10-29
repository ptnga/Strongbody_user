# CLAUDE.md

StrongBody Buyer — Flutter app (package `strongbody_buyer`). Cấu trúc và quy ước **giống `../Multime_Version_2`**; khi cần mẫu cho pattern chưa có ở đây, tham chiếu module `chat_group` hoặc feature voice quota (`modules/iap/*voice_quota*`) bên Multime.

## Commands

See `README.md`. Flavors `dev`/`prod` trên Android (productFlavors) và iOS (scheme `dev`/`prod`, config `<Debug|Release|Profile>-<flavor>`, xcconfig `ios/Flutter/<config>.xcconfig`); 1 entry `lib/main.dart`, môi trường lấy từ `appFlavor`. Dev: app/bundle id thêm `.dev`, tên 'StrongBody Buyer Dev'.

## Structure

```
lib/
  main.dart (env từ --flavor), app.dart
  app/routers/            routers_name.dart (RouteName), app_router.dart (GoRouter)
  core/
    base/failure.dart     Failure + Network/Server/NotFound/Unauthorized
    bloc/                 BlocWithApi.callApi()
    usecases/             UseCase<T, Params>, NoParams
    network/              ApiClient.request(path:, method: ApiType.x, ...) — base URL đã có /v1,
                          tự gắn Bearer token + Scope: strongbody-ai
    di/locator.dart       GetIt; gọi registerXModule(getIt) của từng module
    domain/               GlobalStorage (Hive), `gs` accessor
    config/environment.dart  AppConfig (assets/env/.env.dev|.env.prod — không để secret)
    themes/, design_tokens/  Theme.of(context).primary(context), Colour.*
    constants/            ApiConst, AppConstants, AppSpacing
    components/           BaseAppBar, AppPrimaryButton
    l10n/locale_keys.g.dart  generated
  modules/<module>/
    data/{api_config,datasources/remote,models/{request,response},mappers,repositories}
    domain/{entities,repositories,usecases}
    presentation/{bloc/<feature>,screens,widgets}
    di/<module>_module.dart
  shared/widgets/, service/
```

## Conventions

- DTO `fromJson` viết tay → static Mapper → Entity (Equatable) → repository trả `Either<Failure, T>` (fpdart) → UseCase → Bloc.
- Bloc: `part` event/state; sealed Equatable events (`XStarted`, `XRequested`, `XChanged`); **một state** với `enum XStatus {initial, loading, success, failure}` + `copyWith`; getter `isFirstLoad` coi initial là loading; extend `BlocWithApi` khi gọi UseCase.
- DI: datasource/repo `registerLazySingleton`, UseCase/Bloc `registerFactory`, trong `modules/<m>/di/<m>_module.dart`.
- Route: thêm hằng vào `RouteName`, `GoRoute` với `BlocProvider(create: (_) => getIt<XBloc>()..add(...))`. `context.push/go`; `Navigator.pop` chỉ cho dialog/sheet.
- UI: ScreenUtil 375x812 (`.w/.h/.sp/.r`), `Gap`, `AppSpacing`, `LocaleKeys.x.tr()`, màu qua theme extension / `Colour` — không hardcode `Color(0x..)`. Log bằng `AppLogger`, không `print`. Spinner inline `CupertinoActivityIndicator`.
- Text mới: thêm key vào `assets/translations/en.json` + `vi.json`, rồi chạy lệnh generate LocaleKeys.

## Text style

Thang chữ giống Multime: `lib/core/themes/app_text_style.dart` (`AppTextStyle.lightBodyMediumRegular`, `lightHeadingSmall`…, hoặc `Theme.of(context).textTheme.lightBodyMediumBold`). Chỉ dùng token + `copyWith(color: ...)`; không tự đặt `fontSize`/`fontWeight` (cỡ 10/12/14/16/18, heading 20/24/32/40/48; weight tối đa 700). Màu chữ `Colour.textPrimary` #1F2D44 / `textSecondary` #738093 như Multime.
