---
layout: page
lang: de
title: Funktionen
permalink: /de/features/
description: >-
  Alle Funktionen des Guest Sponsor Info Web Parts — Live-Sponsor-Karten,
  Teams-Präsenz, 14 Sprachen und mehr.
---

Guest Sponsor Info ist speziell für den Moment entwickelt, in dem ein
B2B-Gastbenutzer in Ihrem Microsoft 365 Tenant landet und wissen muss,
wer sein interner Ansprechpartner ist.

## Live-Sponsor-Karten

Kontaktkarten zeigen die zugewiesenen Sponsoren des Gastes mit Live-
Profilfotos, Anzeigenamen, Jobtitel, E-Mail, Telefonnummer und
Büroadresse — alles direkt aus Microsoft Graph geladen. Keine veralteten
Daten, keine manuelle Pflege.

Das Web Part unterstützt drei Layout-Modi: **Vollständig** (detaillierte
Karten), **Kompakt** (für schmalere Spalten) und **Auto** (passt sich dem
verfügbaren Platz an).

## Echtzeit-Teams-Präsenz

Farbige Präsenz-Indikatoren zeigen, ob ein Sponsor verfügbar, beschäftigt,
in einer Besprechung, abwesend, nicht im Büro, fokussiert, nicht stören
oder offline ist. Die Aktualisierung erfolgt automatisch mit intelligenten
Abfrageintervallen.

## Teams-Chat & -Anruf-Integration

Ein-Klick-Deeplinks ermöglichen es Gästen, direkt aus der Sponsor-Karte
einen Teams-Chat oder -Anruf zu starten. Das Web Part erkennt, wenn Teams
für einen Gast noch nicht bereitgestellt wurde, und zeigt stattdessen eine
hilfreiche Erklärung an.

## Privacy-First-Architektur

Alle Daten bleiben innerhalb Ihres Microsoft 365 und Azure Tenants. Das
Web Part macht keine externen Aufrufe, sendet keine Telemetrie an Dritte
und speichert nichts außerhalb der Browser-Sitzung. Der Azure Function
Proxy stellt sicher, dass Gäste nie Verzeichnis-Berechtigungen benötigen.

Die vollständige Datenschutzrichtlinie finden Sie in der
[Datenschutzrichtlinie auf GitHub](https://github.com/workoho/spfx-guest-sponsor-info/blob/main/docs/privacy-policy.md).

## 14 Sprachen

Integrierte Unterstützung für Englisch, Deutsch, Französisch, Spanisch,
Italienisch, Dänisch, Finnisch, Japanisch, Norwegisch, Schwedisch,
Chinesisch (vereinfacht), Portugiesisch (Brasilien), Polnisch und
Niederländisch. Sprachen mit T-V-Unterscheidung (du/Sie, tu/vous)
unterstützen sowohl formelle als auch informelle Modi.

## Automatische Sponsor-Delegation

Wenn mehrere Sponsoren in Prioritätsreihenfolge zugewiesen sind, überspringt
das Web Part nicht verfügbare Sponsoren automatisch. Deaktivierte Konten,
geteilte Postfächer und gelöschte Benutzer werden ausgefiltert — Gäste sehen
immer aktive, erreichbare Kontakte.

## Guest Sponsor API (Azure Function)

Die mitgelieferte Azure Function dient als sicherer Proxy zwischen dem
Browser des Gastes und Microsoft Graph. Sie verwendet EasyAuth + Managed
Identity, sodass Gäste niemals `User.Read.All` oder andere
Verzeichnis-Berechtigungen benötigen. Rate-Limiting und exponentielles
Backoff sind integriert.

## Vorschaumodus für Editoren

Seitenbearbeiter sehen realistische Demo-Karten mit Beispieldaten — keine
Graph-Aufrufe, kein Gastkonto erforderlich. So lässt sich das Seitenlayout
einfach gestalten, bevor Gäste eingeladen wurden.

---

Die vollständige Funktionsdokumentation, Architektur-Entscheidungen und
bekannte Einschränkungen finden Sie in der
[ausführlichen Dokumentation auf GitHub](https://github.com/workoho/spfx-guest-sponsor-info/blob/main/docs/features.md).
