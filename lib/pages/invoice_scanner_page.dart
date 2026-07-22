import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';

class InvoiceScannerPage extends StatefulWidget {
  const InvoiceScannerPage({super.key});

  @override
  State<InvoiceScannerPage> createState() => _InvoiceScannerPageState();
}

class _InvoiceScannerPageState extends State<InvoiceScannerPage> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, // 恢復成不重複掃描模式，節省效能
    returnImage: false,
  );

  bool _isFlashOn = false;
  int _selectedModeIndex = 0;
  String? _scannedInvoiceNumber;
  String? _scannedInvoicePeriod;
  bool _hasScanned = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _handleScan(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      String? rawValue = barcode.rawValue;

      if (rawValue != null) {
        rawValue = rawValue.trim();

        // 💡 完美的台灣發票特徵判斷：大寫英文x2 + 數字x8 + 日期x7
        RegExp invoicePattern = RegExp(r'^([A-Z]{2})([0-9]{8})([0-9]{7})');
        Match? match = invoicePattern.firstMatch(rawValue);

        if (match != null) {
          String prefix = match.group(1)!;
          String numbers = match.group(2)!;
          String dateStr = match.group(3)!;

          String rocYear = dateStr.substring(0, 3);
          String monthStr = dateStr.substring(3, 5);

          int month = int.tryParse(monthStr) ?? 1;
          int periodStartMonth = ((month - 1) ~/ 2) * 2 + 1;
          String period = '$rocYear年 ${periodStartMonth.toString().padLeft(2, '0')}-${(periodStartMonth + 1).toString().padLeft(2, '0')}月';

          setState(() {
            _hasScanned = true;
            _scannedInvoiceNumber = '$prefix-$numbers';
            _scannedInvoicePeriod = period;
          });

          _cameraController.stop();
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("掃描新增發票", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {

          // 💡 恢復成原本專業的長方形掃描框比例
          final double scanWindowWidth = 280.0;
          final double scanWindowHeight = 150.0;

          final Rect scanWindow = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
            width: scanWindowWidth,
            height: scanWindowHeight,
          );

          return Stack(
            children: [
              // 1. 相機畫面
              MobileScanner(
                controller: _cameraController,
                scanWindow: scanWindow,
                onDetect: _handleScan,
              ),

              // 2. 閃光燈與聲音開關
              Positioned(
                top: 20,
                left: 20,
                child: IconButton(
                  icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 28),
                  onPressed: () async {
                    await _cameraController.toggleTorch();
                    setState(() => _isFlashOn = !_isFlashOn);
                  },
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.white, size: 28),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("提示音已開啟")));
                  },
                ),
              ),

              // 3. 掃描對準的綠色方框
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: scanWindowWidth,
                      height: scanWindowHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.safetyGreen, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        color: _hasScanned ? AppColors.safetyGreen.withOpacity(0.2) : Colors.transparent,
                      ),
                      child: _hasScanned
                          ? const Center(child: Icon(Icons.check_circle, color: AppColors.safetyGreen, size: 60))
                          : null,
                    ),
                    if (!_hasScanned && _selectedModeIndex == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Text("請將發票左側 QR Code 對準框內", style: TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                      ),
                  ],
                ),
              ),

              // 4. 底部模式切換 (未掃描時顯示)
              if (!_hasScanned)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeButton("電子發票", 0),
                      const SizedBox(width: 20),
                      _buildModeButton("傳統發票", 1),
                    ],
                  ),
                ),

              // 5. 底部結果面板 (掃描成功後滑出)
              if (_hasScanned)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("尚未開獎，請妥善保存紙本發票", style: TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 20),
                        Text(_scannedInvoicePeriod ?? "", style: const TextStyle(color: Colors.white, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(_scannedInvoiceNumber ?? "", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _hasScanned = false;
                                  _scannedInvoiceNumber = null;
                                });
                                _cameraController.start();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.textGrey),
                              child: const Text("重新掃描", style: TextStyle(color: Colors.white)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context, _scannedInvoiceNumber);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.actionBlue),
                              child: const Text("確認輸入", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeButton(String text, int index) {
    bool isSelected = _selectedModeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModeIndex = index;
        });
        if (index == 1) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("傳統發票掃描功能尚未實作")));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neutralWhite : AppColors.textGrey,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16
          ),
        ),
      ),
    );
  }
}
