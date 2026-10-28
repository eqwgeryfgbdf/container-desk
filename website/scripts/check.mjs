import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const base=process.env.SITE_URL || 'http://localhost:8796';
const out=new URL('../../../work/website-qa/',import.meta.url);
await mkdir(out,{recursive:true});
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const results=[];
try {
 for (const width of [1440,768,390,320]) {
  for (const path of ['/','/en/','/zh-Hans/']) {
   const page=await browser.newPage({viewport:{width,height:1000},reducedMotion:'reduce'});
   await page.addInitScript(() => localStorage.setItem('container-desk.language.v1', location.pathname.startsWith('/en') ? 'en' : location.pathname.startsWith('/zh-Hans') ? 'zh-Hans' : 'zh-Hant'));
   const errors=[]; page.on('pageerror',e=>errors.push(e.message));
   const response=await page.goto(base+path,{waitUntil:'networkidle'});
   assert.equal(response.status(),200);
   assert.equal(await page.locator('h1').count(),1);
   assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'horizontal overflow');
   assert.equal(await page.locator('[data-download]').count(),3);
   const links=await page.locator('[data-download]').evaluateAll(nodes=>nodes.map(n=>n.href));
   assert(links.every(h=>h==='https://github.com/eqwgeryfgbdf/container-desk/releases/download/v1.0.0/Container-Desk-1.0.0-arm64.dmg'));
   await page.locator('[role=tab]').nth(1).click();
   assert.match(await page.locator('#app-shot').getAttribute('src'),/containers.jpg$/);
   await page.locator('[role=tab]').nth(1).press('ArrowRight');
   assert.match(await page.locator('#app-shot').getAttribute('src'),/create.png$/);
   await page.locator('[role=tab]').nth(2).press('Home');
   assert.match(await page.locator('#app-shot').getAttribute('src'),/overview.png$/);
   await page.locator('summary').first().click();
   assert(await page.locator('details').first().evaluate(n=>n.open));
   await page.locator('summary').first().click();
   for (const img of await page.locator('img').all()) { await img.scrollIntoViewIfNeeded(); await img.evaluate(el=>el.decode()); }
   assert.equal(await page.locator('img').evaluateAll(nodes=>nodes.filter(n=>!n.complete || n.naturalWidth===0).length),0);
   assert.deepEqual(errors,[]);
   const slug=path==='/'?'zh-Hant':path.replaceAll('/','');
   await page.evaluate(()=>{document.activeElement?.blur();window.scrollTo(0,0)});
   if(width===1440||width===390) await page.screenshot({path:new URL(`${slug}-${width}.png`,out).pathname,fullPage:true});
   results.push({width,language:slug,status:'PASS'}); await page.close();
  }
 }
 const noJS=await browser.newPage({javaScriptEnabled:false,viewport:{width:390,height:844}});
 await noJS.goto(base+'/');assert(await noJS.locator('h1').isVisible());assert(await noJS.locator('[data-download]').nth(1).isVisible());await noJS.close();
 const page=await browser.newPage(); const missing=await page.goto(base+'/not-a-page');assert.equal(missing.status(),404);await page.close();
 await writeFile(new URL('results.json',out),JSON.stringify({base,results,noJavaScript:'PASS',notFound:'PASS'},null,2));
 console.log(`PASS: ${results.length} language/viewport cases, tabs/keyboard, FAQ, download targets, image loading, no-JS and 404.`);
} finally {await browser.close()}
