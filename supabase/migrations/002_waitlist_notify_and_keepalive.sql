-- Run after 001_waitlist.sql, in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- 1. Emails a notification (via Resend) whenever someone joins the waitlist.
-- 2. Adds a tiny keep_alive() function that the GitHub Actions keep-alive job calls
--    so the free-tier project isn't paused for inactivity.

-- ---------------------------------------------------------------------------
-- 1. New-signup email notification
-- ---------------------------------------------------------------------------

create extension if not exists pg_net with schema extensions;

-- Settings are stored in Supabase Vault (encrypted). Set them ONCE by running the
-- block below with your real values filled in (replace the <...> placeholders).
-- To change a value later: Project Settings -> Vault, or
--   select vault.update_secret((select id from vault.secrets where name = 'resend_api_key'), 're_new_key');
--
-- select vault.create_secret('<your Resend API key, starts with re_>', 'resend_api_key');
-- select vault.create_secret('<address to notify, e.g. hello@missional.io>', 'waitlist_notify_to');
-- select vault.create_secret('Missional <notifications@missional.io>', 'waitlist_notify_from');

create or replace function public.notify_waitlist_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
	api_key text;
	notify_to text;
	notify_from text;
	body_text text;
begin
	select decrypted_secret into api_key from vault.decrypted_secrets where name = 'resend_api_key';
	select decrypted_secret into notify_to from vault.decrypted_secrets where name = 'waitlist_notify_to';
	select decrypted_secret into notify_from from vault.decrypted_secrets where name = 'waitlist_notify_from';

	-- Not configured yet: keep the signup, skip the email.
	if api_key is null or notify_to is null or notify_from is null then
		return new;
	end if;

	-- Plain text only, so nothing a visitor types can inject HTML into the email.
	body_text := concat_ws(E'\n',
		'New Missional waitlist signup',
		'',
		'Email:        ' || new.email,
		'Name:         ' || coalesce(new.name, '-'),
		'Organization: ' || coalesce(new.organization, '-'),
		'Role:         ' || coalesce(new.role, '-'),
		'Source:       ' || coalesce(new.source, '-'),
		'Signed up:    ' || to_char(new.created_at at time zone 'America/New_York', 'YYYY-MM-DD HH24:MI TZ')
	);

	-- Asynchronous: the HTTP call runs after the insert commits and never blocks the signup.
	perform net.http_post(
		url := 'https://api.resend.com/emails',
		headers := jsonb_build_object(
			'Authorization', 'Bearer ' || api_key,
			'Content-Type', 'application/json'
		),
		body := jsonb_build_object(
			'from', notify_from,
			'to', jsonb_build_array(notify_to),
			'subject', 'New waitlist signup: ' || new.email,
			'text', body_text
		)
	);

	return new;
end;
$$;

revoke all on function public.notify_waitlist_signup() from public, anon, authenticated;

drop trigger if exists waitlist_notify on public.waitlist;
create trigger waitlist_notify
	after insert on public.waitlist
	for each row
	execute function public.notify_waitlist_signup();

-- ---------------------------------------------------------------------------
-- 2. Keep-alive
-- ---------------------------------------------------------------------------

-- Returns the database time. Exposes no data; callable with the public key at
-- POST /rest/v1/rpc/keep_alive.
create or replace function public.keep_alive()
returns timestamptz
language sql
stable
set search_path = ''
as $$
	select now();
$$;

revoke all on function public.keep_alive() from public;
grant execute on function public.keep_alive() to anon, authenticated;
