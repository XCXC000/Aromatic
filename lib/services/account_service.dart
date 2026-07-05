import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';

class AccountService {
  static const _key = 'aromatic_accounts_v2';
  final _uuid = const Uuid();

  // ==================== 账户 ====================

  Future<List<LocalAccount>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => LocalAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAll(List<LocalAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  Future<LocalAccount> addAccount(String name) async {
    final accounts = await loadAll();
    final account = LocalAccount(
      id: _uuid.v4(),
      name: name,
      keychains: [
        Keychain(id: _uuid.v4(), name: '默认模型串'),
      ],
    );
    accounts.add(account);
    await _saveAll(accounts);
    return account;
  }

  Future<void> deleteAccount(String accountId) async {
    final accounts = await loadAll();
    accounts.removeWhere((a) => a.id == accountId);
    await _saveAll(accounts);
  }

  Future<void> renameAccount(String accountId, String newName) async {
    final accounts = await loadAll();
    final acc = accounts.firstWhere((a) => a.id == accountId);
    acc.name = newName;
    await _saveAll(accounts);
  }

  // ==================== 模型串 ====================

  Future<void> addKeychain(String accountId, String name) async {
    final accounts = await loadAll();
    final acc = accounts.firstWhere((a) => a.id == accountId);
    acc.keychains.add(Keychain(id: _uuid.v4(), name: name));
    await _saveAll(accounts);
  }

  Future<void> deleteKeychain(String accountId, String keychainId) async {
    final accounts = await loadAll();
    final acc = accounts.firstWhere((a) => a.id == accountId);
    acc.keychains.removeWhere((kc) => kc.id == keychainId);
    await _saveAll(accounts);
  }

  // ==================== 模型 ====================

  Future<void> addKey(
      String accountId, String keychainId, ApiKey key) async {
    final accounts = await loadAll();
    final acc = accounts.firstWhere((a) => a.id == accountId);
    final kc = acc.keychains.firstWhere((k) => k.id == keychainId);
    // 如果新模型设为活跃，取消同模型串内其他活跃
    if (key.isActive) {
      for (final k in kc.keys) {
        k.isActive = false;
      }
    }
    kc.keys.add(key);
    await _saveAll(accounts);
  }

  Future<void> updateKey(
      String accountId, String keychainId, ApiKey updated) async {
    final accounts = await loadAll();
    final acc = accounts.firstWhere((a) => a.id == accountId);
    final kc = acc.keychains.firstWhere((k) => k.id == keychainId);
    final idx = kc.keys.indexWhere((k) => k.id == updated.id);
    if (idx == -1) return;
    if (updated.isActive) {
      for (final k in kc.keys) {
        k.isActive = false;
      }
    }
    kc.keys[idx] = updated;
    await _saveAll(accounts);
  }

  Future<void> deleteKey(
      String accountId, String keychainId, String keyId) async {
    final accounts = await loadAll();
    final acc = accounts.firstWhere((a) => a.id == accountId);
    final kc = acc.keychains.firstWhere((k) => k.id == keychainId);
    kc.keys.removeWhere((k) => k.id == keyId);
    await _saveAll(accounts);
  }

  Future<void> setKeyActive(
      String accountId, String keychainId, String keyId) async {
    final accounts = await loadAll();
    final acc = accounts.firstWhere((a) => a.id == accountId);
    final kc = acc.keychains.firstWhere((k) => k.id == keychainId);
    for (final k in kc.keys) {
      k.isActive = k.id == keyId;
    }
    await _saveAll(accounts);
  }

  // ==================== 查询 ====================

  /// 获取所有活跃模型（跨所有账户和模型串）
  Future<List<ApiKey>> getAllActiveKeys() async {
    final accounts = await loadAll();
    final result = <ApiKey>[];
    for (final acc in accounts) {
      for (final kc in acc.keychains) {
        for (final key in kc.keys) {
          if (key.isActive) result.add(key);
        }
      }
    }
    return result;
  }

  /// 云端同步预留
    Future<void> renameKeychain(String accountId, String keychainId, String newName) async {
    final accounts = await loadAll();
    final acc = accounts.firstWhere((a) => a.id == accountId);
    final kc = acc.keychains.firstWhere((k) => k.id == keychainId);
    kc.name = newName;
    await _saveAll(accounts);
  }

  Future<void> syncToCloud() async {}
}
