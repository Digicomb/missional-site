-- Run after 003, in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Fixes 003: the parameter "source" has the same name as the heartbeat table's
-- column, so every call failed with "column reference "source" is ambiguous".
-- The parameter keeps its name (the GitHub Actions jobs send {"source": ...});
-- the body now says explicitly which one it means.

create or replace function public.keep_alive(source text default 'unknown')
returns timestamptz
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
	label text;
begin
	-- Fixed set of labels, so callers with the public key can't add new rows.
	label := case
		when keep_alive.source in ('missional-site', 'digitalhoneycomb-site') then keep_alive.source
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
