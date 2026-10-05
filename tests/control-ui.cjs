'use strict';
const {chromium}=require(process.env.XLX_QA_PLAYWRIGHT || 'playwright');
const path=require('path');
const assert=require('assert/strict');
(async()=>{
 const root=path.resolve(process.argv[2]);
 const browser=await chromium.launch({headless:true});
 let checks=0;
 try {
  for(const locale of ['pt-BR','en','es','fr','de','it']) {
   for(const viewport of [{width:1440,height:900},{width:390,height:844}]) {
    const page=await browser.newPage({viewport});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    for(const view of ['home','health','access','radioid','login']) {
     await page.goto('file://'+path.join(root,locale+'-'+view+'.html'));
     assert.equal(await page.title(),'Control XLX123');
     assert.equal(await page.locator('html').getAttribute('lang'),locale);
     const dimensions=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));
     assert.ok(dimensions.scroll<=dimensions.width+1,`${locale} ${view} horizontal overflow ${JSON.stringify(dimensions)}`);
     assert.ok(!(await page.locator('body').innerText()).includes('XLX026'));
     if(view!=='login') {
      assert.equal(await page.locator('.control-nav a').count(),4);
      assert.equal(await page.locator('.control-nav .active').count(),1);
      const section={home:'#ia-server',health:'#health',access:'#access',radioid:'#radioid'}[view];
      assert.ok(await page.locator(section).isVisible());
     } else assert.equal(await page.locator('input[type=password]').count(),1);
     if(locale==='pt-BR') await page.screenshot({path:path.join(root,`${view}-${viewport.width}.png`),fullPage:true});
     checks++;
    }
    await page.goto('file://'+path.join(root,locale+'-home.html'));
    await page.locator('.control-nav a').nth(1).click();
    assert.ok(await page.locator('#health').isVisible());
    assert.deepEqual(errors,[]);
    await page.close();
   }
  }
  console.log(`CONTROL_UI=PASS (${checks} views; desktop/mobile; six locales; navigation)`);
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
