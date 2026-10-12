-- Waitlist signups from the missional.io homepage.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Security model: the website uses the public (publishable/anon) key. Visitors can
-- INSERT a signup, but cannot read, update or delete any rows. View signups in the
-- dashboard (Table Editor) or with the service_role key, which never goes in the site.

create table if not exists public.waitlist (
	id uuid primary key default gen_random_uuid(),
	email text not null,
	name text,
	organization text,
	role text,
	source text,
	created_at timestamptz not null default now(),

	constraint waitlist_email_format check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
	constraint waitlist_email_length check (char_length(email) <= 254),
	constraint waitlist_name_length check (char_length(name) <= 120),
	constraint waitlist_organization_length check (char_length(organization) <= 160),
	constraint waitlist_role_valid check (
		role is null or role in ('trip_leader', 'sending_organization', 'church', 'other')
	),
	constraint waitlist_source_length check (char_length(source) <= 60)
);

-- One signup per email address, case-insensitive.
create unique index if not exists waitlist_email_unique on public.waitlist (lower(email));

alter table public.waitlist enable row level security;

-- Only allow inserts from the website; no select/update/delete policies exist,
-- so the public key cannot read the list back.
revoke all on public.waitlist from anon, authenticated;
grant insert (email, name, organization, role, source) on public.waitlist to anon, authenticated;

drop policy if exists "Website visitors can join the waitlist" on public.waitlist;
create policy "Website visitors can join the waitlist"
	on public.waitlist
	for insert
	to anon, authenticated
	with check (true);
