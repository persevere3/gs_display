import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseCrashService {
  static final FirebaseCrashService _instance = FirebaseCrashService._internal();
  factory FirebaseCrashService() => _instance;
  FirebaseCrashService._internal();

  Future<void> init() async {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // 確保開啟收集
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  }

  /// 上報 Socket 連線異常並嘗試立即上傳
  Future<void> recordSocketError(Object e) async {
    await FirebaseCrashlytics.instance.recordError(
      e,
      null,
      reason: 'SocketException – 無法連線',
      fatal: false,
    );

    // 👇 嘗試立即上傳（如果網路可用）
    await _trySendReports();
  }

  /// 上報任意異常並立即上傳
  Future<void> recordCustomError(dynamic error, StackTrace? stack, String reason) async {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      fatal: false,
    );

    await _trySendReports();
  }

  /// 嘗試立即上傳未傳送的報告
  Future<void> _trySendReports() async {
    try {
      // 如果網路可用 → 立即上傳
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        await FirebaseCrashlytics.instance.sendUnsentReports();
      } else {
        // 網路不通 → 等下次啟動自動上傳
        debugPrint('🌐 無法上傳報告，將於下次啟動時送出');
      }
    } catch (_) {
      debugPrint('🌐 無法上傳報告（網路異常），暫存至下次上傳');
    }
  }
}