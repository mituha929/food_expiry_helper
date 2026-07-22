/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

/*
const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
*/
// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
//setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// 修改這行，明確指定使用 v1 介面
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

const TAIPEI_TIME_ZONE = "Asia/Taipei";

function getTaipeiDateParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: TAIPEI_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);

  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
}

function formatTaipeiDate(date = new Date(), separator = "/") {
  const {year, month, day} = getTaipeiDateParts(date);
  return [
    year,
    String(month).padStart(2, "0"),
    String(day).padStart(2, "0"),
  ].join(separator);
}

function parseStoredExpiryDate(expiryDate) {
  if (typeof expiryDate !== "string") return null;
  const match = expiryDate.match(/^(\d{4})[/-](\d{2})[/-](\d{2})$/);
  if (!match) return null;

  const [, year, month, day] = match;
  const parsed = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function getDaysLeftFromTaipeiToday(expiryDate) {
  const expiry = parseStoredExpiryDate(expiryDate);
  if (!expiry) return null;

  const today = getTaipeiDateParts();
  const taipeiToday = new Date(Date.UTC(today.year, today.month - 1, today.day));
  return Math.round((expiry.getTime() - taipeiToday.getTime()) / 86400000);
}

function createMailTransporter() {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.GMAIL_USER,
      pass: process.env.GMAIL_PASS,
    },
  });
}

function buildReminderItems(items = {}) {
  return Object.values(items)
    .map((item) => ({
      name: item.name || "未命名食物",
      expiryDate: item.expiryDate,
      reminderDays: Number.isInteger(Number(item.reminderDays)) ? Number(item.reminderDays) : 3,
      daysLeft: getDaysLeftFromTaipeiToday(item.expiryDate),
    }))
    .filter((item) => item.daysLeft !== null && item.daysLeft >= 0);
}

function buildReminderListHtml(items) {
  if (items.length === 0) {
    return "<p>目前沒有即將到期或今天到期的食物。</p>";
  }

  return `<ul>${items.map((item) => {
    const status = item.daysLeft === 0 ? "今天到期" : `${item.daysLeft} 天後到期`;
    return `<li>${item.name}：${status}，有效期限 ${item.expiryDate}</li>`;
  }).join("")}</ul>`;
}

// 這裡維持原樣，但現在它能正確找到 runWith 了
exports.dailyExpiryCheck = functions
  .runWith({
    secrets: ["GMAIL_USER", "GMAIL_PASS"],
    timeoutSeconds: 300,
    memory: "256MB"
  })
  .pubsub.schedule("0 8 * * *") // 每天早上 8:00 執行
  .timeZone(TAIPEI_TIME_ZONE)
  .onRun(async (context) => {
    const todayStr = formatTaipeiDate(new Date(), "/");
    const usersRef = admin.database().ref("users");
    const snapshot = await usersRef.once("value");
    const usersData = snapshot.val();

    if (!usersData) {
      console.log("資料庫中無使用者資料。");
      return null;
    }

    const transporter = createMailTransporter();

    const emailPromises = [];

    for (const uid in usersData) {
      const items = usersData[uid].items;
      if (!items) continue;

      const reminderItems = buildReminderItems(items)
        .filter((item) => item.daysLeft === 0 || item.daysLeft === item.reminderDays);

      if (reminderItems.length > 0) {
        const targetEmail = usersData[uid].email || process.env.GMAIL_USER;
        const mailOptions = {
          from: "食物效期助手",
          to: targetEmail,
          subject: `⚠️ 食物效期提醒：有 ${reminderItems.length} 件物品需要留意`,
          html: `<p>您好，以下是您在 ${todayStr} 需要留意的食物：</p>
                 ${buildReminderListHtml(reminderItems)}`,
        };
        emailPromises.push(transporter.sendMail(mailOptions));
      }
    }

    try {
      await Promise.all(emailPromises);
      console.log("通知發送完畢。");
    } catch (error) {
      console.error("發信失敗:", error);
    }
    return null;
  });
