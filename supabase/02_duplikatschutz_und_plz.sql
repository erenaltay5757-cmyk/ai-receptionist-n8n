-- =====================================================================
-- AI Terminassistent – SHK: Ergänzung zur technischen Härtung
-- Einmal im Supabase SQL Editor ausführen. Nicht-destruktiv und mehrfach
-- ausführbar. Es werden keine vorhandenen Daten verändert oder gelöscht.
-- =====================================================================

-- Kontrollabfrage vor dem Index (muss 0 Zeilen liefern):
select betrieb_id, anfrage_id, count(*) as anzahl
from public.anfragen
group by betrieb_id, anfrage_id
having count(*) > 1;

-- 1. Schutz vor doppelten Kundenanfragen, auch bei parallelen Vapi-Aufrufen
--    (zweiter Insert derselben Anruf-ID wird mit 23505 abgewiesen; der
--    Workflow liest dann die bestehende Anfrage und verwendet sie weiter).
create unique index if not exists anfragen_betrieb_anfrage_id_uidx
  on public.anfragen (betrieb_id, anfrage_id);

-- 2. Postleitzahl als eigenes Feld an Anfrage und Kunde (genau 5 Ziffern oder leer;
--    WhatsApp- und Telefonanfragen haben zunächst keine PLZ)
alter table public.anfragen
  add column if not exists plz text
    constraint anfragen_plz_format check (coalesce(plz, '') ~ '^([0-9]{5})?$');

alter table public.kunden
  add column if not exists plz text
    constraint kunden_plz_format check (coalesce(plz, '') ~ '^([0-9]{5})?$');
