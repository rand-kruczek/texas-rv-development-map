# Texas RV Market Intelligence

Source for [texas-rv-development-map.vercel.app](https://texas-rv-development-map.vercel.app/).

The site is a static map with three live data layers: RV/mobile-home developments, RV market impacts, and sales/for-sale comps. `index.html` loads the same-origin `base.html` and applies the existing map enhancements. `theme.css` adds the refreshed responsive presentation. Data remains in the existing Supabase project; this repository does not contain a private database key or a copy of the records.

## Run locally

From this directory, run `node tools/serve.mjs`, then open `http://127.0.0.1:8765/`. The map needs an internet connection for Leaflet tiles and the public read-only data API.

Run `node tools/smoke.mjs` for a quick static check before deployment.

## Deploy

Deploy this repository to the existing Vercel project `texas-rv-development-map`. Do not create a second project or change its public URL. Keep `index.html`, `base.html`, and `theme.css` together at the project root. The `.vercelignore` file excludes local tooling and development files.

## Features

- Address or coordinate search, custom radius and presets, layer filters, and map basemaps.
- Distance shown next to results and at the top of marker details after a search.
- Owner Market Snapshot for the searched radius.
- Right-click the map to copy coordinates.
- Export currently visible records as CSV and copy a shareable link to the current view.
- Independent layer loading: a temporary failure in one data source does not hide records from the others.

