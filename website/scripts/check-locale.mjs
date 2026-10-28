import assert from 'node:assert/strict';
import { chromium, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import worker, { languageForCountry } from '../src/worker.mjs';
const base = process.env.SITE_URL || 'http://localhost:8796';
const out = new URL('../../../work/website-qa/', import.meta.url);
await mkdir(out, {recursive:true});
for (const [country, language] of [['TW','zh-Hant'],['HK','zh-Hant'],['MO','zh-Hant'],['CN','zh-Hans'],['US','en'],['JP','en'],['SG','en'],['XX',null],['T1',null],[null,null]]) {
 assert.equal(languageForCountry(country), language);
 const request = new Request('https://example.com/api/locale', {headers:{'CF-IPCountry':'CN'}});
 Object.defineProperty(request, 'cf', {value:{country}});
 const response = await worker.fetch(request, {});
 assert.equal((await response.json()).language, language);
 assert.match(response.headers.get('Cache-Control'), /no-store/);
}
assert.equal((await worker.fetch(new Request('https://example.com/api/locale',{method:'POST'}),{})).status,405);
assert.equal((await worker.fetch(new Request('https://example.com/api/locale',{method:'HEAD'}),{})).body,null);
assert.equal(await (await worker.fetch(new Request('https://example.com/missing'),{ASSETS:{fetch:()=>new Response('fallback',{status:404})}})).text(),'fallback');
const browser = await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const results=[];
const key='container-desk.language.v1';
async function setup(language, options={}) {
 const page=await browser.newPage({viewport:{width:options.width||1440,height:900},locale:options.locale||'en-US',reducedMotion:'reduce'});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 if(options.storageBlocked)await page.addInitScript(()=>{Storage.prototype.getItem=Storage.prototype.setItem=function(){throw new Error('Storage disabled')}});
 await page.route('**/api/locale',async route=>{
  if(options.delay)await new Promise(resolve=>setTimeout(resolve,options.delay));
  if(options.fail)return route.abort();
  return route.fulfill({json:{language,source:language?'region':'browser'},headers:{'Cache-Control':'no-store'}});
 });
 return {page,errors};
}
try {
 for(const [path,language,target] of [['/','en','/en/'],['/en/','zh-Hant','/'],['/zh-Hans/','zh-Hant','/'],['/','zh-Hans','/zh-Hans/']]) {
  const {page,errors}=await setup(language,{width:320});
  await page.goto(base+path+'?from=demo#features');
  const dialog=page.locator('dialog');await expect(dialog).toBeVisible();
  assert.equal(new URL(page.url()).pathname,path,'must not redirect before consent');
  assert(await dialog.evaluate(el=>el.scrollWidth<=el.clientWidth),'dialog overflow');
  await expect(dialog.locator('button')).toBeFocused();
  await page.keyboard.press('Tab');await expect(dialog.locator('a')).toBeFocused();
  if(path==='/')await page.screenshot({path:new URL(`locale-${language}-320.png`,out).pathname});
  await dialog.locator('a').click();
  await expect(page).toHaveURL(base+target+'?from=demo#features');
  await expect(page.locator('dialog')).toHaveCount(0);
  assert.equal(await page.evaluate(key=>localStorage.getItem(key),key),language);
  assert.deepEqual(errors,[]);results.push(`${path} → ${target} confirmed`);await page.close();
 }
 const {page,errors}=await setup('en');await page.goto(base+'/');await expect(page.locator('dialog')).toBeVisible();
 await page.keyboard.press('Escape');await expect(page.locator('dialog')).toHaveCount(0);await page.reload();await expect(page.locator('dialog')).toHaveCount(0);
 assert.equal(await page.evaluate(key=>localStorage.getItem(key),key),'zh-Hant');
 await page.locator('.languages a[lang="en"]').click();await expect(page).toHaveURL(base+'/en/');assert.equal(await page.evaluate(key=>localStorage.getItem(key),key),'en');
 assert.deepEqual(errors,[]);results.push('Escape remembers current language; manual menu overrides');await page.close();
 for (const options of [{locale:'zh-TW',fail:true},{locale:'zh-HK'},{locale:'zh-CN',storageBlocked:true}]) {
  const {page,errors}=await setup(null,options);await page.goto(base+'/en/');await expect(page.locator('dialog')).toBeVisible();
  await expect(page.locator('dialog p').first()).toContainText('browser settings');await page.locator('dialog button').click();
  await expect(page.locator('dialog')).toHaveCount(0);assert.deepEqual(errors,[]);results.push(`fallback ${JSON.stringify(options)}`);await page.close();
 }
 const same=await setup('zh-Hant');await same.page.goto(base+'/',{waitUntil:'networkidle'});await expect(same.page.locator('dialog')).toHaveCount(0);await same.page.close();results.push('matching region: no prompt');
 const delayed=await setup('en',{delay:700});await delayed.page.goto(base+'/');await delayed.page.locator('.languages a[lang="zh-Hant"]').click();await delayed.page.waitForLoadState('networkidle');await expect(delayed.page.locator('dialog')).toHaveCount(0);await delayed.page.close();results.push('manual choice wins over late detection');
 const motion=await setup('en');await motion.page.emulateMedia({reducedMotion:'no-preference'});await motion.page.goto(base+'/');await expect(motion.page.locator('dialog')).toBeVisible();await motion.page.emulateMedia({reducedMotion:'reduce'});await expect.poll(()=>motion.page.evaluate(()=>document.getAnimations().length)).toBe(0);await motion.page.close();results.push('prompt respects live reduced motion');
 await writeFile(new URL('locale-results.json',out),JSON.stringify({base,status:'PASS',worker:'country mapping, private cache, spoofed header ignored, HEAD/405, assets fallback',browser:results},null,2));
 console.log(`PASS: Worker country/privacy/routing checks and ${results.length} locale browser scenarios.`);
} finally {await browser.close()}
