# UniFlow Hostel — development foundation

The original prototype code (`app.js`, `style.css`) has been retained and can be opened with `prototype.html`. The database-connected application lives in `src/` and starts only when Supabase is configured. This is an unfinished production foundation, not a deployed or security-audited service.

## Run it

1. Create a Supabase project, then run every SQL file in `supabase/migrations/` in filename order in its SQL editor (or use `supabase db push`). Later migrations fix and restrict the initial schema; do not omit them.
2. In Supabase Auth, enable Email/password, set your site URL, and add `http://localhost:5173/reset-password` and `http://localhost:5173/student/overview` to the allowed redirect URLs. Add the corresponding HTTPS URLs for your deployed domain.
3. Copy `.env.example` to `.env` and enter `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`. These are public client values, not service-role secrets.
4. Install and run: `npm install`, then `npm run dev`.
5. Sign up the first user, then promote it using the commented SQL at the bottom of the initial migration. An admin can invite staff from the Staff screen once the invitation function is configured.
6. Deploy `supabase functions deploy uniflow-ai` and `supabase functions deploy invite-staff`. Set `OPENAI_API_KEY` and `STAFF_INVITE_REDIRECT_URL` as Supabase Function Secrets. The redirect must be an allowed Auth redirect ending in `/reset-password`, such as `http://localhost:5173/reset-password` during development. Never put secrets in `VITE_` variables. Add verified, published knowledge articles before asking about official hostel information.

## Hosting and installation

Build with `npm run build` after setting the two `VITE_` variables in your hosting provider, then deploy `dist/` on an HTTPS domain. The app uses routes such as `/student/complaints` and `/admin/overview`; the host must serve `index.html` for application routes. Configuration is included for Vercel and Netlify. Set the deployed site's URL and allowed Auth redirects in Supabase before inviting users. The PWA can be installed on supported browsers over HTTPS or localhost. Its offline screen contains no user data; hostel operations require a connection.

## Security model

RLS limits students to their own complaints, feedback, notifications, and conversations; staff sees only assigned tickets; admins can manage all records. The client uses the public anon key only. The AI runs as a Supabase Edge Function and retrieves only verified, published knowledge articles.

## Remaining deployment configuration

Credentials cannot be created safely without access to your Supabase and OpenAI accounts. The SQL, live authentication, realtime updates, and AI endpoint have not been tested against a real project here. Test the full workflow and access boundaries with separate test accounts before entering real personal data.

Complaint image upload, staff invitations and workload management, complaint timelines, analytics, contacts, and PDF attachments are implemented but need live testing. An administrator must manually enter reviewed text for attached PDFs; automatic PDF text extraction and OCR are not implemented. AI searches verified article text with PostgreSQL full-text search, not vector retrieval; its database-backed request limit also needs live verification. Important notices published immediately generate notifications; scheduled notices need a worker to notify at publication time. These require further implementation and security review before real-world use.
