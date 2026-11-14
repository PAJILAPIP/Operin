-- Operin: aturan bisnis sebagai fungsi Postgres (dipanggil lewat RPC).
-- Setiap fungsi berjalan dalam satu transaksi: jika gagal di tengah, semua
-- perubahan dibatalkan. Pesan `raise exception` ditampilkan langsung di app.

-- ---------------------------------------------------------------------------
-- Helper privat
-- ---------------------------------------------------------------------------

-- Seperti formatQuantity di Dart: 10 → "10", 2.5 → "2,5".
create function private.fmt_qty(q double precision)
returns text language sql immutable set search_path = '' as $$
  select case
    when q = round(q) then round(q)::bigint::text
    else replace(rtrim(to_char(round(q::numeric, 2), 'FM999999999990.00'), '0'), '.', ',')
  end
$$;

-- Perkiraan berat per satuan (sama dengan StockUnit.estimatedKg).
create function private.unit_kg(p_unit text)
returns double precision language sql immutable set search_path = '' as $$
  select case p_unit
    when 'kg' then 1 when 'gram' then 0.001 when 'liter' then 1
    when 'pcs' then 0.2 when 'pack' then 0.5 when 'ikat' then 0.25
    when 'porsi' then 0.4 else 0.2
  end::double precision
$$;

create function private.order_status_label(p_status text)
returns text language sql immutable set search_path = '' as $$
  select case p_status
    when 'pending' then 'Menunggu' when 'accepted' then 'Diterima'
    when 'rejected' then 'Ditolak' when 'cancelled' then 'Dibatalkan'
    when 'completed' then 'Selesai' else p_status
  end
$$;

create function private.barter_status_label(p_status text)
returns text language sql immutable set search_path = '' as $$
  select case p_status
    when 'pending' then 'Menunggu' when 'negotiating' then 'Negosiasi'
    when 'accepted' then 'Disepakati' when 'rejected' then 'Ditolak'
    when 'cancelled' then 'Dibatalkan' when 'completed' then 'Selesai'
    else p_status
  end
$$;

-- Harga promo dibulatkan ke Rp100 (sama dengan Promotion.priceAfterDiscount).
create function private.promo_price(p_price integer, p_percent integer)
returns integer language sql immutable set search_path = '' as $$
  select least(greatest((round(p_price * (100 - p_percent) / 100.0 / 100) * 100)::integer, 0), p_price)
$$;

create function private.display_name(p_user_id bigint)
returns text language sql stable set search_path = '' as $$
  select coalesce(
    (select coalesce(b.business_name, u.full_name)
     from public.users u left join public.business_profiles b on b.user_id = u.id
     where u.id = p_user_id),
    'UMKM')
$$;

create function private.require_user()
returns bigint language plpgsql stable set search_path = '' as $$
declare
  v_uid bigint := private.app_uid();
begin
  if v_uid is null then
    raise exception 'Sesi berakhir. Silakan login ulang.';
  end if;
  return v_uid;
end;
$$;

-- Promo aktif (dikunci untuk transaksi).
create function private.active_promotion(p_promotion_id bigint)
returns public.promotions language plpgsql set search_path = '' as $$
declare
  v_promo public.promotions;
begin
  select * into v_promo from public.promotions where id = p_promotion_id for update;
  if not found then
    raise exception 'Promo tidak ditemukan.';
  end if;
  if v_promo.status <> 'active' or v_promo.ends_at <= now() then
    raise exception 'Promo sudah berakhir.';
  end if;
  return v_promo;
end;
$$;

-- Validasi stok untuk barter (tanpa mengubah).
create function private.check_barter_stock(
  p_stock_id bigint, p_owner_id bigint, p_quantity double precision, p_label text)
returns void language plpgsql set search_path = '' as $$
declare
  v_stock public.stock_items;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Jumlah yang % harus lebih dari 0.', p_label;
  end if;
  select * into v_stock from public.stock_items where id = p_stock_id;
  if not found then
    raise exception 'Stok yang % sudah tidak ada.', p_label;
  end if;
  if v_stock.user_id <> p_owner_id then
    raise exception 'Stok yang % bukan milik pihak tersebut.', p_label;
  end if;
  if p_quantity > v_stock.quantity then
    raise exception 'Jumlah yang % melebihi stok (% %).',
      p_label, private.fmt_qty(v_stock.quantity), v_stock.unit;
  end if;
end;
$$;

-- Barter terbuka yang sedang menunggu jawaban dari p_actor (dikunci).
create function private.open_barter_awaiting(p_barter_id bigint, p_actor bigint)
returns public.barters language plpgsql set search_path = '' as $$
declare
  v_barter public.barters;
