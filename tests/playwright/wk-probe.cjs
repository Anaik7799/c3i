const { webkit } = require('@playwright/test');
(async () => {
  console.log("launching webkit...");
  const browser = await webkit.launch({ headless: true });
  console.log("launched", browser.version());
  const ctx = await browser.newContext();
  console.log("context");
  const page = await ctx.newPage();
  console.log("page");
  await page.goto('http://vm-1.tail55d152.ts.net:4100/planning');
  console.log("title=", await page.title());
  await browser.close();
})().catch(e => { console.error("ERR:", e.message); process.exit(1); });
