-- Delete the duplicate standing reminders already sitting in members' inboxes.
--
-- "Complete your profile", "Manual verification is available" and "Unlock
-- premium GS features" are conditions, not events: they stay true until the
-- member does something about them. The server posted a fresh copy of each
-- every 24 hours for as long as the condition held, so an unverified free
-- account collected three new inbox messages a day, identical to yesterday's.
--
-- That is how an inbox reaches 58 items showing the same two notices over and
-- over, and it buries the messages that are genuinely events — a real message,
-- a match, an admin reply — under nags nobody asked to see again.
--
-- The code no longer does this: notifyOnceDaily now refuses while an unread
-- copy exists and waits a week after one is read. This clears what was already
-- delivered, which would otherwise stay in those inboxes forever.
--
-- Only the three reminder types are touched. Likes, matches, messages and admin
-- replies are events, and two of them are two things.

begin;

with ranked as (
    select
        id,
        row_number() over (
            partition by user_id, type
            -- Keep the newest, and prefer an unread one: a member who has not
            -- seen the reminder should still find it there afterwards.
            order by read asc, created_at desc
        ) as position
    from public.user_notifications
    where type in ('profile', 'verification', 'package')
)
delete from public.user_notifications
where id in (select id from ranked where position > 1);

commit;

-- How many remain per member, which should now be at most one of each:
--
--   select user_id, type, count(*)
--   from public.user_notifications
--   where type in ('profile', 'verification', 'package')
--   group by user_id, type
--   having count(*) > 1;
--
-- Any rows returned there mean the code path that writes them has regressed.
