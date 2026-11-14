-- Operin: skema dasar, keamanan (RLS), view baca, dan realtime.
-- Jalankan di Supabase Dashboard → SQL Editor (atau `supabase db push`),
-- lalu jalankan 0002_functions.sql.

-- ---------------------------------------------------------------------------
-- Schema privat untuk helper (tidak diekspos lewat API REST).
-- ---------------------------------------------------------------------------
create schema if not exists private;

-- ---------------------------------------------------------------------------
-- Tabel
-- ---------------------------------------------------------------------------

-- Profil akun. `id` bigint dipakai di seluruh aplikasi; `auth_id` menautkan
-- ke Supabase Auth. Email & password dikelola Supabase Auth.
create table public.users (
  id bigint generated always as identity primary key,
  auth_id uuid not null unique default auth.uid()
    references auth.users (id) on delete cascade,
  full_name text not null,
  business_type text not null,
  address text not null,
  role text check (role in ('seller', 'buyer', 'waste')),
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

create table public.business_profiles (
  user_id bigint primary key references public.users (id) on delete cascade,
  business_name text not null,
  whatsapp text not null,
  preferred_categories text not null default '',
  radius_km integer not null,
  notify_expiry boolean not null,
  notify_days_before integer not null,
  updated_at timestamptz not null default now()
);

create table public.stock_items (
  id bigint generated always as identity primary key,
  user_id bigint not null references public.users (id) on delete cascade,
  name text not null,
  category text not null,
  quantity double precision not null check (quantity >= 0),
  unit text not null,
  price_per_unit integer not null check (price_per_unit >= 0),
  expiry_date date not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_stock_user_expiry on public.stock_items (user_id, expiry_date);

create table public.promotions (
  id bigint generated always as identity primary key,
  user_id bigint not null references public.users (id) on delete cascade,
  stock_id bigint not null references public.stock_items (id) on delete cascade,
  type text not null check (type in ('discount', 'flashSale')),
  discount_percent integer not null check (discount_percent between 0 and 100),
  original_price integer not null,
  quantity double precision not null check (quantity > 0),
  created_at timestamptz not null default now(),
  ends_at timestamptz not null,
  status text not null default 'active' check (status in ('active', 'cancelled'))
);
create index idx_promotion_user on public.promotions (user_id, status);

create table public.orders (
  id bigint generated always as identity primary key,
  promotion_id bigint not null references public.promotions (id) on delete cascade,
  buyer_id bigint not null references public.users (id) on delete cascade,
  seller_id bigint not null references public.users (id) on delete cascade,
  quantity double precision not null,
  unit_price integer not null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'cancelled', 'completed')),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_order_buyer on public.orders (buyer_id, created_at);
create index idx_order_seller on public.orders (seller_id, created_at);
create index idx_order_promotion on public.orders (promotion_id, status);

create table public.barters (
  id bigint generated always as identity primary key,
  type text not null check (type in ('barter', 'donation')),
  proposer_id bigint not null references public.users (id) on delete cascade,
  receiver_id bigint not null references public.users (id) on delete cascade,
  offered_stock_id bigint not null references public.stock_items (id) on delete cascade,
  offered_quantity double precision not null,
  requested_stock_id bigint references public.stock_items (id) on delete set null,
  requested_quantity double precision,
  requested_note text,
  status text not null default 'pending'
    check (status in ('pending', 'negotiating', 'accepted', 'rejected', 'cancelled', 'completed')),
  last_actor_id bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_barter_proposer on public.barters (proposer_id, updated_at);
create index idx_barter_receiver on public.barters (receiver_id, updated_at);

create table public.barter_messages (
  id bigint generated always as identity primary key,
  barter_id bigint not null references public.barters (id) on delete cascade,
  sender_id bigint not null references public.users (id) on delete cascade,
  text text not null,
  offered_quantity double precision,
  requested_quantity double precision,
  created_at timestamptz not null default now()
);
create index idx_barter_message on public.barter_messages (barter_id, id);

-- Riwayat transaksi selesai. Menyalin nama stok/mitra agar riwayat tetap
-- utuh walau data asal berubah (sengaja tanpa FK ke stok/order/barter).
create table public.activity_log (
  id bigint generated always as identity primary key,
  user_id bigint not null references public.users (id) on delete cascade,
  kind text not null
    check (kind in ('sale', 'purchase', 'barterOut', 'barterIn', 'donationOut', 'donationIn')),
  counterpart_id bigint not null,
  counterpart_name text not null,
  stock_name text not null,
  category text not null,
  quantity double precision not null,
  unit text not null,
  amount integer not null,
  saved_value integer not null,
  weight_kg double precision not null,
  reference_type text not null check (reference_type in ('order', 'barter')),
  reference_id bigint not null,
  created_at timestamptz not null default now()
);
create index idx_activity_user on public.activity_log (user_id, created_at);

-- ---------------------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------------------

-- Id user aplikasi (bigint) milik pemanggil saat ini.
create function private.app_uid()
returns bigint
language sql stable security definer
set search_path = ''
as $$
  select id from public.users where auth_id = auth.uid()
$$;

-- Jumlah promo yang sudah dipesan & diterima (melewati RLS orders, hanya
-- mengembalikan total).
create function private.promo_reserved(p_promotion_id bigint)
returns double precision
language sql stable security definer
set search_path = ''
as $$
  select coalesce(sum(quantity), 0)::double precision
  from public.orders
  where promotion_id = p_promotion_id and status in ('accepted', 'completed')
$$;

-- Saat daftar lewat Supabase Auth, buat baris public.users dari metadata.
create function private.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.users (auth_id, full_name, business_type, address, latitude, longitude)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'business_type', 'warungMakan'),
    coalesce(new.raw_user_meta_data ->> 'address', ''),
    nullif(new.raw_user_meta_data ->> 'latitude', '')::double precision,
    nullif(new.raw_user_meta_data ->> 'longitude', '')::double precision
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

revoke all on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.app_uid() to authenticated;
grant execute on function private.promo_reserved(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- Baca: data pasar & matchmaking terbuka untuk user yang login; transaksi
-- hanya untuk pihak terkait. Tulis: hanya pemilik. Order, barter, pesan, dan
-- riwayat HANYA ditulis lewat fungsi RPC (0002_functions.sql).
-- ---------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.business_profiles enable row level security;
alter table public.stock_items enable row level security;
alter table public.promotions enable row level security;
alter table public.orders enable row level security;
alter table public.barters enable row level security;
alter table public.barter_messages enable row level security;
alter table public.activity_log enable row level security;

create policy "users: baca" on public.users
  for select to authenticated using (true);
create policy "users: ubah milik sendiri" on public.users
  for update to authenticated
  using (auth_id = auth.uid()) with check (auth_id = auth.uid());

create policy "profil: baca" on public.business_profiles
  for select to authenticated using (true);
create policy "profil: tambah milik sendiri" on public.business_profiles
  for insert to authenticated with check (user_id = private.app_uid());
create policy "profil: ubah milik sendiri" on public.business_profiles
  for update to authenticated
  using (user_id = private.app_uid()) with check (user_id = private.app_uid());

create policy "stok: baca" on public.stock_items
  for select to authenticated using (true);
create policy "stok: tambah milik sendiri" on public.stock_items
  for insert to authenticated with check (user_id = private.app_uid());
create policy "stok: ubah milik sendiri" on public.stock_items
  for update to authenticated
  using (user_id = private.app_uid()) with check (user_id = private.app_uid());
create policy "stok: hapus milik sendiri" on public.stock_items
  for delete to authenticated using (user_id = private.app_uid());

create policy "promo: baca" on public.promotions
  for select to authenticated using (true);
create policy "promo: tambah untuk stok sendiri" on public.promotions
  for insert to authenticated with check (
    user_id = private.app_uid()
    and exists (
      select 1 from public.stock_items s
      where s.id = stock_id and s.user_id = private.app_uid()
    )
  );
create policy "promo: ubah milik sendiri" on public.promotions
  for update to authenticated
  using (user_id = private.app_uid()) with check (user_id = private.app_uid());

create policy "order: pihak terkait" on public.orders
  for select to authenticated
  using (private.app_uid() in (buyer_id, seller_id));

create policy "barter: pihak terkait" on public.barters
  for select to authenticated
  using (private.app_uid() in (proposer_id, receiver_id));

create policy "pesan barter: pihak terkait" on public.barter_messages
  for select to authenticated
  using (exists (
    select 1 from public.barters b
    where b.id = barter_id and private.app_uid() in (b.proposer_id, b.receiver_id)
  ));

create policy "riwayat: milik sendiri" on public.activity_log
  for select to authenticated using (user_id = private.app_uid());

-- ---------------------------------------------------------------------------
-- View baca (security_invoker: tetap tunduk pada RLS pemanggil)
-- ---------------------------------------------------------------------------
create view public.market_listings with (security_invoker = true) as
select p.*,
  s.name as stock_name, s.category as stock_category,
  s.unit as stock_unit, s.expiry_date as stock_expiry,
  u.full_name as seller_full_name, u.address as seller_address,
  u.latitude as seller_lat, u.longitude as seller_lng,
  b.business_name as seller_business_name, b.whatsapp as seller_whatsapp,
  private.promo_reserved(p.id) as reserved
from public.promotions p
join public.stock_items s on s.id = p.stock_id
join public.users u on u.id = p.user_id
left join public.business_profiles b on b.user_id = p.user_id
where p.status = 'active' and p.ends_at > now();

create view public.order_details with (security_invoker = true) as
select o.*,
  s.name as stock_name, s.unit as stock_unit,
  coalesce(bb.business_name, bu.full_name) as buyer_name,
  coalesce(sb.business_name, su.full_name) as seller_name
from public.orders o
join public.promotions p on p.id = o.promotion_id
join public.stock_items s on s.id = p.stock_id
join public.users bu on bu.id = o.buyer_id
left join public.business_profiles bb on bb.user_id = o.buyer_id
join public.users su on su.id = o.seller_id
left join public.business_profiles sb on sb.user_id = o.seller_id;

create view public.barter_details with (security_invoker = true) as
select br.*,
  coalesce(pb.business_name, pu.full_name) as proposer_name,
  coalesce(rb.business_name, ru.full_name) as receiver_name,
  os.name as offered_stock_name, os.unit as offered_unit,
  rs.name as requested_stock_name, rs.unit as requested_unit
from public.barters br
join public.users pu on pu.id = br.proposer_id
left join public.business_profiles pb on pb.user_id = br.proposer_id
join public.users ru on ru.id = br.receiver_id
left join public.business_profiles rb on rb.user_id = br.receiver_id
join public.stock_items os on os.id = br.offered_stock_id
left join public.stock_items rs on rs.id = br.requested_stock_id;

create view public.barter_message_details with (security_invoker = true) as
select m.*, coalesce(b.business_name, u.full_name) as sender_name
from public.barter_messages m
join public.users u on u.id = m.sender_id
left join public.business_profiles b on b.user_id = m.sender_id;

-- Calon mitra matchmaking: user yang sudah pilih peran & isi profil usaha.
create view public.partner_profiles with (security_invoker = true) as
select u.id, u.full_name, u.role, u.business_type, u.address,
  u.latitude, u.longitude,
  b.business_name, b.whatsapp, b.preferred_categories
from public.users u
join public.business_profiles b on b.user_id = u.id
where u.role is not null;

revoke all on public.market_listings, public.order_details, public.barter_details,
  public.barter_message_details, public.partner_profiles from anon;
grant select on public.market_listings, public.order_details, public.barter_details,
  public.barter_message_details, public.partner_profiles to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: perubahan pesanan, barter, chat, dan promo dikirim ke aplikasi.
-- ---------------------------------------------------------------------------
alter publication supabase_realtime
  add table public.orders, public.barters, public.barter_messages, public.promotions;
