"""
Regenerate the TABLES list in scripts/migrate-supabase.mjs from the migrations.

    python scripts/build-migrate-list.py

The list was written by hand once. It missed twenty one tables that exist in the
schema and named two that do not, which on a migration whose whole promise is
losing nothing means quietly leaving data behind. Nobody notices until somebody
looks for a gift they were sent.

Order is a topological sort over the REFERENCES in every CREATE TABLE, so a
table is always copied after whatever it points at. Inserting a message before
its conversation exists fails on the foreign key; inserting anything before
users exists fails on nearly all of them.
"""
import pathlib
import re

MIGRATIONS = pathlib.Path("supabase/migrations")
SCRIPT = pathlib.Path("scripts/migrate-supabase.mjs")


def tables_with_dependencies():
    schema = "\n".join(
        sorted(p.read_text(encoding="utf-8", errors="replace") for p in MIGRATIONS.glob("*.sql"))
    )
    blocks = re.findall(
        r"CREATE TABLE (?:IF NOT EXISTS )?public\.([a-z_]+)\s*\((.*?)\n\);", schema, re.S
    )

    order, deps = [], {}
    for name, body in blocks:
        if name not in deps:
            order.append(name)
            deps[name] = set()
        for ref in re.findall(r"references\s+public\.([a-z_]+)", body, re.I):
            # A self reference is fine and must not become a cycle.
            if ref != name:
                deps[name].add(ref)
    return order, deps


def sorted_tables():
    order, deps = tables_with_dependencies()
    done, result = set(), []

    def visit(table, stack=()):
        # `stack` breaks cycles. Two tables referencing each other is legal in
        # Postgres when one side is nullable, and recursing forever is not a
        # useful response to it.
        if table in done or table in stack:
            return
        for dependency in sorted(deps.get(table, ())):
            if dependency in deps:
                visit(dependency, stack + (table,))
        done.add(table)
        result.append(table)

    for table in order:
        visit(table)
    return result


def main():
    tables = sorted_tables()
    body = "\n".join(f"    '{table}'," for table in tables)

    source = SCRIPT.read_text(encoding="utf-8")
    updated = re.sub(
        r"(const TABLES = \[\n).*?(\n\];)",
        lambda m: m.group(1) + body + m.group(2),
        source,
        flags=re.S,
    )
    SCRIPT.write_text(updated, encoding="utf-8")

    print(f"  {len(tables)} tables written to {SCRIPT}")
    print(f"  first: {', '.join(tables[:4])}")
    print(f"  last : {', '.join(tables[-4:])}")


if __name__ == "__main__":
    main()
