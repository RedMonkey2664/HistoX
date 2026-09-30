# Shipaton 2026 · Next Gen award · submission pack

Everything the entry form asks for, and where it is.

**Deadline:** 30 September 2026, 11:45pm PDT, which is 1 October, 12:15pm IST.

## Checklist

| Requirement | Where it is | State |
|---|---|---|
| Public repository | <https://github.com/RedMonkey2664/RevenueCat> | done |
| Open-source licence, detectable at the top of the repo page | `LICENSE`, MIT, GitHub shows it in the sidebar | done |
| RevenueCat SDK powering a purchase | `lib/core/services/revenuecat_service.dart` | done |
| 1024x1024 app icon | `docs/submission/app_icon_1024.png` | done |
| Screenshot, 1179x2556, no device frame | `docs/screenshots/`, regenerate with the command below | regenerate |
| Demo video, under 2 minutes, YouTube or Vimeo | shot list in `docs/DEMO_SCRIPT.md` | **to record** |
| Text description of features | below | ready |
| Student or academic email | your NMIMS address | verify it passes |
| Published app URL | not required for Next Gen | n/a |

## Regenerating the screenshots

```sh
MN_SHOTS_DIR=build/screens flutter test tool/screens/capture_test.dart
```

Writes 1179x2556 PNGs with no device frame. The six worth submitting, in
the order `docs/STORE_LISTING.md` recommends:

1. `04_level_halted`, the pause point, which is the hook
2. `06_debrief`, the Discipline Score
3. `01_campaign_home`, the campaign map
4. the Daily Pivot question
5. `17_profile_share_card`, the Nerve Profile card
6. `13_live_markets_feed_states`, the watchlist

## Two places the video URL goes

Once the video is up, search the repository for `VIDEO_URL` and replace the
placeholder beside each marker. There are two, both in `README.md`.

```sh
grep -rn "REPLACE_ME" README.md
```

## Description, for the entry form

> HistoX drops you inside a real market crash and finds out how you actually
> behave.
>
> You start already invested, with virtual capital, in a fall that has
> already begun. You are not told which crash it is or what you are holding.
> The tape rolls, and at scripted moments it stops and asks one question:
> hold, sell all, or buy the dip. There is no timer. Afterwards the Debrief
> scores your discipline out of 100 against what price actually did next,
> breaks down every call with its real outcome, and compares the run against
> your earlier ones: how often you sold into a fall before, and how deep the
> fall usually was when you did.
>
> Seventeen playable crashes across US, Indian and crypto markets, from Black
> Monday 1987 through the dot-com collapse, 2008, demonetisation, COVID and
> the crypto winter. Every price, date and "historically optimal move" is
> computed from a real price series by an importer in the repository. Nothing
> is typed by hand, and `tool/validation/` regenerates the whole validation
> report offline so the claims can be rechecked by anyone with a clone.
>
> Also inside: a Daily Pivot, one sealed call a day on Bitcoin resolved
> against real prices; Time Machine, a what-if compounding calculator with a
> shareable card; Live Markets, a read-only watchlist that shows the source
> and staleness of every price it prints; and a Nerve Profile, a five-axis
> read of how you trade under stress.
>
> No real money anywhere. Every position is virtual, the app cannot place a
> trade, and Daily Pivot points have no cash value.
>
> RevenueCat powers HistoX Pro, which unlocks fifteen of the seventeen
> crashes and the full Nerve Profile. The app talks to the store through a
> single `PurchasesService` interface, so tests and the web demo swap it out
> without touching a screen. Prices come from the current offering's annual
> and monthly packages exactly as the store formats them, entitlement is a
> customer-info listener pushing renewals and cross-device purchases to every
> locked screen, and a build with no key falls back to an honest "store not
> connected" state rather than a price it cannot charge.
>
> Built solo in Flutter. 26k lines, 208 tests, CI running the analyzer, the
> suite and an offline data validation that fails if the committed report
> drifts. `AUDIT_REPORT.md` is a self-audit written before submitting: it
> records a blocker where a release build would have handed every user Pro
> for free, an Android manifest that would have shipped with no network
> permission, and five levels where a player can score 100 by tapping Hold
> repeatedly, which is still open.

## Judge access to Pro

There is no promo code, because there is no store release to redeem one
against. The web preview is built with the admin panel on, so every Pro
level and the full Nerve Profile can be opened without a purchase:

<https://revenue-cat-redmonkey2664s-projects.vercel.app>

The paywall itself is live. It reads its offering, packages and prices from
the RevenueCat dashboard through the Test Store, so the purchase flow runs
end to end with no money moving. A phone release build refuses both the
admin panel and the Test Store key; `lib/app/admin_mode.dart` says why.

## GitHub repository page

The About field is empty, so GitHub is showing its generic placeholder to
anyone who lands there. Suggested:

> HistoX: a behavioural finance simulator that drops you into real market
> crashes and scores your discipline. Flutter, RevenueCat. Shipaton 2026 Next
> Gen.

Website: `https://revenue-cat-redmonkey2664s-projects.vercel.app`

Topics: `flutter`, `dart`, `revenuecat`, `riverpod`, `fintech`,
`behavioural-finance`, `shipaton`

## Still to do

1. Record the video against `docs/DEMO_SCRIPT.md`, upload it, replace both
   `REPLACE_ME` placeholders.
2. Regenerate the screenshots and commit the six listed above.
3. Confirm the student email passes the entry form's domain check.
4. Fill the form.
