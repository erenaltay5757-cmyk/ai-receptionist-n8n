-- =====================================================================
-- AI Terminassistent – SHK: Datenbank-Migration
-- Einmal im Supabase SQL Editor ausführen. Nicht-destruktiv und mehrfach
-- ausführbar (nur CREATE ... IF NOT EXISTS / ADD COLUMN IF NOT EXISTS).
-- Es werden keine vorhandenen Daten verändert oder gelöscht.
-- =====================================================================

-- Erweiterung für den Überschneidungsschutz (Gleichheit + Zeitbereich in einem Index)
create extension if not exists btree_gist;

-- ---------------------------------------------------------------------
-- 1. Termine (Vorschläge, Reservierungen, Buchungen)
-- ---------------------------------------------------------------------
create table if not exists public.termine (
  id                   uuid primary key default gen_random_uuid(),
  betrieb_id           uuid not null,
  anfrage_db_id        uuid not null references public.anfragen (id),
  terminart            text not null,
  ressource_id         text not null,
  kalender_anbieter    text not null default 'test'
                       check (kalender_anbieter in ('test', 'outlook')),
  status               text not null default 'vorgeschlagen'
                       check (status in ('vorgeschlagen', 'reserviert', 'gebucht',
                                         'abgelehnt', 'abgelaufen', 'storniert', 'fehler')),
  kunden_bestaetigung  text not null default 'offen'
                       check (kunden_bestaetigung in ('offen', 'bestaetigt', 'abgelehnt')),
  start_at             timestamptz not null,           -- intern immer als Zeitpunkt (UTC) gespeichert
  ende_at              timestamptz not null,
  puffer_vor_minuten   integer not null default 0 check (puffer_vor_minuten >= 0),
  puffer_nach_minuten  integer not null default 0 check (puffer_nach_minuten >= 0),
  belegt_von           timestamptz not null,           -- start_at minus Puffer
  belegt_bis           timestamptz not null,           -- ende_at plus Puffer
  zeitzone             text not null default 'Europe/Berlin',
  vorschlag_gruppe     text,
  vorschlag_nummer     smallint,
  gueltig_bis          timestamptz,
  externe_event_id     text,
  idempotenz_id        text,
  fehler_code          text,
  fehler_text          text,
  bestaetigt_at        timestamptz,
  gebucht_at           timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint termine_ende_nach_start check (ende_at > start_at),
  constraint termine_puffer_umfasst_termin check (belegt_von <= start_at and belegt_bis >= ende_at),
  constraint termine_idempotenz_bei_buchung
    check (status not in ('reserviert', 'gebucht') or idempotenz_id is not null),

  -- Technischer Doppelbuchungsschutz, auch bei parallelen Buchungsversuchen:
  -- Reservierte oder gebuchte Termine derselben Ressource dürfen sich
  -- (inklusive Puffer) nicht überschneiden.
  constraint termine_keine_ueberschneidung exclude using gist (
    betrieb_id with =,
    ressource_id with =,
    tstzrange(belegt_von, belegt_bis, '[)') with &&
  ) where (status in ('reserviert', 'gebucht'))
);

-- Derselbe bestätigte Termin kann nur einmal reserviert/gebucht werden
create unique index if not exists termine_idempotenz_uidx
  on public.termine (idempotenz_id)
  where idempotenz_id is not null;

-- Eine Anfrage kann nur einen aktiven (reservierten/gebuchten) Termin haben –
-- verhindert Doppelbuchungen, wenn ein Kunde parallel zwei Vorschläge bestätigt
create unique index if not exists termine_ein_aktiver_termin_je_anfrage_uidx
  on public.termine (anfrage_db_id)
  where status in ('reserviert', 'gebucht');

-- Ein externer Kalendereintrag gehört zu genau einem Termin
create unique index if not exists termine_externe_event_uidx
  on public.termine (kalender_anbieter, externe_event_id)
  where externe_event_id is not null;

create index if not exists termine_anfrage_idx
  on public.termine (betrieb_id, anfrage_db_id, status);

create index if not exists termine_ressource_zeit_idx
  on public.termine (betrieb_id, ressource_id, belegt_von, belegt_bis)
  where status in ('reserviert', 'gebucht');

alter table public.termine enable row level security;
-- Hinweis: n8n nutzt den Service-Key (umgeht RLS). Für ein späteres Dashboard
-- müssen passende Policies ergänzt werden.

-- ---------------------------------------------------------------------
-- 2. Terminstatus an Anfrage und Aufgabe
-- ---------------------------------------------------------------------
alter table public.anfragen
  add column if not exists termin_status text
    check (termin_status in ('vorgeschlagen', 'kundenbestaetigt', 'gebucht', 'mitarbeiterpruefung', 'fehler')),
  add column if not exists termin_id uuid references public.termine (id);

alter table public.aufgaben
  add column if not exists termin_status text
    check (termin_status in ('vorgeschlagen', 'kundenbestaetigt', 'gebucht', 'mitarbeiterpruefung', 'fehler')),
  add column if not exists termin_id uuid references public.termine (id);
