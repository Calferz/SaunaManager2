/**
 * Saunamanager2 用 Google Apps Script（スプレッドシート連携）
 *
 * アプリ（SheetsService.swift）からの POST を受けて、日付名のシート（yyyy/MM/dd）に
 * 入館・退館・更新・削除を記録します。doGet は在館状況を JSON で返します。
 *
 * セットアップ:
 *   1. スプレッドシートを作成し、「拡張機能 → Apps Script」にこのコードを貼り付ける
 *   2. 「デプロイ → 新しいデプロイ → ウェブアプリ」（実行：自分、アクセス：全員）
 *   3. 発行されたURLを、アプリの Saunamanager2/Config.swift の sheetsWebAppURL に設定する
 *
 * 補足: 過去データの一括修正に使った一度きりの整理用関数（水着列の整理・朝活プラン名の統一）は
 *       公開用のこのコピーには含めていません。
 */

const HEADER_ROW = [
  "番号", "日にち", "曜日", "入り", "出", "滞在時間",
  "プラン", "性別", "水着", "レンタル", "割引", "荷物預かり", "メモ"
];

const DAILY_SETTING_SHEET_NAME = "今日の設定";
const ASSIGNMENT_SHEET_NAME = "エリア設定";
const NORTH_CAPACITY = 12;
const SOUTH_CAPACITY = 14;

// ランニング中（サウナ未利用）の「ランステ」「ランステ＋通常利用」は在館人数に含めない
const RUNNING_PLANS = ["ランステ", "ランステ＋通常利用"];

// ---------- シート取得・作成 ----------

function getOrCreateSheet() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const today = Utilities.formatDate(new Date(), "Asia/Tokyo", "yyyy/MM/dd");
  let sheet = spreadsheet.getSheetByName(today);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(today);
    sheet.appendRow(HEADER_ROW);
    const header = sheet.getRange(1, 1, 1, HEADER_ROW.length);
    header.setFontWeight("bold");
    header.setBackground("#0f9d58");
    header.setFontColor("white");
    header.setHorizontalAlignment("center");
    header.setVerticalAlignment("middle");
  }
  sheet.getDataRange().setHorizontalAlignment("center");
  sheet.getDataRange().setVerticalAlignment("middle");
  return sheet;
}

function getSheetByDate(dateStr) {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  return spreadsheet.getSheetByName(dateStr);
}

function getOrCreateDailySettingSheet() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = spreadsheet.getSheetByName(DAILY_SETTING_SHEET_NAME);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(DAILY_SETTING_SHEET_NAME);
    sheet.appendRow([
      "日付", "北", "南",
      "アロマ（上）", "アロマ（下）",
      "サービス", "更新日時"
    ]);
    // デフォルト値を2行目に追加
    sheet.appendRow(["", "男", "女", "", "", "", ""]);
    const header = sheet.getRange(1, 1, 1, 7);
    header.setFontWeight("bold");
    header.setBackground("#0f9d58");
    header.setFontColor("white");
    header.setHorizontalAlignment("center");
  }
  return sheet;
}

// 北・南エリアの男女割り当て（エリア設定シート）。なければ作成する（2行目に北・南・更新日時）
function getOrCreateAssignmentSheet() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = spreadsheet.getSheetByName(ASSIGNMENT_SHEET_NAME);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(ASSIGNMENT_SHEET_NAME);
    sheet.appendRow(["北", "南", "更新日時"]);
    // デフォルト値を2行目に追加（北=男、南=女）
    sheet.appendRow(["男", "女", ""]);
    const header = sheet.getRange(1, 1, 1, 3);
    header.setFontWeight("bold");
    header.setBackground("#0f9d58");
    header.setFontColor("white");
    header.setHorizontalAlignment("center");
  }
  return sheet;
}

// ---------- 表記の補助 ----------

// 「ランステ＋通常利用」用：滞在時間セルを2行（ランニング／サウナ）で記録する
function formatMinutesJa(min) {
  const m = Math.max(0, Math.round(Number(min)));
  return Math.floor(m / 60) + "時間" + ("0" + (m % 60)).slice(-2) + "分";
}

