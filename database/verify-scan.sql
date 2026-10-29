-- Run with the authorized SQL connector. All test changes roll back.
begin;
do $$ declare run_id uuid;item_id uuid;target uuid;n bigint;
begin
 insert into market_scan.runs(summary) values('Rollback-only verification') returning id into run_id;
 select id into target from public.texas_rv_market_impacts order by id limit 1;
 insert into market_scan.items(run_id,candidate_key,target_table,name,source_url,expected_fields)
 select run_id,'rollback-test','texas_rv_market_impacts',name,source_url,jsonb_build_object('name',name) from public.texas_rv_market_impacts where id=target returning id into item_id;
 begin
  update market_scan.runs set status='complete' where id=run_id;
  raise exception 'TEST FAILED: pending run accepted';
 exception when raise_exception then if sqlerrm like 'TEST FAILED%' then raise;end if;end;
 begin
  update market_scan.items set target_id=target,expected_fields='{"name":"not the saved name"}',state='database_verified' where id=item_id;
  raise exception 'TEST FAILED: mismatching fields accepted';
 exception when raise_exception then if sqlerrm like 'TEST FAILED%' then raise;end if;end;
 update market_scan.items set target_id=target,state='database_verified' where id=item_id;
 begin
  update market_scan.items set state='site_verified' where id=item_id;
  raise exception 'TEST FAILED: site evidence missing';
 exception when raise_exception then if sqlerrm like 'TEST FAILED%' then raise;end if;end;
 select count(*) into n from market_scan.changes;
 update public.texas_rv_market_impacts set status=status where id=target;
 if (select count(*) from market_scan.changes)<>n+1 then raise exception 'TEST FAILED: change audit';end if;
end $$;
rollback;
select 'PASS ledger completion, expected fields, site evidence, change audit' result;
