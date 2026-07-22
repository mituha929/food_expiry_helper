import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/local_database_service.dart';
import '../theme/app_colors.dart';
import 'food_input_screen.dart';

enum _MergeChoice { keepCloud, overwriteCloud, addAsNew }

class HomePage extends StatefulWidget {
  final bool isLocalMode;

  const HomePage({super.key, this.isLocalMode = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _dbService = DatabaseService();
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  int _currentIndex = 0;
  String _searchQuery = '';
  late Future<List<MapEntry<dynamic, dynamic>>> _localItemsFuture;
  bool _syncPromptShown = false;

  bool get _isLocalMode => widget.isLocalMode;

  String _normalizeName(dynamic value) => (value ?? '').toString().trim().toLowerCase();
  String _normalizeCode(dynamic value) => (value ?? '').toString().trim().toUpperCase();
  String _normalizeDate(dynamic value) => (value ?? '').toString().trim().replaceAll('-', '/');

  @override
  void initState() {
    super.initState();
    _localItemsFuture = _loadLocalEntries();

    if (!_isLocalMode && FirebaseAuth.instance.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskUploadLocalItems());
    }
  }

  Future<List<MapEntry<dynamic, dynamic>>> _loadLocalEntries() async {
    final items = await _localDbService.getFoodItems();
    return items
        .map((item) => MapEntry(item['id'].toString(), Map<dynamic, dynamic>.from(item)))
        .toList();
  }

  void _refreshLocalItems() {
    setState(() {
      _localItemsFuture = _loadLocalEntries();
    });
  }

  Future<void> _maybeAskUploadLocalItems() async {
    if (_syncPromptShown || !mounted) return;
    _syncPromptShown = true;

    final localCount = await _localDbService.getPendingCount();
    if (!mounted || localCount == 0) return;

    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("合併本機暫存資料？"),
        content: Text("偵測到 $localCount 筆本機暫存食物。是否要逐筆與雲端資料合併？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("稍後再說")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("開始合併")),
        ],
      ),
    );

