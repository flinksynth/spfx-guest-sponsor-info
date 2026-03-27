---
layout: page
lang: en
title: Features
permalink: /en/features/
description: >-
  Explore all features of the Guest Sponsor Info web part —
  live sponsor cards, Teams presence, 14 languages, and more.
---

Guest Sponsor Info is purpose-built for the moment a B2B guest user lands in
your Microsoft 365 tenant and needs to know who their internal contact is.

## Live Sponsor Cards

Rich contact cards show the guest's assigned sponsors with live profile photos,
display name, job title, email, phone number, and office address — all loaded
directly from Microsoft Graph. No stale data, no manual maintenance.

The web part supports three layout modes: **Full** (detailed cards), **Compact**
(condensed for narrower columns), and **Auto** (adapts to the available space).

## Real-Time Teams Presence

Coloured presence indicators show whether a sponsor is Available, Busy, In a
Meeting, Away, Out of Office, Focusing, Do Not Disturb, or Offline. Updates
automatically with intelligent polling intervals.

## Teams Chat & Call Integration

One-click deep links let guests start a Teams chat or call directly from the
sponsor card. The web part detects when Teams hasn't been provisioned for a
guest yet and shows a helpful explanation instead of a broken link.

## Privacy-First Architecture

All data stays within your Microsoft 365 and Azure tenant. The web part makes
no external calls, sends no telemetry to third parties, and stores nothing
outside the browser session. The Azure Function proxy ensures guests never need
directory-level permissions.

For full details, see the
[Privacy Policy](https://github.com/workoho/spfx-guest-sponsor-info/blob/main/docs/privacy-policy.md).

## 14 Languages

Built-in support for English, German, French, Spanish, Italian, Danish, Finnish,
Japanese, Norwegian, Swedish, Chinese (Simplified), Portuguese (Brazil), Polish,
and Dutch. Languages with T–V distinction (du/Sie, tu/vous) support both formal
and informal modes.

## Automatic Sponsor Delegation

When multiple sponsors are assigned in priority order, the web part skips
unavailable sponsors automatically. Disabled accounts, shared mailboxes, and
deleted users are filtered out — guests always see active, reachable contacts.

## Guest Sponsor API (Azure Function)

The included Azure Function acts as a secure proxy between the guest's browser
and Microsoft Graph. It uses EasyAuth + Managed Identity, so guests never need
`User.Read.All` or other directory-level permissions. Rate limiting and
exponential backoff are built in.

## Editor Preview Mode

Page editors see realistic demo cards with mock data — no Graph calls, no guest
account required. This makes it easy to design the landing page layout before
any guests have been invited.

---

For the complete feature documentation, architecture decisions, and known
limitations, see the
[full documentation on GitHub](https://github.com/workoho/spfx-guest-sponsor-info/blob/main/docs/features.md).
