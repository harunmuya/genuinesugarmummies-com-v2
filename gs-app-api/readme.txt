# GS App API — WordPress Plugin

REST API plugin for the **GenuineSugarMummies.com** Next.js mobile app.

## Installation
1. **Zip this folder** — right-click `gs-app-api` → Send to → Compressed (zipped) folder
2. In WordPress Admin, go to **Plugins → Add New → Upload Plugin**
3. Upload `gs-app-api.zip` and click **Activate**

## Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/wp-json/gs-app/v1/profiles` | Paginated profile list with images |
| GET | `/wp-json/gs-app/v1/profiles/{id}` | Single profile with full content |
| GET | `/wp-json/gs-app/v1/comments/{post_id}` | Comments with author avatars |
| POST | `/wp-json/gs-app/v1/comment` | Submit comment (held for moderation) |
| POST | `/wp-json/gs-app/v1/subscribe` | Email subscription |

## Admin Features
- View all app subscribers at **Tools → GS App Subscribers**
- All app comments are held for moderation automatically

## Version
2.0.0 — Full profiles, comments with avatars, image fallbacks, and email subscriptions.
