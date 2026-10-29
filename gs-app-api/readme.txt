# GS App API — WordPress Plugin

REST API plugin for the **GenuineSugarMummies.com** Next.js mobile app.

## Installation
1. **Zip this folder** — right-click `gs-app-api` → Send to → Compressed (zipped) folder
2. In WordPress Admin, go to **Plugins → Add New → Upload Plugin**
3. Upload `gs-app-api.zip` and click **Activate**

## Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/wp-json/gs-app/v1/profiles` | Paginated profiles from the `sugarmummies` and `sugar-daddies` categories |
| GET | `/wp-json/gs-app/v1/profiles/{id}` | Single eligible profile with full content; other posts return 404 |
| GET | `/wp-json/gs-app/v1/comments/{post_id}` | Comments with author avatars |
| POST | `/wp-json/gs-app/v1/comment` | Submit comment (held for moderation) |
| POST | `/wp-json/gs-app/v1/subscribe` | Email subscription |

## Admin Features
- View all app subscribers at **Tools → GS App Subscribers**
- All app comments are held for moderation automatically

## Version
2.1.0 — Listing-category-only profile feed, lighter list responses, and single-profile eligibility checks.
