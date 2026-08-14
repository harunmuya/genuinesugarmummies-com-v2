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

HEADER = """-- Everything needed to stand this app up on a fresh Supabase project.
--
-- Every migration in supabase/migrations, concatenated in filename order, which
-- is the order they were written and the order they must be applied. Paste the
-- whole file into the SQL Editor of the new project and run it once.
--
-- The migrations use IF NOT EXISTS and DROP POLICY IF EXISTS throughout, so
-- running this against a project that already has some of it is safe.
--
-- This is schema only. It creates no members, no messages and no packages
-- beyond the seeded package tiers. Read docs/migrating-supabase.md first: on a
-- restricted project the data cannot be exported, and standing this up without
-- it means every member loses their account.
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
        parts.append("\n\n-- " + "=" * 70)
        parts.append(f"-- {path.name}")
        parts.append("-- " + "=" * 70 + "\n")
        parts.append(path.read_text(encoding="utf-8").strip())

    out.write_text("\n".join(parts) + "\n", encoding="utf-8")
    print(f"  wrote {out} ({len(migrations)} migrations, {out.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
