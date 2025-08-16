-- Example guard (main-only in workflow). Add your real checks here.
do $
begin
  if (select count(*) from scout.brand_catalog) < 1 then
    raise exception 'DQ: empty brand_catalog';
  end if;
end$;