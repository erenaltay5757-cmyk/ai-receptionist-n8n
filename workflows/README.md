# n8n-Workflows

| Datei | Inhalt |
|---|---|
| `ai-receptionist-main.json` | Hauptworkflow: Eingänge, KI-Analyse, Speicherung, Übergabe (99 Nodes) |
| `ai-terminassistent-subworkflow.json` | Unterworkflow: Terminvorschläge, Buchung, Verschiebung, Storno (60 Nodes) |

## Was für die Veröffentlichung geändert wurde

Die Logik ist unverändert. Ersetzt beziehungsweise entfernt wurde Folgendes:

- Zugangsdaten: Jeder Credential-Verweis heißt jetzt `YOUR_CREDENTIAL_ID` / `YOUR_…_CREDENTIAL`. Echte Schlüssel standen nie in den Dateien, weil n8n sie getrennt speichert.
- Supabase-Projekt-URL → `https://YOUR_PROJECT.supabase.co`
- n8n-Instanz → `https://YOUR_N8N_INSTANCE`
- Twilio Account SID → `YOUR_TWILIO_ACCOUNT_SID`, Absendernummer → `EXAMPLE_PHONE_NUMBER`
- E-Mail-Adressen → `YOUR_EMAIL@example.com`
- Betriebs-ID → `00000000-0000-0000-0000-000000000001`, Einsatzgebiet → `12345` / `Musterstadt`
- ID des Unterworkflows → `YOUR_SUBWORKFLOW_ID`
- Node- und Webhook-IDs wurden neu vergeben. Interne Metadaten, Versions-IDs und gespeicherte Testdaten (Pin-Daten) wurden entfernt.

## Import (optional)

1. In n8n: **Workflows → Import from File** und erst den Unterworkflow, dann den Hauptworkflow importieren.
2. In den vier „Execute Workflow“-Nodes `Terminassistent: …` des Hauptworkflows den importierten Unterworkflow auswählen.
3. Zugangsdaten für Supabase, OpenAI, Vapi und Twilio anlegen und den Nodes zuweisen.
4. Im Node `Betriebskonfiguration` die Platzhalter ersetzen.
5. Die Tabellen in Supabase anlegen (siehe [`../docs/datenmodell.md`](../docs/datenmodell.md) und [`../supabase/`](../supabase/)).

Die Dateien sind vor allem zum Ansehen gedacht. Ein vollständiger Nachbau braucht zusätzlich einen eingerichteten Vapi-Assistenten und die Datenbanktabellen.
