# Container Desk website

Live: https://container.emo-lab.com/

A three-language product website served by Cloudflare Workers Static Assets, with a small Worker endpoint for region-based language suggestions. Traditional Chinese is `/`, English `/en/`, Simplified Chinese `/zh-Hans/`. Download buttons link to the 1.0.0 ARM64 DMG on GitHub. AI/MCP and image-update workflows are included with the documented model and deployment limitations.

## Develop and deploy

Node 22 or later, Python 3, pnpm and a Cloudflare account with access to emo-lab.com:

```sh
pnpm install --frozen-lockfile
pnpm run build
pnpm run dev
pnpm run check
pnpm run check:motion
pnpm exec wrangler login
pnpm run deploy
```

`check` uses a separate headless Chrome instance at `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`. It checks 12 language/viewport cases (1440, 768, 390 and 320 px), tab mouse/keyboard operation, FAQs, images, exact DMG link targets, missing-page responses and content without JavaScript. Override `SITE_URL` to check the deployed site. Screenshots and reports go to the workspace's `work/website-qa/` folder outside the repository.

`check:motion` verifies button hover/press feedback, decoded screenshot transitions, rapid tab changes, keyboard selection, FAQ entrance and card hover. It also switches the system reduced-motion preference at runtime and checks that animations stop. Downloads use normal links and never wait for an animation.

Copy and release URLs are maintained in `scripts/build.py`. Run the build after changing copy. CSS and JavaScript are in `public/`. No external fonts, analytics, account system or runtime GitHub API dependency are used. Static media comes from the app's reviewed 0.2.0 screenshots and existing app icon; see `../docs/MEDIA.md`. No model files or installers are hosted on this website.

When publishing a new app release, update the release URL, version labels, requirements and notes together in the generator and link assertions in `scripts/check.mjs`. Keep preview-only features distinct from the downloadable stable version.

## EMO-Lab entry integration

The current emo-lab.com production site is the existing Cloudflare Worker `emo-lab-website`; the public repositories inspected during setup did not contain its current 3D homepage. `integration/worker.js` adds a small product entry to the existing live HTML using HTMLRewriter and a service binding to that original Worker. No original static assets are replaced.

Production routes are limited to `emo-lab.com/` and `emo-lab.com/projects*`. The Worker only modifies successful HTML GET responses for `/`, `/projects` and `/projects/`. Other responses pass through. The exact root route does not match query strings; visitors with a query on the homepage still receive the original homepage. Projects remain linked from the normal canonical homepage and footer.

- Home: Container Desk link at the start of “繼續探索” and in the footer.
- Projects: Container Desk introduction after the page introduction and a footer link.
- Original main-site content, scenes and assets are served by the existing Worker.

```sh
# Deploy integration without attaching production routes; verify the workers.dev result first.
pnpm exec wrangler deploy --config integration/wrangler.preview.jsonc
# Attach the verified integration to the two production routes.
pnpm run deploy:entry
```

The preview configuration uses the same integration Worker name: deploying it after production removes these entry routes. This provides a reversible way to restore the original homepage and projects page. It does not remove the standalone product website. The original `emo-lab-website` Worker and custom domain must remain intact.

## Historical verification (0.2.0 website launch) — 2026-10-20 (Asia/Taipei)

- Local and live browser matrices passed for all three languages and all four widths.
- Source download URL verified to redirect to a GitHub release asset returning HTTP 200 and filename `Container-Desk-0.2.0-arm64.dmg`.
- Custom domain HTTPS returned HTTP 200 with the configured response headers.
- Main-site homepage and projects entry checks passed, with original scene and project content retained.
- A live browser click followed EMO-Lab projects → product page → English → GitHub DMG; the suggested download filename matched the published installer.
- Build and deploy use pinned versions in `pnpm-lock.yaml`; authentication lives in Wrangler's user configuration, never in this repository.

References: [Workers static assets](https://developers.cloudflare.com/workers/static-assets/), [Custom domains and routes](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/#interaction-with-routes).

## Brand and motion refresh — 2026-10-26

- Uses the approved `Resources/Brand/ContainerDesk-VM-Package.png` artwork in the navigation, hero, download section and favicon. The web copy is a 512 px export under a new filename to avoid the old icon cache. This branding refresh does not replace the already published installer.
- Enlarges body copy, navigation, buttons and small supporting text across all three languages, with mobile wrapping at 320 px and above.
- Adds a staggered hero entrance, section/step reveals and a subtle scrolling header material change; keeps screenshot, FAQ, hover and pressed-state feedback. System Reduce Motion disables transforms/animations and immediately cancels active Web Animations. Links remain directly operable and content remains visible without JavaScript.
- Local and live verification: 12 language/viewport cases and 10 motion checks passed, plus visual review of desktop and mobile. Live logo, CSS and JavaScript hashes match the local release. Cloudflare deployment: `4faadba1-c3e5-4bc9-813e-458712b42064`.
- Deployment continues to use the existing `container-desk-site` Worker and `container.emo-lab.com` domain; release selection and main EMO-Lab integration are unchanged.

## IP-region language suggestions — 2026-10-26

`src/worker.mjs` exposes `/api/locale`, using Cloudflare's trusted `request.cf.country` metadata. TW/HK/MO suggest Traditional Chinese, CN suggests Simplified Chinese, and other known regions suggest English. Unknown locations fall back to the browser's primary language; unsupported browser languages fall back to English. IP location is only a suggestion and may reflect a VPN exit location.

When a suggested language differs from the current page, `public/locale.js` presents a translated native dialog. Navigation happens only after the visitor confirms. The current query string and section anchor are retained. Staying on the page or pressing Escape remembers the current language; the navigation menu updates that preference. The preference is stored only in this browser's localStorage (`container-desk.language.v1`). A saved preference takes priority over detection; when visiting a different language URL, the visitor can confirm returning to the preferred version or keep the new version. Storage denial does not block browsing.

The application code does not read, log, persist, or send IP addresses to a third-party geolocation service. Only the language recommendation is returned, with `Cache-Control: private, no-store`; HTML remains static and shared safely. The browser makes one same-origin detection request when there is no saved preference, with a three-second timeout and a browser-language fallback. Explicit language choices win over a late detection response. The Worker runs first only for `/api/locale`, serving other unmatched paths through the ASSETS binding. No new database, paid geolocation service or account is required.

`pnpm run check:locale` covers country mapping, spoofed country-header rejection, no-store responses, method handling, static fallback, mismatch confirmation, persistence, keyboard/Escape behavior, reduced motion, 320 px screens, blocked storage, failed detection and delayed responses. Browser country scenarios use mocked recommendations; mapping tests inject Cloudflare metadata locally. Live checks verify the deployed endpoint and page flow, not physical travel from every country.

Verified locally and on the live domain: country mapping and 11 browser locale scenarios passed. The actual live IP recommendation, private/no-store headers, confirmed navigation, preference persistence and existing 404 response were also checked. Deployment version: `79dcde8f-52e3-4382-a91c-62fe889001c2`.