begin
  select * into v_barter from public.barters where id = p_barter_id for update;
  if not found then
    raise exception 'Barter tidak ditemukan.';
  end if;
  if v_barter.status not in ('pending', 'negotiating') then
    raise exception 'Barter sudah %.', lower(private.barter_status_label(v_barter.status));
  end if;
  if v_barter.last_actor_id = p_actor
     or p_actor not in (v_barter.proposer_id, v_barter.receiver_id) then
    raise exception 'Menunggu jawaban dari pihak lain.';
  end if;
  return v_barter;
end;
$$;

create function private.add_barter_message(
  p_barter_id bigint, p_sender_id bigint, p_text text,
  p_offered double precision default null, p_requested double precision default null)
returns void language sql set search_path = '' as $$
  insert into public.barter_messages (barter_id, sender_id, text, offered_quantity, requested_quantity)
  values (p_barter_id, p_sender_id, p_text, p_offered, p_requested)
$$;

-- Kurangi stok. Stok tidak dihapus walau habis (jumlah 0) agar riwayat
-- order/barter yang merujuknya tetap ada.
create function private.take_stock(
  p_stock_id bigint, p_owner_id bigint, p_quantity double precision)
returns public.stock_items language plpgsql set search_path = '' as $$
declare
  v_stock public.stock_items;
begin
  select * into v_stock from public.stock_items where id = p_stock_id for update;
  if not found then
    raise exception 'Stok sudah tidak ada.';
  end if;
  if v_stock.user_id <> p_owner_id then
    raise exception 'Stok bukan milik pihak tersebut.';
  end if;
  if p_quantity > v_stock.quantity + 1e-9 then
    raise exception 'Stok "%" tinggal % %, tidak cukup untuk %.',
      v_stock.name, private.fmt_qty(v_stock.quantity), v_stock.unit,
      private.fmt_qty(p_quantity);
  end if;
  update public.stock_items
    set quantity = greatest(quantity - p_quantity, 0), updated_at = now()
    where id = p_stock_id;
  return v_stock;
end;
$$;

-- Penerima mendapat bahan sebagai stok baru.
create function private.give_stock(
  p_source public.stock_items, p_to_user bigint, p_quantity double precision,
  p_price integer, p_note text)
returns void language sql set search_path = '' as $$
  insert into public.stock_items
    (user_id, name, category, quantity, unit, price_per_unit, expiry_date, notes)
  values
    (p_to_user, p_source.name, p_source.category, p_quantity, p_source.unit,
     p_price, p_source.expiry_date, p_note)
$$;

create function private.log_activity(
  p_user_id bigint, p_kind text, p_counterpart_id bigint, p_counterpart_name text,
  p_stock public.stock_items, p_quantity double precision, p_amount integer,
  p_saved integer, p_reference_type text, p_reference_id bigint)
returns void language sql set search_path = '' as $$
  insert into public.activity_log
    (user_id, kind, counterpart_id, counterpart_name, stock_name, category,
     quantity, unit, amount, saved_value, weight_kg, reference_type, reference_id)
  values
    (p_user_id, p_kind, p_counterpart_id, p_counterpart_name, p_stock.name,
     p_stock.category, p_quantity, p_stock.unit, p_amount, p_saved,
     p_quantity * private.unit_kg(p_stock.unit), p_reference_type, p_reference_id)
$$;

