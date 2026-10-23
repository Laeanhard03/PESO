# PESO / JobKonek bundled image assets

These compressed JPEG copies are stored locally under `lib/assets/` and included by
the existing Flutter asset declaration in `pubspec.yaml` (`lib/assets/`). Static
banners and fallback images ship with the app and do not require an image-host
request at runtime.

The source column records the actual Unsplash image-CDN URLs used to download each
local copy. The query parameters select a cropped/resized JPEG; these URLs are not
municipal or employer-owned images. Check the current Unsplash license and any
applicable model/property release requirements before public production use, and
do not imply the people in stock photos endorse PESO or the municipality.

| Local file | Source image URL |
|---|---|
| `peso_hero_career.jpg` | https://images.unsplash.com/photo-1573164713988-8665fc963095?fit=crop&w=1600&h=1000&q=82&fm=jpg |
| `peso_programs_workshop.jpg` | https://images.unsplash.com/photo-1552664730-d307ca884978?fit=crop&w=1400&h=900&q=80&fm=jpg |
| `peso_about_team.jpg` | https://images.unsplash.com/photo-1522071820081-009f0129c71c?fit=crop&w=1000&h=700&q=80&fm=jpg |
| `peso_gallery_conference.jpg` | https://images.unsplash.com/photo-1542744173-8e7e53415bb0?fit=crop&w=1000&h=700&q=78&fm=jpg |
| `peso_gallery_workspace.jpg` | https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?fit=crop&w=1000&h=700&q=78&fm=jpg |
| `peso_gallery_team.jpg` | https://images.unsplash.com/photo-1528605105345-5344ea20e269?fit=crop&w=1000&h=700&q=78&fm=jpg |
| `peso_gallery_meeting.jpg` | https://images.unsplash.com/photo-1556761175-4b46a572b786?fit=crop&w=1000&h=700&q=78&fm=jpg |
| `peso_gallery_event.jpg` | https://images.unsplash.com/photo-1517048676732-d65bc937f952?fit=crop&w=1000&h=700&q=78&fm=jpg |
| `peso_gallery_career.jpg` | https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?fit=crop&w=1000&h=700&q=78&fm=jpg |
| `peso_job_default.jpg` | https://images.unsplash.com/photo-1497366216548-37526070297c?fit=crop&w=1000&h=700&q=80&fm=jpg |
| `peso_job_technology.jpg` | https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?fit=crop&w=1000&h=700&q=80&fm=jpg |

The files are illustrative stock photography, not evidence that a named employer or
PESO program is participating. Actual employer-supplied job image URLs continue to
be shown when valid; bundled images are local fallbacks only.

## Official employer logo assets (added 2026-10-23)

These are downloaded, locally bundled marks from the employers' own websites, not AI-generated or third-party approximations:

| Local file | Official source | Verification |
|---|---|---|
| `lib/assets/peso_employer_jcrcc.png` | https://jcrcc.com.ph/sites/default/files/logo-footer.png | HTTP 200, PNG 105x105, 5,803 bytes; official JCRCC website footer logo mark |
| `lib/assets/peso_employer_jcrcc_banner.png` | https://jcrcc.com.ph/sites/default/files/jcrcc_website_company_name_banner_0.png | HTTP 200, PNG 422x90, 12,006 bytes; official JCRCC company-name wordmark retained as a reference asset |
| `lib/assets/peso_employer_puregold.png` | https://puregold.com.ph/images/headers/pg_logo.png | HTTP 200, PNG 336x60, 8,001 bytes; official Puregold Price Club Inc. website wordmark |

`lib/peso_ui/Reusable_Designs/peso_employer_branding.dart` maps recognized saved company names to these local assets when rendering job cards. A stored `logoUrl` always takes precedence; an unknown employer receives only the neutral business icon. This is presentation-only and does not write employer metadata to the live job database. On the 2026-10-23 public read-only API check, JCRCC had 15 active role cards with no `logoUrl`; the active public search returned no Puregold roles, so its fallback will appear only if a saved active Puregold record is published later.
