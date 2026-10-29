create schema if not exists market_scan;
revoke all on schema market_scan from public,anon,authenticated;
grant usage on schema market_scan to service_role;
create table market_scan.runs (
 id uuid primary key default gen_random_uuid(),
 started_at timestamptz not null default now(),
 finished_at timestamptz,
 status text not null default 'in_progress' check(status in ('in_progress','complete','partial','failed')),
 summary text
);
create table market_scan.items (
 id uuid primary key default gen_random_uuid(),
 run_id uuid not null references market_scan.runs(id),
 candidate_key text not null,
 target_table text not null check(target_table in ('texas_park_developments','texas_rv_market_impacts','texas_rv_sales_comps')),
 target_id uuid,
 name text not null,
 source_url text not null check(source_url ~ '^https?://'),
 expected_fields jsonb not null default '{}'::jsonb check(jsonb_typeof(expected_fields)='object'),
 state text not null default 'pending' check(state in ('pending','database_verified','site_verified','blocked')),
 outcome text not null default 'queued' check(outcome in ('queued','added','updated','existing')),
 error text,
 database_verified_at timestamptz,
 site_verified_at timestamptz,
 site_evidence text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(run_id,candidate_key)
);
create index scan_items_pending on market_scan.items(state,created_at) where state<>'site_verified';
create index scan_items_target on market_scan.items(target_table,target_id);
create table market_scan.changes (
 id bigint generated always as identity primary key,
 table_name text not null,
 record_id uuid not null,
 operation text not null,
 changed_at timestamptz not null default now(),
 actor text not null default current_user,
 before_row jsonb,
 after_row jsonb
);
create index scan_changes_target on market_scan.changes(table_name,record_id,changed_at desc);
alter table market_scan.runs enable row level security;
alter table market_scan.items enable row level security;
alter table market_scan.changes enable row level security;
revoke all on all tables in schema market_scan from public,anon,authenticated;
grant select,insert,update on market_scan.runs,market_scan.items to service_role;
grant select,insert on market_scan.changes to service_role;
grant usage,select on all sequences in schema market_scan to service_role;

create function market_scan.verify_item() returns trigger language plpgsql security invoker set search_path='' as $$
declare actual jsonb;
begin
 new.updated_at=now();
 if new.state in ('database_verified','site_verified') then
  if new.target_id is null or new.expected_fields='{}'::jsonb then raise exception 'Target and expected fields are required'; end if;
  execute format('select to_jsonb(t) from public.%I t where id=$1',new.target_table) into actual using new.target_id;
  if actual is null or not(actual @> new.expected_fields) then raise exception 'Saved record does not match expected fields'; end if;
  new.database_verified_at=coalesce(new.database_verified_at,now());
 end if;
 if new.state='site_verified' then
  if nullif(btrim(new.site_evidence),'') is null then raise exception 'Live-site evidence is required'; end if;
  new.site_verified_at=coalesce(new.site_verified_at,now());
 else new.site_verified_at=null;
 end if;
 return new;
end $$;
revoke all on function market_scan.verify_item() from public,anon,authenticated;
create trigger verify_scan_item before insert or update on market_scan.items for each row execute function market_scan.verify_item();

create function market_scan.verify_run() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.status='complete' then
  if exists(select 1 from market_scan.items where run_id=new.id and state<>'site_verified') then raise exception 'Run still has unverified items'; end if;
  new.finished_at=coalesce(new.finished_at,now());
 end if;
 return new;
end $$;
revoke all on function market_scan.verify_run() from public,anon,authenticated;
create trigger verify_scan_run before update on market_scan.runs for each row execute function market_scan.verify_run();

create function market_scan.capture_change() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 insert into market_scan.changes(table_name,record_id,operation,before_row,after_row)
 values(tg_table_name,coalesce(new.id,old.id),tg_op,case when tg_op<>'INSERT' then to_jsonb(old) end,case when tg_op<>'DELETE' then to_jsonb(new) end);
 return null;
end $$;
create function market_scan.touch_updated_at() returns trigger language plpgsql security invoker set search_path='' as $$
begin new.updated_at=now();return new;end $$;
revoke all on function market_scan.capture_change(),market_scan.touch_updated_at() from public,anon,authenticated;

create trigger scan_touch before update on public.texas_park_developments for each row execute function market_scan.touch_updated_at();
create trigger scan_touch before update on public.texas_rv_market_impacts for each row execute function market_scan.touch_updated_at();
create trigger scan_touch before update on public.texas_rv_sales_comps for each row execute function market_scan.touch_updated_at();
create trigger scan_audit after insert or update or delete on public.texas_park_developments for each row execute function market_scan.capture_change();
create trigger scan_audit after insert or update or delete on public.texas_rv_market_impacts for each row execute function market_scan.capture_change();
create trigger scan_audit after insert or update or delete on public.texas_rv_sales_comps for each row execute function market_scan.capture_change();

alter table public.texas_rv_market_impacts alter column latitude drop not null,alter column longitude drop not null;
alter table public.texas_rv_market_impacts add constraint impact_coordinate_pair check(
 (latitude is null and longitude is null) or (latitude is not null and longitude is not null and latitude between 25 and 37 and longitude between -107 and -93));
alter table public.texas_park_developments add constraint development_coordinate_pair check(
 (latitude is null and longitude is null) or (latitude is not null and longitude is not null and latitude between 25 and 37 and longitude between -107 and -93));
alter table public.texas_rv_sales_comps add constraint comp_coordinate_pair check(
 (latitude is null and longitude is null) or (latitude is not null and longitude is not null and latitude between 25 and 37 and longitude between -107 and -93));

create unique index texas_development_normalized_identity on public.texas_park_developments
(lower(regexp_replace(name,'[^[:alnum:]]','','g')),lower(regexp_replace(coalesce(nullif(btrim(address),''),city,''),'[^[:alnum:]]','','g')));
create unique index texas_impact_normalized_identity on public.texas_rv_market_impacts
(lower(regexp_replace(name,'[^[:alnum:]]','','g')),lower(regexp_replace(coalesce(nullif(btrim(location_label),''),city,''),'[^[:alnum:]]','','g')));
create unique index texas_comp_normalized_identity on public.texas_rv_sales_comps
(record_type,lower(regexp_replace(name,'[^[:alnum:]]','','g')),lower(regexp_replace(coalesce(nullif(btrim(address),''),city,''),'[^[:alnum:]]','','g')));