-- Helper privat hanya untuk fungsi RPC di bawah, bukan untuk dipanggil user.
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.app_uid() to authenticated;
grant execute on function private.promo_reserved(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC Pasar B2B
-- ---------------------------------------------------------------------------
create function public.create_order(
  p_promotion_id bigint, p_quantity double precision, p_note text default null)
returns public.orders
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_promo public.promotions;
  v_available double precision;
  v_order public.orders;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Jumlah harus lebih dari 0.';
  end if;
  v_promo := private.active_promotion(p_promotion_id);
  if v_promo.user_id = v_uid then
    raise exception 'Tidak bisa membeli promo sendiri.';
  end if;
  v_available := v_promo.quantity - private.promo_reserved(p_promotion_id);
  if p_quantity > v_available then
    raise exception 'Jumlah melebihi yang tersedia (%).',
      private.fmt_qty(greatest(v_available, 0));
  end if;
  insert into public.orders (promotion_id, buyer_id, seller_id, quantity, unit_price, note)
  values (p_promotion_id, v_uid, v_promo.user_id, p_quantity,
          private.promo_price(v_promo.original_price, v_promo.discount_percent),
          nullif(trim(p_note), ''))
  returning * into v_order;
  return v_order;
end;
$$;

-- Penjual: accepted/rejected. Pembeli: cancelled.
create function public.update_order_status(p_order_id bigint, p_status text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_order public.orders;
  v_promo public.promotions;
  v_available double precision;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_uid not in (v_order.buyer_id, v_order.seller_id) then
    raise exception 'Pengajuan tidak ditemukan.';
  end if;
  if p_status in ('accepted', 'rejected') and v_uid <> v_order.seller_id then
    raise exception 'Hanya penjual yang bisa menjawab pengajuan.';
  elsif p_status = 'cancelled' and v_uid <> v_order.buyer_id then
    raise exception 'Hanya pembeli yang bisa membatalkan pengajuan.';
  elsif p_status not in ('accepted', 'rejected', 'cancelled') then
    raise exception 'Status pengajuan tidak valid.';
  end if;
  if v_order.status <> 'pending' then
    raise exception 'Pengajuan sudah %.', lower(private.order_status_label(v_order.status));
  end if;
  if p_status = 'accepted' then
    v_promo := private.active_promotion(v_order.promotion_id);
    v_available := v_promo.quantity - private.promo_reserved(v_order.promotion_id);
    if v_order.quantity > v_available then
      raise exception 'Stok promo tidak cukup. Tersisa %.',
        private.fmt_qty(greatest(v_available, 0));
    end if;
  end if;
  update public.orders set status = p_status, updated_at = now() where id = p_order_id;
end;
$$;

-- Penjual menandai pesanan diterima sebagai selesai: stok pindah ke pembeli.
create function public.complete_order(p_order_id bigint)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_order public.orders;
  v_promo public.promotions;
  v_stock public.stock_items;
  v_seller_name text;
  v_buyer_name text;
  v_total integer;
  v_discount double precision;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_uid not in (v_order.buyer_id, v_order.seller_id) then
    raise exception 'Pesanan tidak ditemukan.';
  end if;
  if v_order.seller_id <> v_uid then
    raise exception 'Hanya penjual yang bisa menyelesaikan pesanan.';
  end if;
  if v_order.status <> 'accepted' then
    raise exception 'Pesanan berstatus "%", belum bisa diselesaikan.',
      private.order_status_label(v_order.status);
  end if;
  select * into v_promo from public.promotions where id = v_order.promotion_id;
  if not found then
    raise exception 'Promo tidak ditemukan.';
  end if;

  v_stock := private.take_stock(v_promo.stock_id, v_order.seller_id, v_order.quantity);
  v_seller_name := private.display_name(v_order.seller_id);
  v_buyer_name := private.display_name(v_order.buyer_id);
  perform private.give_stock(v_stock, v_order.buyer_id, v_order.quantity,
    v_order.unit_price, 'Dibeli dari ' || v_seller_name);

  update public.orders set status = 'completed', updated_at = now() where id = p_order_id;

  v_total := round(v_order.quantity * v_order.unit_price)::integer;
  v_discount := (v_promo.original_price - v_order.unit_price) * v_order.quantity;
  perform private.log_activity(v_order.seller_id, 'sale', v_order.buyer_id, v_buyer_name,
    v_stock, v_order.quantity, v_total, v_total, 'order', p_order_id);
  perform private.log_activity(v_order.buyer_id, 'purchase', v_order.seller_id, v_seller_name,
    v_stock, v_order.quantity, v_total,
    case when v_discount <= 0 then 0 else round(v_discount)::integer end,
    'order', p_order_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC Matchmaking & Barter
-- ---------------------------------------------------------------------------
create function public.create_barter(
  p_type text,
  p_receiver_id bigint,
  p_offered_stock_id bigint,
  p_offered_quantity double precision,
  p_requested_stock_id bigint default null,
  p_requested_quantity double precision default null,
  p_requested_note text default null,
  p_message text default null)
returns public.barters
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_barter public.barters;
begin
  if p_type not in ('barter', 'donation') then
    raise exception 'Jenis penawaran tidak valid.';
  end if;
  if p_receiver_id = v_uid then
    raise exception 'Tidak bisa barter dengan diri sendiri.';
  end if;
  perform private.check_barter_stock(p_offered_stock_id, v_uid, p_offered_quantity, 'ditawarkan');
  if p_requested_stock_id is not null then
    perform private.check_barter_stock(p_requested_stock_id, p_receiver_id,
      coalesce(p_requested_quantity, 0), 'diminta');
  elsif p_type = 'barter' and coalesce(trim(p_requested_note), '') = '' then
    raise exception 'Sebutkan bahan yang Anda minta.';
  end if;

  insert into public.barters (type, proposer_id, receiver_id, offered_stock_id,
    offered_quantity, requested_stock_id, requested_quantity, requested_note,
    status, last_actor_id)
  values (p_type, v_uid, p_receiver_id, p_offered_stock_id, p_offered_quantity,
    p_requested_stock_id, p_requested_quantity, nullif(trim(p_requested_note), ''),
    'pending', v_uid)
  returning * into v_barter;

  perform private.add_barter_message(v_barter.id, v_uid,
    coalesce(nullif(trim(p_message), ''),
      case when p_type = 'donation'
        then 'Mengajukan penyaluran stok untuk daur ulang.'
        else 'Mengajukan penawaran barter.' end),
    p_offered_quantity, p_requested_quantity);
  return v_barter;
end;
$$;

create function public.counter_offer(
  p_barter_id bigint,
  p_offered_quantity double precision,
  p_requested_quantity double precision default null,
  p_message text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_barter public.barters;
  v_requested double precision;
begin
  v_barter := private.open_barter_awaiting(p_barter_id, v_uid);
  v_requested := case when v_barter.requested_stock_id is null
    then v_barter.requested_quantity
    else coalesce(p_requested_quantity, v_barter.requested_quantity) end;
  perform private.check_barter_stock(v_barter.offered_stock_id, v_barter.proposer_id,
    p_offered_quantity, 'ditawarkan');
  if v_barter.requested_stock_id is not null then
    perform private.check_barter_stock(v_barter.requested_stock_id, v_barter.receiver_id,
      coalesce(v_requested, 0), 'diminta');
  end if;
  update public.barters set
    offered_quantity = p_offered_quantity,
    requested_quantity = v_requested,
    status = 'negotiating',
    last_actor_id = v_uid,
    updated_at = now()
  where id = p_barter_id;
  perform private.add_barter_message(p_barter_id, v_uid,
    coalesce(nullif(trim(p_message), ''), 'Mengajukan tawaran balik.'),
    p_offered_quantity, v_requested);
end;
$$;

create function public.respond_barter(p_barter_id bigint, p_accept boolean)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_barter public.barters;
begin
  v_barter := private.open_barter_awaiting(p_barter_id, v_uid);
  if p_accept then
    -- Stok bisa berubah selama negosiasi; cek ulang sebelum sepakat.
    perform private.check_barter_stock(v_barter.offered_stock_id, v_barter.proposer_id,
      v_barter.offered_quantity, 'ditawarkan');
    if v_barter.requested_stock_id is not null then
      perform private.check_barter_stock(v_barter.requested_stock_id, v_barter.receiver_id,
        coalesce(v_barter.requested_quantity, 0), 'diminta');
    end if;
  end if;
  update public.barters set
    status = case when p_accept then 'accepted' else 'rejected' end,
    last_actor_id = v_uid,
    updated_at = now()
  where id = p_barter_id;
  perform private.add_barter_message(p_barter_id, v_uid,
    case when p_accept then 'Menyetujui kesepakatan.' else 'Menolak penawaran.' end);
end;
$$;

create function public.cancel_barter(p_barter_id bigint)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_barter public.barters;
begin
  select * into v_barter from public.barters where id = p_barter_id for update;
  if not found or v_uid not in (v_barter.proposer_id, v_barter.receiver_id) then
    raise exception 'Barter tidak ditemukan.';
  end if;
  if v_barter.proposer_id <> v_uid then
    raise exception 'Hanya pengaju yang bisa membatalkan.';
  end if;
  if v_barter.status not in ('pending', 'negotiating') then
    raise exception 'Barter sudah %.', lower(private.barter_status_label(v_barter.status));
  end if;
  update public.barters set status = 'cancelled', last_actor_id = v_uid, updated_at = now()
  where id = p_barter_id;
  perform private.add_barter_message(p_barter_id, v_uid, 'Membatalkan penawaran.');
end;
$$;

create function public.send_barter_message(p_barter_id bigint, p_text text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_barter public.barters;
begin
  if coalesce(trim(p_text), '') = '' then
    return;
  end if;
  select * into v_barter from public.barters where id = p_barter_id;
  if not found then
    raise exception 'Barter tidak ditemukan.';
  end if;
  if v_uid not in (v_barter.proposer_id, v_barter.receiver_id) then
    raise exception 'Anda bukan bagian dari barter ini.';
  end if;
  perform private.add_barter_message(p_barter_id, v_uid, trim(p_text));
  update public.barters set updated_at = now() where id = p_barter_id;
end;
$$;

-- Salah satu pihak menandai barter/donasi yang disepakati sebagai selesai.
create function public.complete_barter(p_barter_id bigint)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_barter public.barters;
  v_is_donation boolean;
  v_proposer_name text;
  v_receiver_name text;
  v_offered public.stock_items;
  v_requested public.stock_items;
begin
  select * into v_barter from public.barters where id = p_barter_id for update;
  if not found then
    raise exception 'Barter tidak ditemukan.';
  end if;
  if v_uid not in (v_barter.proposer_id, v_barter.receiver_id) then
    raise exception 'Anda bukan bagian dari barter ini.';
  end if;
  if v_barter.status <> 'accepted' then
    raise exception 'Barter berstatus "%", belum bisa diselesaikan.',
      private.barter_status_label(v_barter.status);
  end if;
  v_is_donation := v_barter.type = 'donation';
  v_proposer_name := private.display_name(v_barter.proposer_id);
  v_receiver_name := private.display_name(v_barter.receiver_id);

  -- Pengaju → penerima (donasi: stok hanya berkurang, tidak masuk stok mitra)
  v_offered := private.take_stock(v_barter.offered_stock_id, v_barter.proposer_id,
    v_barter.offered_quantity);
  if not v_is_donation then
    perform private.give_stock(v_offered, v_barter.receiver_id, v_barter.offered_quantity,
      v_offered.price_per_unit, 'Barter dengan ' || v_proposer_name);
  end if;
  perform private.log_activity(v_barter.proposer_id,
    case when v_is_donation then 'donationOut' else 'barterOut' end,
    v_barter.receiver_id, v_receiver_name, v_offered, v_barter.offered_quantity, 0,
    case when v_is_donation then 0
      else round(v_barter.offered_quantity * v_offered.price_per_unit)::integer end,
    'barter', p_barter_id);
  perform private.log_activity(v_barter.receiver_id,
    case when v_is_donation then 'donationIn' else 'barterIn' end,
    v_barter.proposer_id, v_proposer_name, v_offered, v_barter.offered_quantity, 0, 0,
    'barter', p_barter_id);

  -- Penerima → pengaju (hanya jika yang diminta adalah stok tercatat)
  if not v_is_donation and v_barter.requested_stock_id is not null
     and v_barter.requested_quantity is not null then
    v_requested := private.take_stock(v_barter.requested_stock_id, v_barter.receiver_id,
      v_barter.requested_quantity);
    perform private.give_stock(v_requested, v_barter.proposer_id, v_barter.requested_quantity,
      v_requested.price_per_unit, 'Barter dengan ' || v_receiver_name);
    perform private.log_activity(v_barter.receiver_id, 'barterOut',
      v_barter.proposer_id, v_proposer_name, v_requested, v_barter.requested_quantity, 0,
      round(v_barter.requested_quantity * v_requested.price_per_unit)::integer,
      'barter', p_barter_id);
    perform private.log_activity(v_barter.proposer_id, 'barterIn',
      v_barter.receiver_id, v_receiver_name, v_requested, v_barter.requested_quantity, 0, 0,
      'barter', p_barter_id);
  end if;

  update public.barters set status = 'completed', last_actor_id = v_uid, updated_at = now()
  where id = p_barter_id;
  perform private.add_barter_message(p_barter_id, v_uid,
    'Menandai barter selesai. Stok sudah dipindahkan.');
end;
$$;

-- Hanya user login yang boleh memanggil RPC.
revoke all on function
  public.create_order(bigint, double precision, text),
  public.update_order_status(bigint, text),
  public.complete_order(bigint),
  public.create_barter(text, bigint, bigint, double precision, bigint, double precision, text, text),
  public.counter_offer(bigint, double precision, double precision, text),
  public.respond_barter(bigint, boolean),
  public.cancel_barter(bigint),
  public.send_barter_message(bigint, text),
  public.complete_barter(bigint)
from public, anon;
grant execute on function
  public.create_order(bigint, double precision, text),
  public.update_order_status(bigint, text),
  public.complete_order(bigint),
  public.create_barter(text, bigint, bigint, double precision, bigint, double precision, text, text),
  public.counter_offer(bigint, double precision, double precision, text),
  public.respond_barter(bigint, boolean),
  public.cancel_barter(bigint),
  public.send_barter_message(bigint, text),
  public.complete_barter(bigint)
to authenticated;
