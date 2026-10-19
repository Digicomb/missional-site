-- Run after 002, in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Makes the keep-alive a real write instead of a read-only call, so the shared
-- Digicomb project always shows database activity. Each GitHub Actions keep-alive
-- job (missional-site and digitalhoneycomb-site) updates its own heartbeat row.
-- Check the last ping from each repo with:
--   select * from public.keep_alive_heartbeat order by pinged_at desc;

create table if not exists public.keep_alive_heartbeat (
	source text primary key,
	pinged_at timestamptz not null default now(),
	ping_count bigint not null default 1
);

alter table public.keep_alive_heartbeat enable row level security;

-- No policies and no grants: only keep_alive() (security definer) writes here.
revoke all on public.keep_alive_heartbeat from anon, authenticated;

-- Replaces the read-only keep_alive() from 002. The default keeps POST
-- /rest/v1/rpc/keep_alive with an empty body {} working.
drop function if exists public.keep_alive();

create or replace function public.keep_alive(source text default 'unknown')
returns timestamptz
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
	label text;
begin
	-- Fixed set of labels, so callers with the public key can't add new rows.
	label := case
		when source in ('missional-site', 'digitalhoneycomb-site') then source
		else 'other'
	end;

	insert into public.keep_alive_heartbeat as h (source, pinged_at)
	values (label, now())
	on conflict (source) do update
		set pinged_at = excluded.pinged_at,
			ping_count = h.ping_count + 1;

	return now();
end;
$$;

revoke all on function public.keep_alive(text) from public;
grant execute on function public.keep_alive(text) to anon, authenticated;
