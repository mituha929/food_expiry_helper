import requests
from bs4 import BeautifulSoup
import firebase_admin
from firebase_admin import credentials
from firebase_admin import db
import os

# ==========================================
# 1. Firebase 初始化設定
# ==========================================
service_account_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
database_url = os.environ.get("FIREBASE_DATABASE_URL")

if not service_account_path:
    raise RuntimeError("請先設定 GOOGLE_APPLICATION_CREDENTIALS，指向 Firebase service account JSON 檔案。")

if not database_url:
    raise RuntimeError("請先設定 FIREBASE_DATABASE_URL，例如 https://your-project-id-default-rtdb.firebaseio.com/")

cred = credentials.Certificate(service_account_path)
firebase_admin.initialize_app(cred, {
    'databaseURL': database_url
})

def crawl_invoice_numbers(year, month):
    # 設定資料庫初始值 (對應 PHP 的 $date=$year.$month)
    date_str = f"{year}{month}"
    print(f"準備抓取期別: {date_str}")

    # 要抓取的網頁 (對應 PHP 的 $url)
    url = f"https://www.etax.nat.gov.tw/etw-main/ETW183W2_{year}{month}/"
    print(f"目標網址: {url}")

    # ==========================================
    # 2. 請求網頁與解析 (Requests + bs4)
    # ==========================================
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status() # 檢查 HTTP 狀態碼是否為 200
        response.encoding = 'utf-8' # 設置編碼為 UTF-8
        
    except requests.exceptions.RequestException as e:
        print(f"無法讀取網頁內容: {e}")
        return

    # 創建 BeautifulSoup 對象並加載 HTML
    soup = BeautifulSoup(response.text, 'html.parser')

    # 查找 class 包含 "col-12 mb-3" 的元素
    # bs4 可以很方便地用 class_ 參數來尋找
    elements = soup.find_all(class_=lambda x: x and 'col-12' in x and 'mb-3' in x)

    if not elements:
        print("找不到目標元素，可能網頁結構已改變或該期尚未開獎。")
        return

    # ==========================================
    # 3. 處理資料與寫入 Firebase Realtime Database
    # ==========================================
    # 建立一個 list 來儲存抓到的所有號碼，方便一次性寫入 Firebase
    receipt_numbers = []

    for element in elements:
        # 去除前後空白 (對應 PHP 的 trim)
        receipt_number = element.text.strip()
        print(f"抓取到號碼: {receipt_number}")
        
        # 排除空字串
        if receipt_number:
            receipt_numbers.append(receipt_number)

    # 將資料寫入 Firebase Realtime Database
    # 這裡我們將資料結構設計為： /receipt_number_prize/11311/ ["號碼1", "號碼2", ...]
    # 這樣在 NoSQL 資料庫中查詢與管理會比 SQL 的單行插入更有效率
    try:
        ref = db.reference(f'receipt_number_prize/{date_str}')
        
        # 使用 set() 會直接覆蓋該期別的舊資料，確保資料是最新的
        ref.set({
            "numbers": receipt_numbers,
            "update_status": "success"
        })
        print(f"✅ 期別 {date_str} 成功寫入 Firebase！共 {len(receipt_numbers)} 筆號碼。")
        
    except Exception as e:
        print(f"❌ 寫入 Firebase 失敗: {e}")


# ==========================================
# 4. 執行主程式
# ==========================================
if __name__ == "__main__":
    # 假設我們要抓取 113 年 05 月 (財政部的網址通常是用單數月代表該期，例如 11305 代表 5-6 月)
    target_year = "113"
    target_month = "05" 
    
    crawl_invoice_numbers(target_year, target_month)
