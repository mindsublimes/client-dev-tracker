# DevTracker

Internal agenda tracker built with Ruby 3.2 / Rails 7.1 / PostgreSQL. It provides a client-facing agenda with automatic ranking, professional UI, and internal chat/file sharing—all without Stimulus/Hotwire.

## Features

- **Authentication & Roles**: Devise + Pundit. New signups default to `viewer` (read-only). Admin/lead/analyst users have full management powers, developers see only agenda items assigned to them, and the new `client` role is limited to its own agenda + dashboard (with forms auto-filling client/requester fields). Only admins can delete.
- **Agenda Items**: Track sprint/correction/enhancement/training/support work with due date, priority, complexity, status, requester, cost, paid flag, notes, and custom rank score.
- **Automatic Ranking**: `AgendaItems::Ranker` recalculates score based on priority, due date proximity, complexity, status, and recent activity.
- **Dashboard**: Summary cards, priority queue, overdue/upcoming lists, and client health snapshots.
- **Agenda Index**: Auto-submitting filters (client, status, work type, keyword) plus ranked table.
- **Agenda Show Page**: Delivery details, rank breakdown, and a timeline-style conversation thread with Active Storage file uploads.
- **Client Management**: CRUD for clients with priority/status/timezone, plus per-client agenda lists.
- **Chat & Files**: Agenda messages include kind (update/note/blocker/decision) and support multi-file uploads.
- **Styling**: Bootstrap 5 with custom SCSS; responsive layout; polished auth pages.

## Getting Started

1. **Install dependencies**
   - ImageMagick CLI utilities (needed for Active Storage thumbnails).
     - macOS: `brew install imagemagick`
     - Debian/Ubuntu: `sudo apt-get install imagemagick`
   ```sh
   bundle install
   npm install
   ```
2. **Environment setup**
   - Ensure Postgres is running.
   - Copy `.env.example` if you manage secrets (optional).
3. **Database**
   ```sh
   bin/rails db:prepare
   bin/rails db:seed
   ```
4. **Run app**
   ```sh
   bin/dev
   ```
   This launches Rails + CSS watcher (foreman).

## Default Accounts

Seed data creates:

| Role   | Email               | Password      |
|--------|---------------------|---------------|
| Admin  | admin@example.com   | Password123!  |
| Lead   | pm@example.com      | Password123!  |
| Dev    | dev@example.com     | Password123!  |

You can create viewer accounts via sign-up (no elevated rights until promoted).

## Tech Stack
- Ruby 3.2.0
- Rails 7.1.x (classic asset pipeline + importmap)
- PostgreSQL
- Bootstrap 5 / SCSS via cssbundling-rails
- Active Storage (local disk)
- Devise, Pundit, ImageProcessing

## Project Structure Highlights

- `app/models/agenda_item.rb` – Agenda logic + helpers
- `app/services/agenda_items/ranker.rb` – Rank calculation
- `app/controllers/dashboards_controller.rb` – Metrics view
- `app/views/agenda_items/` – Index/show forms & chat UI
- `app/policies/` – Role-based authorization
- `db/seeds.rb` – Sample clients, agenda items, users

## Notes
- No Stimulus/Hotwire/Tailwind/React per client request.
- Filters use plain JS for auto-submit (see `app/javascript/application.js`).
- File uploads go to `storage/`; configure Active Storage for production (S3, etc.).

## Next Steps
- Integrate into main application or refine role permissions.
- Wire notifications, reports, or API endpoints if required.

Feel free to fork/extend as needed.
