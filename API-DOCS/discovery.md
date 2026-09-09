# How the endpoint list was produced

The list in [endpoints.md](endpoints.md) was not guessed. It was recorded by using the
real Neptun web client with a network interceptor installed, then reading back what it
called.

This took an afternoon and overturned two conclusions that had stood for weeks. If you
are about to write "the API does not support X", do this first.

## Method

1. **Open the institution's Neptun web client** in a Playwright-driven browser.

2. **Install the interceptor before logging in**, so the auth calls are captured too.
   The script lives at `~/Documents/neptun/tool/api_capture.js`. It is injected with
   both `page.addInitScript` (so it survives navigation) and a one-off `page.evaluate`
   (for the page already open).

   It wraps `fetch` and `XMLHttpRequest`, and appends `METHOD path -> status` to
   `localStorage` under `__nhnk_api_log_v2`.

3. **Log in by hand.** Do not automate this. Typing credentials through tooling puts
   them in transcripts and logs, and the browser's accessibility snapshot returns the
   contents of the form fields while you type.

4. **Click through the site.** Menu, submenus, every list and overview.

5. **Read the log back** from `localStorage`.

## Rules that made this safe

**Only method, path and status are recorded.** Never response bodies: they hold grades,
messages, financial records and personal details. Query strings are stripped too,
because they carry identifiers.

**Never click anything that submits.** Loading a form page is a GET and is harmless,
but the buttons on it are not. Course registration, exam signup, semester registration,
module and specialisation selection, dorm and student card applications, student loan
requests, questionnaires. In Hungarian, treat anything containing *jelentkezés,
igénylés, felvétel, regisztráció, kérelem* or *választás* as off limits.

**Log out afterwards** if a session was captured anywhere it might persist.

## Probing response shapes

Knowing a route exists is not enough; you need its shape, and you want that without
printing anybody's data.

`~/Documents/neptun/probe*.py` authenticate with the credentials in that project's
`.env` and print **field paths and types only**. `tool/json_shape.py` in this repo does
the same for anything piped into it:

    curl -s '<url>' -H 'Authorization: Bearer <token>' | python3 tool/json_shape.py

It prints `$.data.requiredCredit  int` rather than the number. It also detects the
common `{"message": "..."}` error envelope and says so, which saves confusion when a
token has quietly expired.

Tokens last about five minutes. If a probe returns an auth error, that is almost
certainly why. The fastest route is devtools, right click the request, Copy as cURL,
and paste it into a terminal straight away.

## Adding an endpoint to NHNK

1. Confirm the shape with a probe. Record it in [schemas.md](schemas.md), including
   which fields came back null.
2. Add the path as a constant on `ModernApi` in `lib/API/api_coms.dart`.
3. Fetch it through `ModernApi.fetchData`, which handles the capability caching, the
   legacy API, demo mode and missing sessions.
4. **Keep the old path as the fallback.** Every institution is different and a null
   return must degrade to previous behaviour, not to an error.
5. Add a test that the feature still behaves when the endpoint returns nothing. See
   `test/modern_api_test.dart`.
