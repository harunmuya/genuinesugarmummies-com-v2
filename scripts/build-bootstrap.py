"""
Concatenate every migration into one file that stands the app up on a fresh
Supabase project.

Filename order is the order they were written and the order they must run, so
this is a straight concatenation rather than anything clever. Regenerate after
adding a migration:

    python scripts/build-bootstrap.py

The output is schema only. It creates no members, no messages and no packages
beyond the seeded tiers, which is the whole difficulty of moving projects: see
docs/migrating-supabase.md.
"""
import pathlib
import re

HEADER = """-- Everything needed to stand this app up on a fresh Supabase project.
--
-- Every migration in supabase/migrations, concatenated in filename order, which
-- is the order they were written and the order they must be applied. Paste the
-- schema is intended for a fresh project. Do not run it against a populated
-- project.
--
-- Synthetic seed member profiles are intentionally omitted. Package-tier and
-- application-default rows remain; gift catalog rows come from the verified
-- source export so their original IDs are preserved without duplicate seeds.
--
-- This creates no member accounts, messages, matches, or other member records.
-- Read docs/migrating-supabase.md before using it; schema without a verified
-- data export is not a complete migration.
--
-- Regenerate with: python scripts/build-bootstrap.py
"""


def main():
    migrations = sorted(pathlib.Path("supabase/migrations").glob("*.sql"))
    if not migrations:
        raise SystemExit("no migrations found; run this from the project root")

    out = pathlib.Path("supabase/bootstrap/schema.sql")
    out.parent.mkdir(parents=True, exist_ok=True)

    parts = [HEADER]
    for path in migrations:
        sql = path.read_text(encoding="utf-8").strip()
        if path.name == "20260625_020_seed_members_profiles.sql":
            marker = "INSERT INTO public.users ("
            if marker not in sql:
                raise SystemExit(f"expected synthetic profile seed block in {path}")
            sql = sql.split(marker, 1)[0].rstrip()
            sql += "\n\n-- Synthetic seed member inserts intentionally omitted from bootstrap."

        sql, _ = re.subn(
            r"(?is)\bINSERT\s+INTO\s+public\.gift_catalog\b.*?;",
            "-- Gift catalog seed rows are restored from the verified source export.",
            sql,
        )

        parts.append("\n\n-- " + "=" * 70)
        parts.append(f"-- {path.name}")
        parts.append("-- " + "=" * 70 + "\n")
        parts.append(sql)

    out.write_text("\n".join(parts) + "\n", encoding="utf-8")
    print(f"  wrote {out} ({len(migrations)} migrations, {out.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
