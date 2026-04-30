const { webkit } = require('@playwright/test');
(async () => {
  const browser = await webkit.launch({
    headless: true,
    logger: { isEnabled: () => true, log: (n,s,m,a)=>console.log(n,s,m) }
  });
  console.log("launched", browser.version());
  try {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    console.log("page ok");
    await browser.close();
  } catch (e) {
    console.log("ERR:", e.message);
  }
})();
