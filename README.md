<div align="center" markdown="1">

<img src=".github/edu-logo.svg" alt="Madrasati Logo" width="80">

<h1>Madrasati · مدرستي</h1>

**Empowering Schools with Smarter Management — منصة إدارة المدرسة الذكية**

![GitHub release (latest by date)](https://img.shields.io/github/v/release/frappe/education)

</div>

<div align="center">
	<img width="1552" alt="Screenshot 2025-01-01 6 24 15 PM" src="https://github.com/user-attachments/assets/46af048c-749f-41f7-8d10-47e4fa643592" width="100%" />

</div>
<br />
<div align="center">
	<a href="https://frappe.io/education">Website</a>
	-
	<a href="https://docs.frappe.io/education">Documentation</a>
</div>

## About Madrasati

**Madrasati (مدرستي)** is an open-source, user-friendly Education Management
System designed to streamline the administrative and academic processes of
educational institutions. It is a powerful module based on the Frappe framework
and ERPNext — a hardened fork of *Frappe Education* with a new identity and a
much richer school-operations feature set.

### Key Features

- **Student & Teacher Management** — Manage student and teacher profiles,
  attendance.
- **Admission Management** — Streamline the admission process for new students.
- **Fee Management** — Organize and manage the fee structure and schedule
  payments.
- **Course Scheduling & Exam Planning** — Efficiently schedule courses and
  manage course calendars.
- **Student Portal** — Students can visit the portal to check their timetable,
  attendance, pay fees online, and see current and previous grades.

### New in Madrasati 🆕

- **📖 Library Management** — Books catalogue with live copy tracking,
  issue/return transactions, automatic due dates and late fines, an
  *Library Overdue Report*, plus a *My Library* page in the student portal.
- **🚌 School Transport** — Vehicles, routes with ordered stops and pickup
  times, per-student assignments with monthly fees (one active assignment per
  student is enforced).
- **🏠 Hostel / Dormitories** — Rooms with capacity & occupancy tracking and
  student allocations (full/available status maintained automatically).
- **⚖️ Discipline & Conduct** — Incident records with severity, actions
  (warning → suspension), parent notification flags, follow-ups and a
  *Disciplinary Action Report*.
- **📣 Notice Board** — Publish dated notices by audience (students, parents,
  teachers) with priorities; visible in the student portal under *Notices*.
- **🎓 Certificates & Documents** — Issue numbered certificates (transfer,
  character, enrollment, transcript, fee clearance) with full register.
- **🗓️ Timetable Entries** — Day-wise period scheduling with automatic
  clash detection for rooms and instructors.
- **📊 Madrasati Dashboard** — A dedicated desk page with live KPIs: fees
  collected vs outstanding, attendance today, library overdue, discipline
  cases, hostel occupancy, transport users, recent admissions and more.
- **⚙️ Education Settings** — New library controls: loan duration (days) and
  fine per day.

### Identity

This fork ships under the name **Madrasati (مدرستي)** with a new logo, while
staying 100% compatible with the Frappe Education app (`education`) and
crediting the original work below.

<details open>
<summary >View Screenshots</summary>
<h3></h3>
<div align="center">
	<sub>
		Student Management
	</sub>
</div>

<img width="1300" alt="Screenshot 2025-01-01 6 09 34 PM" src="https://github.com/user-attachments/assets/78263a31-eb9f-45f0-a7a4-486f75c2b774" />

<div align="center">
	<sub>
		Organize and manage the fee structure and schedule payments.
	</sub>
</div>

<img width="1300" alt="Screenshot 2025-01-01 6 12 40 PM" src="https://github.com/user-attachments/assets/7dcf7e7b-a003-4520-a41e-84ca553e7f0d" />

<div align="center">
	<sub>
		Efficiently schedule courses and manage course calendars. 🗓️
	</sub>
</div>

<img width="1300" alt="Screenshot 2025-01-01 6 19 49 PM" src="https://github.com/user-attachments/assets/19106f12-c278-48f9-8be3-47db5ce3a5f3" />

<div align="center">
	<sub>
		Student Portal - Fee Payment Records
	</sub>
</div>

<img width="1300" alt="Screenshot 2025-01-01 6 16 27 PM" src="https://github.com/user-attachments/assets/0640c623-bc81-4308-a15d-53a5977d5011" />

</details>
<br>

### Under the Hood

- [**Frappe Framework**](https://github.com/frappe/frappe): A full-stack web
  application framework written in Python and Javascript.
- [**ERPNext**](https://github.com/frappe/erpnext) - An open-source, modern ERP
  system that includes modules for accounting, inventory, manufacturing, and
  more.
- [**Frappe UI**](https://github.com/frappe/frappe-ui): A Vue-based UI library,
  to provide a modern user interface.

## Run locally with the portable MySQL database 🗄️

Everything runs **on your machine** with a **portable MySQL server that lives
inside this repository** (`local-db/`) — copy the folder and your data travels
with it. The helper scripts fetch every dependency from GitHub / PyPI / npm, so
they also work behind restrictive networks.

```bash
# 1) One-shot toolchain: Node 24, Python 3.14, Redis, MySQL 5.7 binaries,
#    pkg-config, frappe-bench + frappe/erpnext/payments apps
bash scripts/local/install-core.sh

# 2) Start the portable database (creates local-db/data on first run,
#    root password "root", listens on 127.0.0.1:3306)
bash scripts/local/start-db.sh          # keep it running (or run in background)

# 3) Create the site (named after your preview host + localhost aliases),
#    install payments + erpnext + education and build all assets
bash scripts/local/setup-site.sh

# 4) Start the app on http://localhost:8000
bash scripts/local/start-bench.sh
```

Notes:

- Redis must be running on `127.0.0.1:6379` (any `redis-server` works).
- Login: `Administrator` / `admin`.
- Student portal: `/student-portal` · Madrasati dashboard: `/app/school_dashboard`.
- Data files are ignored by git (`local-db/data/`) — commit only scripts.

## Production Setup

### Managed Hosting

You can try [Frappe Cloud](https://frappecloud.com), a simple, user-friendly and
sophisticated [open-source](https://github.com/frappe/press) platform to host
Frappe applications with peace of mind.

It takes care of installation, setup, upgrades, monitoring, maintenance and
support of your Frappe deployments. It is a fully featured developer platform
with an ability to manage and control multiple Frappe deployments.

<div>
	<a href="https://frappecloud.com/education/signup" target="_blank">
		<picture>
			<source media="(prefers-color-scheme: dark)" srcset="https://frappe.io/files/try-on-fc-white.png">
			<img src="https://frappe.io/files/try-on-fc-black.png" alt="Try on Frappe Cloud" height="28" />
		</picture>
	</a>
</div>

## Development Setup

### Local

1. Install bench and setup a `frappe-bench` directory by following the
   [Installation Steps](https://frappeframework.com/docs/user/en/installation)
1. Install ERPNext by running `bench get-app erpnext`
1. Once ERPNext is installed, install the Education App by using
   `bench get-app education`
1. In a separate terminal window, create a new site by running
   `bench new-site education.test`
1. Map your site to localhost with the command
   `bench --site education.test add-to-hosts`
1. After that, you can install the Education app on the required site by running
   ```jsx
   $ bench --site sitename install-app education
   ```
1. Now open the URL `http://education.test:8000/education` in your browser, you
   should see the app running
1. To access student portal, open the URL
   `http://education.test:8000/student-portal` in your browser, you should see
   the student portal running.

### Portable scripts (this repo)

See **Run locally** above — `scripts/local/*.sh` handles toolchain, database,
site and assets for restricted environments.

### Docker

You need Docker, docker-compose and git setup on your machine. Refer
[Docker documentation](https://docs.docker.com/). After that, follow below
steps:

**Step 1**: Setup folder and download the required files

    mkdir frappe-education
    cd frappe-education

    # Download the docker-compose file
    wget -O docker-compose.yml https://raw.githubusercontent.com/frappe/education/develop/docker/docker-compose.yml

    # Download the setup script
    wget -O init.sh https://raw.githubusercontent.com/frappe/education/develop/docker/init.sh

**Step 2**: Run the container and daemonize it

    docker compose up -d

**Step 3**: The site
[http://education.localhost:8000/](http://education.localhost:8000) should now
be available. The default credentials are:

- Username: Administrator
- Password: admin

## Compatibility matrix

| Education Branch | Compatible Frappe Framework Version |
| ---------------- | ----------------------------------- |
| version-15.1     | version-15                          |
| version-15.2     | version-15                          |
| version-16       | version-16                          |
| develop          | develop branch                      |

## Learn and connect

- [Telegram Public Group](https://t.me/frappe_education)
- [Discuss Forum](https://discuss.frappe.io/c/erpnext/schools-college-education/40)
- [Documentation](https://docs.frappe.io/education) |

## Credits

Originally built by
[Frappe Technologies](https://github.com/frappe/education) as
**Frappe Education** (GNU GPL v3). Madrasati keeps the same license, code base
and community links, with an updated identity and extended school-management
features.