function writeRunStePhases(sheet, targetRow, data) {
  if (data.runningMinutes === undefined || data.saunaMinutes === undefined) return;
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const stayCol = headers.indexOf("滞在時間") + 1;
  if (stayCol <= 0) return;
  const cell = sheet.getRange(targetRow, stayCol);
  cell.setValue("ランニング " + formatMinutesJa(data.runningMinutes) + "\nサウナ " + formatMinutesJa(data.saunaMinutes));
  cell.setWrap(true);
}

// 朝活プラン名を「朝活〜」（「＋」なし）に統一する。
// アプリのバージョンによって「＋軽食」「朝活＋軽食」等で届いても、必ずこの表記でシートに書き込む。
function normalizeMorningPlanName(plan) {
  const map = {
    "＋軽食": "朝活軽食", "＋ポンチョ": "朝活ポンチョ", "＋パック": "朝活パック", "＋ステッカー": "朝活ステッカー",
    "朝活＋軽食": "朝活軽食", "朝活＋ポンチョ": "朝活ポンチョ", "朝活＋パック": "朝活パック", "朝活＋ステッカー": "朝活ステッカー"
  };
  const key = String(plan).trim();
  return (key in map) ? map[key] : plan;
}

// ---------- POST（アプリからの書き込み） ----------

