# Package Entitlements

The code currently defines default package behavior in `src/lib/packageAccess.js`.

## Free

1. 5 messages per day.
2. 5 likes per day.
3. 10 swipes per day.
4. 10 profile views per day.
5. No calls, live, voice notes, image messages, gifts, phone reveal, nearby, or viewer lists.

## Basic

1. 30 messages per day.
2. 10 gifts per day.
3. 10 likes per day.
4. 5 super likes per day.
5. 30 swipes and 30 profile views per day.
6. Image messages enabled.
7. Gifts enabled up to tier 1.

## Silver

1. Unlimited messages.
2. 50 gifts per day.
3. 50 likes per day.
4. 100 super likes per day.
5. Unlimited swipes and profile views.
6. Phone reveal enabled.
7. Voice and video calls enabled.
8. Voice notes, image messages, live, gifts, nearby, who liked me, and who viewed me enabled.
9. Priority visibility enabled.

## Gold

1. Unlimited messages, gifts, likes, super likes, swipes, and profile views.
2. Phone reveal enabled.
3. Voice and video calls enabled.
4. Voice notes, image messages, live, gifts, nearby, who liked me, and who viewed me enabled.
5. International access enabled.
6. Highest priority visibility.

## Enforcement Audit Needed

Every endpoint below should be checked for the same package source of truth:

1. `src/app/api/chat/route.js`
2. `src/app/api/calls/route.js`
3. `src/app/api/live/route.js`
4. `src/app/api/wallet/route.js`
5. `src/app/api/members/route.js`
6. `src/app/api/activity/route.js`
7. `src/app/api/location/route.js`
8. `src/app/api/profiles/follows/route.js`

