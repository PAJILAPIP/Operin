-- Operin: Katalog Pasar B2B — beli stok UMKM lain dengan harga normal,
-- tanpa harus menunggu promo. Jalankan setelah 0001 & 0002.

-- ---------------------------------------------------------------------------
-- Pesanan merujuk stok langsung; promo menjadi opsional.
-- ---------------------------------------------------------------------------
alter table public.orders
  add column stock_id bigint references public.stock_items (id) on delete cascade;

update public.orders o set stock_id = p.stock_id
from public.promotions p
where p.id = o.promotion_id and o.stock_id is null;

alter table public.orders alter column stock_id set not null;
alter table public.orders alter column promotion_id drop not null;
create index idx_order_stock on public.orders (stock_id, status);

-- Jumlah stok yang sudah dijanjikan (pesanan diterima, belum selesai).
create function private.stock_reserved(p_stock_id bigint)
returns double precision
language sql stable security definer
set search_path = ''
as $$
  select coalesce(sum(quantity), 0)::double precision
  from public.orders
  where stock_id = p_stock_id and status = 'accepted'
$$;

revoke all on function private.stock_reserved(bigint) from public, anon;
grant execute on function private.stock_reserved(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- View
-- ---------------------------------------------------------------------------

-- Kolom orders berubah → view detail pesanan dibuat ulang (stok via stock_id).
drop view public.order_details;
create view public.order_details with (security_invoker = true) as
select o.*,
  s.name as stock_name, s.unit as stock_unit,
  coalesce(bb.business_name, bu.full_name) as buyer_name,
  coalesce(sb.business_name, su.full_name) as seller_name
from public.orders o
join public.stock_items s on s.id = o.stock_id
join public.users bu on bu.id = o.buyer_id
left join public.business_profiles bb on bb.user_id = o.buyer_id
join public.users su on su.id = o.seller_id
left join public.business_profiles sb on sb.user_id = o.seller_id;

-- Katalog: stok layak jual (jumlah > 0, belum kedaluwarsa) milik UMKM yang
-- sudah onboarding. Stok yang sedang promo tampil di Flash Sale/Sale saja.
create view public.catalog_items with (security_invoker = true) as
select s.*,
  u.full_name as seller_full_name, u.address as seller_address,
  u.latitude as seller_lat, u.longitude as seller_lng,
  b.business_name as seller_business_name, b.whatsapp as seller_whatsapp,
  private.stock_reserved(s.id) as reserved
from public.stock_items s
join public.users u on u.id = s.user_id
left join public.business_profiles b on b.user_id = s.user_id
where s.quantity > 0
  and s.expiry_date >= current_date
  and u.role is not null
  and not exists (
    select 1 from public.promotions p
    where p.stock_id = s.id and p.status = 'active' and p.ends_at > now()
  );

revoke all on public.order_details, public.catalog_items from anon;
grant select on public.order_details, public.catalog_items to authenticated;

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------

-- Ajukan pembelian stok katalog (harga normal).
create function public.create_stock_order(
  p_stock_id bigint, p_quantity double precision, p_note text default null)
returns public.orders
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_stock public.stock_items;
  v_available double precision;
  v_order public.orders;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Jumlah harus lebih dari 0.';
  end if;
  select * into v_stock from public.stock_items where id = p_stock_id for update;
  if not found or v_stock.quantity <= 0 then
    raise exception 'Stok sudah tidak tersedia.';
  end if;
  if v_stock.user_id = v_uid then
    raise exception 'Tidak bisa membeli stok sendiri.';
  end if;
  if v_stock.expiry_date < current_date then
    raise exception 'Stok sudah kedaluwarsa.';
  end if;
  v_available := v_stock.quantity - private.stock_reserved(p_stock_id);
  if p_quantity > v_available then
    raise exception 'Jumlah melebihi yang tersedia (%).',
      private.fmt_qty(greatest(v_available, 0));
  end if;
  insert into public.orders (promotion_id, stock_id, buyer_id, seller_id, quantity, unit_price, note)
  values (null, p_stock_id, v_uid, v_stock.user_id, p_quantity, v_stock.price_per_unit,
          nullif(trim(p_note), ''))
  returning * into v_order;
  return v_order;
end;
$$;

-- Pesanan promo kini juga menyimpan stock_id.
create or replace function public.create_order(
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
  insert into public.orders (promotion_id, stock_id, buyer_id, seller_id, quantity, unit_price, note)
  values (p_promotion_id, v_promo.stock_id, v_uid, v_promo.user_id, p_quantity,
          private.promo_price(v_promo.original_price, v_promo.discount_percent),
          nullif(trim(p_note), ''))
  returning * into v_order;
  return v_order;
end;
$$;

create or replace function public.update_order_status(p_order_id bigint, p_status text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid bigint := private.require_user();
  v_order public.orders;
  v_promo public.promotions;
  v_stock public.stock_items;
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
    if v_order.promotion_id is not null then
      v_promo := private.active_promotion(v_order.promotion_id);
      v_available := v_promo.quantity - private.promo_reserved(v_order.promotion_id);
      if v_order.quantity > v_available then
        raise exception 'Stok promo tidak cukup. Tersisa %.',
          private.fmt_qty(greatest(v_available, 0));
      end if;
    else
      select * into v_stock from public.stock_items where id = v_order.stock_id for update;
      v_available := coalesce(v_stock.quantity, 0) - private.stock_reserved(v_order.stock_id);
      if v_order.quantity > v_available then
        raise exception 'Stok tidak cukup. Tersisa %.',
          private.fmt_qty(greatest(v_available, 0));
      end if;
    end if;
  end if;
  update public.orders set status = p_status, updated_at = now() where id = p_order_id;
end;
$$;

create or replace function public.complete_order(p_order_id bigint)
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
  v_discount double precision := 0;
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
  if v_order.promotion_id is not null then
    select * into v_promo from public.promotions where id = v_order.promotion_id;
    if found then
      v_discount := (v_promo.original_price - v_order.unit_price) * v_order.quantity;
    end if;
  end if;

  v_stock := private.take_stock(v_order.stock_id, v_order.seller_id, v_order.quantity);
  v_seller_name := private.display_name(v_order.seller_id);
  v_buyer_name := private.display_name(v_order.buyer_id);
  perform private.give_stock(v_stock, v_order.buyer_id, v_order.quantity,
    v_order.unit_price, 'Dibeli dari ' || v_seller_name);

  update public.orders set status = 'completed', updated_at = now() where id = p_order_id;

  v_total := round(v_order.quantity * v_order.unit_price)::integer;
  perform private.log_activity(v_order.seller_id, 'sale', v_order.buyer_id, v_buyer_name,
    v_stock, v_order.quantity, v_total, v_total, 'order', p_order_id);
  perform private.log_activity(v_order.buyer_id, 'purchase', v_order.seller_id, v_seller_name,
    v_stock, v_order.quantity, v_total,
    case when v_discount <= 0 then 0 else round(v_discount)::integer end,
    'order', p_order_id);
end;
$$;

revoke all on function public.create_stock_order(bigint, double precision, text) from public, anon;
grant execute on function public.create_stock_order(bigint, double precision, text) to authenticated;