    if (shouldUpload == true) {
      await _mergeLocalItems();
    }
  }

  MapEntry<String, Map<String, dynamic>>? _findPossibleDuplicate(
    Map<String, dynamic> localItem,
    Map<String, dynamic> cloudItems,
  ) {
    MapEntry<String, Map<String, dynamic>>? nameDateMatch;
    final localBarcode = _normalizeCode(localItem['barcode']);
    final localInvoice = _normalizeCode(localItem['invoiceNum']);
    final localName = _normalizeName(localItem['name']);
    final localDate = _normalizeDate(localItem['expiryDate']);

    for (final entry in cloudItems.entries) {
      final cloudItem = Map<String, dynamic>.from(entry.value as Map);
      final cloudBarcode = _normalizeCode(cloudItem['barcode']);
      final cloudInvoice = _normalizeCode(cloudItem['invoiceNum']);
      final cloudName = _normalizeName(cloudItem['name']);
      final cloudDate = _normalizeDate(cloudItem['expiryDate']);

      if (localBarcode.isNotEmpty && localBarcode == cloudBarcode) {
        return MapEntry(entry.key, cloudItem);
      }

      if (localInvoice.isNotEmpty && localInvoice == cloudInvoice) {
        return MapEntry(entry.key, cloudItem);
      }

      if (localName.isNotEmpty && localName == cloudName && localDate == cloudDate) {
        nameDateMatch ??= MapEntry(entry.key, cloudItem);
      }
    }

    return nameDateMatch;
  }

  Widget _buildMergeItemSummary(String title, Map item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutralWhite,
        border: Border.all(color: AppColors.textGrey.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("名稱：${item['name'] ?? '未命名'}"),
          Text("有效日期：${item['expiryDate'] ?? '無'}"),
          Text("提醒：${item['reminderDays'] ?? 3} 天"),
          Text("金額：${item['price'] ?? 0}"),
          Text("條碼：${_normalizeCode(item['barcode']).isEmpty ? '無' : item['barcode']}"),
          Text("發票：${_normalizeCode(item['invoiceNum']).isEmpty ? '無' : item['invoiceNum']}"),
        ],
      ),
    );
  }

  Future<_MergeChoice?> _showMergeChoiceDialog(
    Map<String, dynamic> localItem,
    Map<String, dynamic> cloudItem,
  ) {
    return showDialog<_MergeChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("可能重複的食物"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("請選擇這筆本機暫存資料要如何處理。"),
              const SizedBox(height: 16),
              _buildMergeItemSummary("本機", localItem),
              const SizedBox(height: 12),
              _buildMergeItemSummary("雲端", cloudItem),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _MergeChoice.keepCloud),
            child: const Text("保留雲端"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _MergeChoice.overwriteCloud),
            child: const Text("用本機覆蓋"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _MergeChoice.addAsNew),
            child: const Text("新增為另一筆"),
          ),
        ],
      ),
    );
  }

  Future<void> _mergeLocalItems() async {
    final processedLocalIds = <int>[];
    try {
      final localItems = await _localDbService.getFoodItems();
      final cloudItems = await _dbService.getFoodItemsOnce();
      var addedCount = 0;
      var overwrittenCount = 0;
      var keptCloudCount = 0;

      for (final localItem in localItems) {
        if (!mounted) return;

        final localId = localItem['id'] as int;
        final itemData = Map<String, dynamic>.from(localItem)..remove('id');
        itemData['updatedAt'] = DateTime.now().toIso8601String();

        final duplicate = _findPossibleDuplicate(itemData, cloudItems);
        if (duplicate == null) {
          final newItemId = await _dbService.addFoodItem(itemData);
          if (newItemId.isNotEmpty) cloudItems[newItemId] = itemData;
          processedLocalIds.add(localId);
          addedCount++;
          continue;
        }

        final choice = await _showMergeChoiceDialog(itemData, duplicate.value);
        if (choice == null) return;

        switch (choice) {
          case _MergeChoice.keepCloud:
            processedLocalIds.add(localId);
            keptCloudCount++;
            break;
          case _MergeChoice.overwriteCloud:
            await _dbService.updateFoodItem(duplicate.key, itemData);
            cloudItems[duplicate.key] = itemData;
            processedLocalIds.add(localId);
            overwrittenCount++;
            break;
          case _MergeChoice.addAsNew:
            final newItemId = await _dbService.addFoodItem(itemData);
            if (newItemId.isNotEmpty) cloudItems[newItemId] = itemData;
            processedLocalIds.add(localId);
            addedCount++;
            break;
        }
      }

      await _localDbService.deleteItems(processedLocalIds);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("合併完成：新增 $addedCount 筆，覆蓋 $overwrittenCount 筆，保留雲端 $keptCloudCount 筆。"),
        ),
      );
    } catch (e) {
      await _localDbService.deleteItems(processedLocalIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("本機資料合併失敗：$e")),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("登出確認"),
        content: const Text("是否確定要登出？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _authService.signOut();
            },
            child: const Text("確認", style: TextStyle(color: AppColors.dangerRed)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int daysLeft) {
    if (daysLeft < 0) return AppColors.dangerRed;
    if (daysLeft <= 3) return AppColors.warningYellow;
    return AppColors.safetyGreen;
  }

  List<MapEntry<dynamic, dynamic>> _prepareDisplayItems(Map<dynamic, dynamic> data) {
    final todayClean = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final validItems = <MapEntry<dynamic, dynamic>>[];
    final expiredItems = <MapEntry<dynamic, dynamic>>[];

    for (final entry in data.entries) {
      final item = Map<dynamic, dynamic>.from(entry.value as Map);
      final itemName = (item['name'] ?? '').toString().toLowerCase();

      if (_searchQuery.isNotEmpty && !itemName.contains(_searchQuery)) {
        continue;
      }

      final expiryStr = item['expiryDate'] ?? '';
      try {
        final expiry = DateTime.parse(expiryStr.toString().replaceAll('/', '-'));
        final daysLeft = expiry.difference(todayClean).inDays;
        item['daysLeft'] = daysLeft;

        if (daysLeft < 0) {
          expiredItems.add(MapEntry(entry.key, item));
        } else {
          validItems.add(MapEntry(entry.key, item));
        }
      } catch (e) {
        item['daysLeft'] = 999;
        validItems.add(MapEntry(entry.key, item));
      }
    }

    validItems.sort((a, b) => (a.value['expiryDate'] ?? '').compareTo(b.value['expiryDate'] ?? ''));
    expiredItems.sort((a, b) => (b.value['expiryDate'] ?? '').compareTo(a.value['expiryDate'] ?? ''));

    return _currentIndex == 0 ? validItems : expiredItems;
  }

  Widget _buildEmptyState() {
    final message = _searchQuery.isNotEmpty
        ? "找不到符合「${_searchController.text}」的食物"
        : _currentIndex == 0
            ? (_isLocalMode ? "目前沒有本機暫存食物。" : "目前冰箱空空的，趕快新增食物吧！")
            : "太棒了！目前沒有已過期的食物。";

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, style: const TextStyle(fontSize: 16, color: AppColors.textGrey)),
      ),
    );
  }

  void _showItemDetails(BuildContext context, String itemId, Map item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text(item['name'] ?? '未命名', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
              const Divider(height: 30, thickness: 1.5),
              if (_isLocalMode)
                const ListTile(
                  leading: Icon(Icons.phone_android, color: AppColors.textGrey),
                  title: Text("本機暫存資料"),
                  subtitle: Text("登入並上傳後才會啟用寄信提醒與跨裝置同步"),
                ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: AppColors.actionBlue),
                title: Text("有效期限：${item['expiryDate']}"),
                subtitle: Text("預計提前 ${item['reminderDays'] ?? 3} 天發送提醒"),
              ),
              ListTile(
                leading: const Icon(Icons.attach_money, color: AppColors.safetyGreen),
                title: Text("金額：\$${item['price'] ?? 0}"),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: AppColors.warningYellow),
                title: Text("發票號碼：${item['invoiceNum']?.isEmpty == true ? '無' : item['invoiceNum']}"),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code, color: AppColors.actionBlue),
                title: Text("條碼：${item['barcode']?.isEmpty == true ? '無' : item['barcode']}"),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FoodInputScreen(
                        itemId: itemId,
                        existingItem: item,
                        isLocalMode: _isLocalMode,
                      ),
                    ),
                  );
                  if (_isLocalMode) _refreshLocalItems();
                },
                icon: const Icon(Icons.edit),
                label: const Text("修改資訊", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.warningYellow,
                  foregroundColor: AppColors.textGrey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _restoreDeletedItem(Map<String, dynamic> itemData) async {
    if (_isLocalMode) {
      await _localDbService.addFoodItem(itemData);
      _refreshLocalItems();
    } else {
      await _dbService.addFoodItem(itemData);
    }
  }

  Future<void> _deleteItem(String itemId, Map item) async {
    final deletedItem = Map<String, dynamic>.from(item)..remove('daysLeft');
    if (_isLocalMode) {
      deletedItem.remove('id');
      await _localDbService.deleteItem(itemId);
      _refreshLocalItems();
    } else {
      await _dbService.deleteItem(itemId);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: const Color(0xFF1F2329),
        content: Text("已刪除「${deletedItem['name'] ?? '未命名'}」"),
        action: SnackBarAction(
          label: "復原",
          textColor: AppColors.primaryIceBlue,
          onPressed: () => _restoreDeletedItem(deletedItem),
        ),
      ),
    );
  }

  Widget _buildFoodList(Map<dynamic, dynamic>? data) {
    if (data == null || data.isEmpty) return _buildEmptyState();

    final displayItems = _prepareDisplayItems(data);
    if (displayItems.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final itemId = displayItems[index].key.toString();
        final item = displayItems[index].value as Map;
        final statusColor = _getStatusColor(item['daysLeft'] ?? 999);

        return Dismissible(
          key: Key("${_isLocalMode ? 'local' : 'remote'}-$itemId"),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            padding: const EdgeInsets.only(right: 20),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(color: AppColors.dangerRed, borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.delete, color: AppColors.neutralWhite, size: 30),
          ),
          onDismissed: (direction) => _deleteItem(itemId, item),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Container(
              decoration: BoxDecoration(border: Border(left: BorderSide(color: statusColor, width: 6))),
              child: ListTile(
                title: Text(item['name'] ?? '未命名', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text("${_isLocalMode ? '本機暫存，不會寄信 | ' : '📅 '}有效期限：${item['expiryDate']}"),
                trailing: Icon(
                  _isLocalMode
                      ? Icons.phone_android
                      : item['daysLeft'] < 0
                          ? Icons.warning_amber_rounded
                          : Icons.cloud_done,
                  color: _isLocalMode
                      ? AppColors.textGrey
                      : item['daysLeft'] < 0
                          ? AppColors.dangerRed
                          : AppColors.actionBlue,
                  size: 24,
                ),
                onTap: () => _showItemDetails(context, itemId, item),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListBody() {
    if (_isLocalMode) {
      return FutureBuilder<List<MapEntry<dynamic, dynamic>>>(
        future: _localItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("讀取本機暫存資料失敗: ${snapshot.error}"));
          }

          final entries = snapshot.data ?? [];
          return _buildFoodList(Map<dynamic, dynamic>.fromEntries(entries));
        },
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _dbService.getFoodStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("發生錯誤: ${snapshot.error}"));
        }

        final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
        return _buildFoodList(data);
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.subtleBackground,
      appBar: AppBar(
        title: Text(
          _isLocalMode ? "本機暫存食物" : "食間管理大師",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isLocalMode)
            TextButton.icon(
              icon: const Icon(Icons.login, color: AppColors.textGrey),
              label: const Text("登入", style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.logout, color: AppColors.textGrey),
              label: const Text("登出", style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
              onPressed: _showLogoutDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isLocalMode)
            Container(
              width: double.infinity,
              color: AppColors.primaryIceBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Text(
                "目前為本機暫存模式。登入後才能使用雲端清單、跨裝置同步與寄信提醒。",
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋食物名稱...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.neutralWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(child: _buildListBody()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.actionBlue,
        unselectedItemColor: AppColors.textGrey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "我的冰箱"),
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: "已過期食物"),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => FoodInputScreen(isLocalMode: _isLocalMode)),
          );
          if (_isLocalMode) _refreshLocalItems();
        },
        backgroundColor: AppColors.actionBlue,
        foregroundColor: AppColors.neutralWhite,
        label: Text(_isLocalMode ? "新增本機食物" : "新增食物"),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}
