# RAHOSETU Foundation v1

A lightweight public-site foundation for RAHOSETU.

## Current status
- Responsive green-and-white homepage starter.
- No public admin dashboard or customer login.
- Search form currently routes to `search.html`; the search page and Supabase integration are not implemented yet.
- Database migration is a foundation, not a production-ready deployment.

## Stack
- HTML, CSS, Vanilla JavaScript
- Supabase PostgreSQL + Auth + Storage (next integration stage)
- Vercel hosting

## Next steps
1. Create a Supabase project.
2. Review and run `supabase/migrations/001_initial_schema.sql` in the Supabase SQL Editor.
3. Bootstrap the first owner account securely; do not expose service-role/secret keys in browser code.
4. Build public listing pages and forms.
5. Build the separate private Android admin app.

## Important
Never publish secrets, service-role keys, passwords, customer phone numbers, or private enquiry data in this repository.
