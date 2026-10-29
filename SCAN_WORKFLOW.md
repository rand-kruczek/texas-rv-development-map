# Texas RV scan write and verification workflow

Production: https://texas-rv-development-map.vercel.app/
Supabase: hewvnlfvhvpzlrgxjmkd
Vercel: prj_1iuPk1SHMDn4YxO4ftjK60cTez7Q / team_uk6fyKtAkFsRpIhnrpD0mO1C

This is a static read-only frontend. New database rows appear without a code deployment. GitHub commits do not add findings to Supabase. The daily ChatGPT automation must perform the writes explicitly with the authorized Supabase connector.

## Required run procedure

1. Read this workflow, current schema, and all unresolved market_scan.items before researching new changes. Pending/blocked/database_verified items must be retried; never advance the research window past an unresolved finding. Compare every candidate with existing table IDs, normalized name/address/city, source/TDLR identifiers, and nearby coordinates. A matching site is an update, not another insert.
2. Create market_scan.runs. For every credible candidate, insert market_scan.items BEFORE writing the public row. Use a stable candidate_key (e.g. tdlr:TABS...). Store source_url and expected_fields JSON with the exact intended saved facts. Do not stage unverified guesses.
3. Write to the correct existing public table. Use an existing ID for updates and preserve prior facts/history where useful. Unknown coordinates must BOTH be NULL, not 0 or a city centroid. Market impacts now permit NULL coordinates. A verified non-spatial finding is still saved and displays as Location pending verification. Do not mistake the source author's mailing address for the project address.
4. Re-query the exact target ID and compare all intended fields, including source, date, confidence and numbers. Set target_id, outcome (added/updated/existing), state=database_verified. A database trigger rejects mismatching expected_fields. A zero-row update is not success. Record errors as blocked and retain the candidate for the next run.
5. Open the production website in a real browser. Reset radius/filters and select the intended layer. Compare the card data-id and relevant popup fields with the saved record. For records without coordinates, verify the card and details and explicitly report that no pin/radius result is available. Verify current comps in the current view and off-market/old comps under Archive / off market. The DOM cards have data-layer and data-id.
6. If a search-engine fetch returns cache-miss, use the actual browser and/or Vercel fetch connector. A search fetch error does not establish a website outage. Do not keep retrying the same failed route. Public API read-back alone is database/API verification, not visual verification.
7. Set state=site_verified with site_evidence specifying public URL, tab, target ID, displayed values, verification method and time. Then mark the run complete. The run trigger rejects completion while its own items remain unresolved. Check unresolved older runs independently as well. If browser verification is blocked, retain database_verified state, mark run partial, and notify accurately.
8. Notify only meaningful writes, verification failures, unresolved verified findings, or required user action. Counts must match ledger outcomes. Never say everything is updated/verified when unresolved items remain.

The private market_scan schema contains runs, items and automatic changes with before/after row snapshots. It is not exposed to anonymous/authenticated public clients. The baseline recorded on October 29 is current-state evidence, not a reconstruction of older unlogged changes.

## Useful SQL

    select * from market_scan.items where state <> 'site_verified' order by created_at;
    select * from market_scan.runs order by started_at desc;
    select * from market_scan.changes order by changed_at desc, id desc;

For one write:

    insert into market_scan.items
      (run_id,candidate_key,target_table,name,source_url,expected_fields)
    values (:run_id,:stable_key,:table,:name,:source,:expected_json);

After writing and independently reading the public row:

    update market_scan.items
    set target_id=:id,outcome=:outcome,state='database_verified'
    where id=:item_id;

After the browser check:

    update market_scan.items
    set state='site_verified',site_evidence=:observed_details
    where id=:item_id;

## Frontend integrity

data-utils.js preserves null coordinates, validates Texas map bounds, pages in stable ID order, checks exact row counts and rejects repeated pages. Refresh failures retain the last good dataset and display a warning. Source counts/times appear above results and Refresh data reruns the reads.

Current comps exclude closed/off-market/withdrawn listings and sold comps outside the rolling 18-month window or lacking a positive sale price/date. All saved historical records remain in Archive / off market. The radius snapshot uses the same eligibility rules. New impact categories are added to the dropdown from live data.

## Verification

Run node tools/smoke.mjs and node tools/data-tests.mjs. The latter checks blank coordinates, date boundaries, undisclosed sold prices, archived listings, short server pages, repeated pages, count changes and HTTP failures. database/verify-scan.sql checks ledger guards and audit triggers in a rolled-back transaction.