function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.tryLock(10000);

  try {
    const data = JSON.parse(e.postData.contents);
    if (data.plan !== undefined) {
      data.plan = normalizeMorningPlanName(data.plan);
    }
    Logger.log("受信データ action: " + data.action);

    if (data.action === "updateDailySetting") {
      const dailySheet = getOrCreateDailySettingSheet();

      const rowData = [
        data.date,
        data.northGender,
        data.southGender,
        data.upperAroma,
        data.lowerAroma,
        data.services,
        new Date()
      ];

      // 常に2行目に上書き
      dailySheet.getRange(2, 1, 1, rowData.length).setValues([rowData]);
      Logger.log("本日の設定を2行目に上書き: " + data.date);

      dailySheet.getDataRange().setHorizontalAlignment("center");
      dailySheet.getDataRange().setVerticalAlignment("middle");

      return ContentService
        .createTextOutput(JSON.stringify({ status: "ok" }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    if (data.action === "updateAssignment") {
      const assignSheet = getOrCreateAssignmentSheet();
      assignSheet.getRange(2, 1).setValue(data.northGender);
      assignSheet.getRange(2, 2).setValue(data.southGender);
      assignSheet.getRange(2, 3).setValue(new Date());
      Logger.log("エリア設定更新: 北=" + data.northGender + " 南=" + data.southGender);

      return ContentService
        .createTextOutput(JSON.stringify({ status: "ok" }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    const sheet = data.action === "checkin"
      ? getOrCreateSheet()
      : getSheetByDate(data.date);

    if (!sheet) {
      return ContentService
        .createTextOutput(JSON.stringify({ status: "error", message: "シートが見つかりません" }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    if (data.action === "checkin") {
      sheet.appendRow([
        data.lockerNumber,
        data.date,
        data.dayOfWeek,
        data.checkInTime,
        "",
        "",
        data.plan,
        data.gender,
        data.swimwearRental ? "あり" : "なし",
        data.rentalItems,
        data.discounts,
        data.storedItems,
        data.memo
      ]);
      const lastRow = sheet.getLastRow();
      sheet.getRange(lastRow, 6).setFormula(
        `=IF(E${lastRow}="","",TEXT(TIMEVALUE(E${lastRow})-TIMEVALUE(D${lastRow}),"H時間mm分ss秒"))`
      );

    } else if (data.action === "checkout") {
      const targetSheet = getSheetByDate(data.date) || sheet;
      const rows = targetSheet.getDataRange().getValues();
      const headers = targetSheet.getRange(1, 1, 1, targetSheet.getLastColumn()).getValues()[0];
      const checkOutCol = headers.indexOf("出") + 1;
      const checkInCol = headers.indexOf("入り");
      const planCol = headers.indexOf("プラン") + 1;
      const rentalCol = headers.indexOf("レンタル") + 1;

      // 同じロッカーで未退館の行のうち、最も新しい入館のものを対象にする
      const candidates = [];
      for (let i = 1; i < rows.length; i++) {
        if (String(rows[i][0]) == String(data.lockerNumber) &&
            rows[i][checkOutCol - 1] === "") {
          candidates.push({
            rowIndex: i,
            checkInTime: new Date(rows[i][checkInCol])
          });
        }
      }
      if (candidates.length > 0) {
        candidates.sort((a, b) => b.checkInTime - a.checkInTime);
        const targetRow = candidates[0].rowIndex + 1;
        targetSheet.getRange(targetRow, checkOutCol).setValue(data.checkOutTime);
        if (data.plan !== undefined) {
          targetSheet.getRange(targetRow, planCol).setValue(data.plan);
        }
        if (data.rentalItems !== undefined) {
          targetSheet.getRange(targetRow, rentalCol).setValue(data.rentalItems);
        }
        writeRunStePhases(targetSheet, targetRow, data);
        Logger.log("退館記録成功: 行" + targetRow);
      } else {
        Logger.log("該当行が見つかりません: " + data.lockerNumber);
      }

    } else if (data.action === "saunaStart") {
      // 「ランステ＋通常利用」でサウナ利用が始まったとき、プラン欄を「（サウナ中）」付きに更新する
      const rows = sheet.getDataRange().getValues();
      const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
      const checkOutCol = headers.indexOf("出");
      const checkInCol = headers.indexOf("入り");
      const planCol = headers.indexOf("プラン") + 1;
      const candidates = [];
      for (let i = 1; i < rows.length; i++) {
        if (String(rows[i][0]) == String(data.lockerNumber) && rows[i][checkOutCol] === "") {
          candidates.push({ rowIndex: i, checkInTime: new Date(rows[i][checkInCol]) });
        }
      }
      if (candidates.length > 0) {
        candidates.sort((a, b) => b.checkInTime - a.checkInTime);
        sheet.getRange(candidates[0].rowIndex + 1, planCol).setValue(data.plan);
        Logger.log("サウナ利用開始を記録: 行" + (candidates[0].rowIndex + 1));
      }

    } else if (data.action === "delete") {
      const rows = sheet.getDataRange().getValues();
      const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
      const checkInCol = headers.indexOf("入り");

      for (let i = 1; i < rows.length; i++) {
        const rowLocker = String(rows[i][0]).trim();
        const rowCheckIn = rows[i][checkInCol] instanceof Date
          ? Utilities.formatDate(rows[i][checkInCol], "Asia/Tokyo", "HH:mm:ss")
          : String(rows[i][checkInCol]).trim();

        if (rowLocker == String(data.lockerNumber).trim() &&
            rowCheckIn == String(data.checkInTime).trim()) {
          sheet.deleteRow(i + 1);
          Logger.log("削除成功: 行" + (i + 1));
          break;
        }
      }

    } else if (data.action === "update") {
      const rows = sheet.getDataRange().getValues();
      const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
      const checkInCol = headers.indexOf("入り");
      const lockerCol = headers.indexOf("番号");

      const originalLocker = data.originalLockerNumber || data.lockerNumber;
      const originalCheckIn = data.originalCheckInTime || data.checkInTime;

      for (let i = 1; i < rows.length; i++) {
        const rowLocker = String(rows[i][lockerCol]).trim();
        const rowCheckIn = rows[i][checkInCol] instanceof Date
          ? Utilities.formatDate(rows[i][checkInCol], "Asia/Tokyo", "HH:mm:ss")
          : String(rows[i][checkInCol]).trim();

        if (rowLocker == String(originalLocker).trim() &&
            rowCheckIn == String(originalCheckIn).trim()) {
          const targetRow = i + 1;
          sheet.getRange(targetRow, lockerCol + 1).setValue(data.lockerNumber);
          sheet.getRange(targetRow, headers.indexOf("入り") + 1).setValue(data.checkInTime);
          sheet.getRange(targetRow, headers.indexOf("出") + 1).setValue(data.checkOutTime);
          sheet.getRange(targetRow, headers.indexOf("プラン") + 1).setValue(data.plan);
          sheet.getRange(targetRow, headers.indexOf("性別") + 1).setValue(data.gender);
          sheet.getRange(targetRow, headers.indexOf("水着") + 1).setValue(data.swimwearRental ? "あり" : "なし");
          sheet.getRange(targetRow, headers.indexOf("レンタル") + 1).setValue(data.rentalItems);
          sheet.getRange(targetRow, headers.indexOf("割引") + 1).setValue(data.discounts);
          sheet.getRange(targetRow, headers.indexOf("荷物預かり") + 1).setValue(data.storedItems);
          sheet.getRange(targetRow, headers.indexOf("メモ") + 1).setValue(data.memo);
          writeRunStePhases(sheet, targetRow, data);
          Logger.log("更新成功: 行" + targetRow);
          break;
        }
      }
    }

    sheet.getDataRange().setHorizontalAlignment("center");
    sheet.getDataRange().setVerticalAlignment("middle");

    return ContentService
      .createTextOutput(JSON.stringify({ status: "ok" }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    Logger.log("エラー: " + err.message);
    return ContentService
      .createTextOutput(JSON.stringify({ status: "error", message: err.message }))
      .setMimeType(ContentService.MimeType.JSON);
  } finally {
    lock.releaseLock();
  }
}

// ---------- GET（在館状況の取得） ----------

// 未退館の客を集める。ランニング中のランステ利用者は一覧には含めるが、男女別の人数には数えない。
function collectActiveGuests(sheetObj) {
  const guests = [];
  let maleCount = 0;
  let femaleCount = 0;
  if (!sheetObj) return { guests: guests, maleCount: maleCount, femaleCount: femaleCount };

  const rows = sheetObj.getDataRange().getValues();
  const headers = rows[0];
  const lockerCol = headers.indexOf("番号");
  const checkInCol = headers.indexOf("入り");
  const checkOutCol = headers.indexOf("出");
  const planCol = headers.indexOf("プラン");
  const genderCol = headers.indexOf("性別");

  for (let i = 1; i < rows.length; i++) {
    const checkOut = rows[i][checkOutCol];
    if (checkOut === "") {
      const checkIn = rows[i][checkInCol] instanceof Date
        ? Utilities.formatDate(rows[i][checkInCol], "Asia/Tokyo", "HH:mm:ss")
        : String(rows[i][checkInCol]);
      const gender = String(rows[i][genderCol]);
      const isRunning = RUNNING_PLANS.indexOf(String(rows[i][planCol]).trim()) >= 0;
      if (!isRunning && gender === "男") maleCount++;
      if (!isRunning && gender === "女") femaleCount++;
      guests.push({
        locker: String(rows[i][lockerCol]),
        checkInTime: checkIn,
        plan: String(rows[i][planCol]),
        gender: gender
      });
    }
  }
  return { guests: guests, maleCount: maleCount, femaleCount: femaleCount };
}

function doGet(e) {
  const cache = CacheService.getScriptCache();
  const cached = cache.get("sauna_data");
  if (cached) {
    return ContentService
      .createTextOutput(cached)
      .setMimeType(ContentService.MimeType.JSON);
  }

  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const now = new Date();

  // 営業時間判定（7:30〜翌4:00）
  const hour = parseInt(Utilities.formatDate(now, "Asia/Tokyo", "H"));
  const minute = parseInt(Utilities.formatDate(now, "Asia/Tokyo", "m"));
  const totalMinutes = hour * 60 + minute;
  const isOpen = totalMinutes >= 450 || totalMinutes < 240;

  // 当日シート（実際の暦日）。深夜0:00〜4:00は日付をまたぐ前にチェックインした
  // お客様が前日シートに残っているため、前日シートも合わせて参照する
  const todayStr = Utilities.formatDate(now, "Asia/Tokyo", "yyyy/MM/dd");
  const sheet = spreadsheet.getSheetByName(todayStr);
  let previousSheet = null;
  if (totalMinutes < 240) {
    const prevDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const prevStr = Utilities.formatDate(prevDate, "Asia/Tokyo", "yyyy/MM/dd");
    previousSheet = spreadsheet.getSheetByName(prevStr);
  }

  // デフォルト値
  let northGender = "男";
  let southGender = "女";
  let upperAroma = "";
  let lowerAroma = "";
  let services = "";
  let lastUpdated = "";

  // 今日の設定シートの2行目から取得
  const dailySheet = getOrCreateDailySettingSheet();
  const dailyRows = dailySheet.getDataRange().getValues();
  if (dailyRows.length > 1) {
    northGender = String(dailyRows[1][1]).trim() || "男";
    southGender = String(dailyRows[1][2]).trim() || "女";

    if (isOpen) {
      upperAroma = String(dailyRows[1][3]);
      lowerAroma = String(dailyRows[1][4]);
      services   = String(dailyRows[1][5]);
    }

    if (dailyRows[1][6] instanceof Date) {
      lastUpdated = Utilities.formatDate(dailyRows[1][6], "Asia/Tokyo", "yyyy/MM/dd HH:mm");
    }
  }

  // 定員計算（北=12、南=14）。北・南それぞれの性別割り当てに応じて男女の定員に加算する
  let maleLimit = 0;
  let femaleLimit = 0;
  if (northGender === "男") maleLimit += NORTH_CAPACITY;
  if (northGender === "女") femaleLimit += NORTH_CAPACITY;
  if (southGender === "男") maleLimit += SOUTH_CAPACITY;
  if (southGender === "女") femaleLimit += SOUTH_CAPACITY;

  const base = {
    maleLimit: maleLimit,
    femaleLimit: femaleLimit,
    northGender: northGender,
    southGender: southGender,
    upperAroma: upperAroma,
    lowerAroma: lowerAroma,
    services: services,
    lastUpdated: lastUpdated,
    isOpen: isOpen
  };

  if (!sheet && !previousSheet) {
    return ContentService
      .createTextOutput(JSON.stringify(Object.assign({ guests: [], maleCount: 0, femaleCount: 0 }, base)))
      .setMimeType(ContentService.MimeType.JSON);
  }

  const current = collectActiveGuests(sheet);
  const previous = collectActiveGuests(previousSheet);

  const result = JSON.stringify(Object.assign({
    guests: current.guests.concat(previous.guests),
    maleCount: current.maleCount + previous.maleCount,
    femaleCount: current.femaleCount + previous.femaleCount
  }, base));

  // 30秒間キャッシュ
  cache.put("sauna_data", result, 30);

  return ContentService
    .createTextOutput(result)
    .setMimeType(ContentService.MimeType.JSON);
}

// ---------- シートの整理 ----------

// スプレッドシートを開いたとき、日付シートを新しい順に並べる
function onOpen() {
  sortSheetsByDate();
}

function sortSheetsByDate() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = spreadsheet.getSheets();

  const sheetList = sheets.map(sheet => {
    const name = sheet.getName();
    const date = new Date(name);
    return {
      sheet: sheet,
      timestamp: isNaN(date.getTime()) ? Infinity : date.getTime()
    };
  });

  sheetList.sort((a, b) => b.timestamp - a.timestamp);

  sheetList.forEach((item, index) => {
    spreadsheet.setActiveSheet(item.sheet);
    spreadsheet.moveActiveSheet(index + 1);
  });

  if (sheetList.length > 0) {
    spreadsheet.setActiveSheet(sheetList[0].sheet);
  }
}

function centerAlignAll() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = spreadsheet.getSheets();
  for (const sheet of sheets) {
    const range = sheet.getDataRange();
    range.setHorizontalAlignment("center");
    range.setVerticalAlignment("middle");
  }
}
