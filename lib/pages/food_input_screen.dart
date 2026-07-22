import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/local_database_service.dart';
import '../theme/app_colors.dart';
// 💡 匯入條碼掃描套件
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
// 在檔案最上方的 import 區塊加入這行
import 'invoice_scanner_page.dart';


class FoodInputScreen extends StatefulWidget {
  final String? itemId;
  final Map<dynamic, dynamic>? existingItem;
  final bool isLocalMode;

  const FoodInputScreen({
    super.key,
    this.itemId,
    this.existingItem,
    this.isLocalMode = false,
  });

  @override
  State<FoodInputScreen> createState() => _FoodInputScreenState();
}

class _FoodInputScreenState extends State<FoodInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();
  final LocalDatabaseService _localDbService = LocalDatabaseService();

  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _invoiceController = TextEditingController();
  // 💡 需求 2: 新增提醒天數控制器 (預設為 3 天)
  final _reminderDaysController = TextEditingController(text: '3');

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _nameController.text = widget.existingItem!['name'] ?? '';
      _barcodeController.text = widget.existingItem!['barcode'] ?? '';
      _priceController.text = widget.existingItem!['price']?.toString() ?? '';
      _invoiceController.text = widget.existingItem!['invoiceNum'] ?? '';
      // 💡 讀取舊有的提醒天數
      _reminderDaysController.text = widget.existingItem!['reminderDays']?.toString() ?? '3';

      try {
        String dateStr = widget.existingItem!['expiryDate'] ?? '';
        _selectedDate = DateTime.parse(dateStr.replaceAll('/', '-'));
      } catch (e) {
        _selectedDate = DateTime.now();
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final initialDate = _selectedDate.isBefore(todayClean) ? todayClean : _selectedDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: todayClean,
      lastDate: DateTime(2100),
      helpText: '請選擇有效日期',
      cancelText: '取消',
      confirmText: '確定',
      errorFormatText: '日期格式錯誤',
      errorInvalidText: '日期不可選',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    final Map<String, dynamic> itemData = {
      'name': _nameController.text.trim(),
      'expiryDate': DateFormat('yyyy/MM/dd').format(_selectedDate),
      'barcode': _barcodeController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'invoiceNum': _invoiceController.text.trim().toUpperCase(),
      // 💡 需求 2: 將提醒天數存入資料庫
      'reminderDays': int.tryParse(_reminderDaysController.text.trim()) ?? 3,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      if (widget.itemId == null) {
        itemData['createdAt'] = DateTime.now().toIso8601String();
        if (widget.isLocalMode) {
          await _localDbService.addFoodItem(itemData);
        } else {
          await _dbService.addFoodItem(itemData);
        }
      } else {
        if (widget.isLocalMode) {
          await _localDbService.updateFoodItem(widget.itemId!, itemData);
        } else {
          await _dbService.updateFoodItem(widget.itemId!, itemData);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isLocalMode
                  ? (widget.itemId == null ? "食物已暫存在本機！" : "本機暫存食物已修改！")
                  : (widget.itemId == null ? "食物新增成功！" : "食物修改成功！"),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("儲存失敗：$e")));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _invoiceController.dispose();
    _reminderDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.itemId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isLocalMode
              ? (isEditing ? "修改本機暫存食物" : "新增本機暫存食物")
              : (isEditing ? "修改食物紀錄" : "新增食物項目"),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (widget.isLocalMode) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryIceBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "目前為本機暫存模式。這筆資料尚未同步，不會寄送 Email 提醒；登入並上傳後才會啟用提醒。",
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
                const SizedBox(height: 15),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "食物名稱*", icon: Icon(Icons.fastfood)),
                validator: (value) => value == null || value.trim().isEmpty ? "請輸入食物名稱" : null,
              ),
              const SizedBox(height: 15),

              ListTile(
                title: Text("有效日期: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}"),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _selectDate(context),
                shape: RoundedRectangleBorder(side: const BorderSide(color: AppColors.textGrey), borderRadius: BorderRadius.circular(5)),
              ),
              const SizedBox(height: 15),

              // 💡 需求 2: 提醒天數輸入框
              TextFormField(
                controller: _reminderDaysController,
                decoration: const InputDecoration(
                    labelText: "到期前幾天提醒我？",
                    icon: Icon(Icons.notifications_active),
                    suffixText: "天"
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) return "請輸入提醒天數";

                  int? inputDays = int.tryParse(value);
                  if (inputDays == null || inputDays < 0) return "請輸入有效正整數";

                  // 💡 核心防呆：計算今天到有效日期之間，最多剩下幾天
                  DateTime todayClean = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                  DateTime expiryClean = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                  int maxDays = expiryClean.difference(todayClean).inDays;

                  // 如果選的日期是今天或已經過期，就不允許設定提前提醒（或最多只能設 0）
                  if (maxDays < 0) return "已過期的食物無法設定提醒";

                  // 如果輸入的提醒天數大於剩餘天數，就擋下來
                  if (inputDays > maxDays) {
                    return "不能大於距離過期的天數 (最多只能設 $maxDays 天)";
                  }

                  return null;
                },
              ),
              const SizedBox(height: 15),

              // 💡 條碼輸入框與掃描功能
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                    labelText: "條碼編號 (選填)",
                    icon: const Icon(Icons.qr_code_scanner),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt, color: AppColors.actionBlue),
                      onPressed: () async {
                        // 呼叫相機掃描
                        var res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SimpleBarcodeScannerPage(),
                          ),
                        );
                        // 如果掃描成功且不是取消 (-1)
                        if (res is String && res != '-1') {
                          setState(() {
                            _barcodeController.text = res;
                          });
                        }
                      },
                    )
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: "金額", icon: Icon(Icons.attach_money)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          double? price = double.tryParse(value);
                          if (price == null || price < 0) return "請輸入有效數字";
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    // 💡 發票輸入與 QR Code 智慧掃描功能
                    child: TextFormField(
                      controller: _invoiceController,
                      decoration: InputDecoration(
                          labelText: "發票號碼",
                          icon: const Icon(Icons.receipt_long),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code, color: AppColors.warningYellow),
                            onPressed: () async {
                              // 💡 呼叫剛剛做好的精美掃描頁面，並等待回傳結果
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const InvoiceScannerPage(),
                                ),
                              );

                              // 💡 如果有掃描成功並按下「確認輸入」，就把號碼填入文字框
                              if (result != null && result is String && mounted) {
                                setState(() {
                                  _invoiceController.text = result;
                                });
                              }
                            },
                          )
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: isEditing ? AppColors.warningYellow : AppColors.actionBlue,
                  foregroundColor: isEditing ? AppColors.textGrey : AppColors.neutralWhite,
                ),
                child: Text(isEditing ? "確認修改" : "確認儲存並同步", style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
