# 🏫 សាលាបឋមសិក្សា — School Management System
### Project Description · Current State · Next Plan

---

## 👨‍💻 About the Project

This is a **free, open-source school management system** built specifically for **Cambodian government primary schools**. Designed with a deep understanding of the Cambodian education system — from the Mon–Sat school week, to Khmer holidays, to the semester scoring logic used in classrooms every day.

Built by a solo Cambodian developer from Battambang, this system was created out of a genuine desire to help rural government schools that have little to no budget for digital tools. The entire system is built in **Khmer language first**, making it accessible to every teacher and parent regardless of their English proficiency.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Vue 3 + Vite + Tailwind CSS |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| Hosting | Vercel (Frontend) + Supabase (Backend) |
| Language | Khmer (ភាសាខ្មែរ) |
| Font | Hanuman (Khmer) + Inter (Latin) |

---

## ✅ Current State — Version 1 (MVP)

The system is **fully built, deployed, and currently being tested** by a real team at a government primary school in **Battambang province, Cambodia**.

### 👥 Role System
| Role | Access |
|---|---|
| 👨‍💼 Admin / Director | Full system access — all schools data, budget, reports |
| 👩‍🏫 Teacher | Their class only — students, attendance, scores, health |
| 📚 Librarian | Books and borrows management |
| 👨‍👩‍👧 Parent | Read-only via name + DOB search — no login required |

### 🗄️ Database (Schema v6)
- **20+ tables** with comprehensive Row Level Security (RLS)
- Every staff member has a teacher profile (Cambodian school design)
- Per-class subject assignment (Grade 1-3 vs Grade 4-6 subjects)
- Singleton `school_settings` table for configurable late thresholds

### 🏫 Admin Features
- **Two-layer flow** — Academic year selector (standalone) → Full dashboard
- **Settings page** — School info, Academic years, Subjects, Holidays, Attendance config grouped in one tabbed page
- Student & teacher management (full CRUD)
- Class management with subject assignment per class
- Budget tracking (income/expense)
- Inventory management
- Library overview
- User management (create/deactivate/reset password via Supabase Edge Functions)

### 👩‍🏫 Teacher Features
- **Self check-in** — one click per day, auto-calculates present/late based on configurable thresholds (morning 07:15 / evening 13:15)
- **Bulk attendance marking** — mark all present, change exceptions only
- **Monthly calendar view** — color-coded (🟢 present 🔴 absent 🟡 late 🔵 permission ⬜ Sunday/holiday)
- **Printable attendance grid** — all students × all days in a month
- **Score entry** — dynamic subject columns per class, auto average, auto rank
- Monthly scores + Semester scores with full calculation logic
- PDF export for scores and attendance
- Student health, growth, vaccinations, sick days management

### 📊 Score System
```
Monthly:
  subject1 + subject2 + ... → monthly_average → rank (within class)

Semester:
  Semester exam subjects → semester_exam_average
  (Month1_avg + Month2_avg + Month3_avg) / 3 → monthly_average
  (monthly_average + semester_exam_average) / 2 → semester_average → rank
```

### 👨‍👩‍👧 Parent Portal
- No login required
- Search by student full name + date of birth
- View: attendance calendar, scores, health, growth, vaccinations, sick days
- Mobile-first design (parents in countryside use phones)

### 🔒 Security
- Full RLS policies — every role scoped to their data only
- Teacher check-in enforced at DB level (once per day, unique constraint)
- User deactivation blocks login immediately (`banned_until`)
- Parent access is anonymous read-only, filtered by app

---

## 🎯 Next Plan

### Phase 1 — Stabilize (Now)
- [ ] Complete team testing at Battambang school
- [ ] Fix bugs reported by real users
- [ ] Train teachers and admin to use the system
- [ ] Collect feedback and usage data
- [ ] Monitor performance via Supabase dashboard

### Phase 2 — Multi-tenant Architecture (schema_v7)
The biggest next step — transforming from a **single school system** into a **multi-school platform** where each school manages their own data independently on the same infrastructure.

```
Current:    1 school → 1 Supabase → 1 Vercel deployment
Next:       N schools → 1 Supabase → 1 Vercel deployment
                        filtered by school_id
```

**Changes needed:**
- Add `schools` table
- Add `school_id` to every major table
- Update RLS to scope by `school_id`
- Add database indexes for performance
- School selector on login page
- New school onboarding flow

**Why this matters:**
- Add a new school in minutes (no manual .env changes)
- Same $25/month Supabase cost for multiple schools
- Scale from 1 school → 10 → 100 without infrastructure changes

### Phase 3 — District Rollout (កម្រង)
In Cambodia, schools are grouped into clusters (**កម្រង**) of 3-4 schools per district. The goal is to onboard entire clusters at once — one district at a time, starting from Battambang.

```
Battambang District
  └── កម្រង 1
        ├── School A ✅
        ├── School B
        ├── School C
        └── School D
```

### Phase 4 — Performance & Indexing
As more schools join, database performance becomes critical.

```sql
-- Key indexes planned:
create index on students(school_id);
create index on students(school_id, class_id);
create index on attendances(student_id, date);
create index on scores(student_id, subject_id);
create index on teacher_attendances(teacher_id, date);
create index on students(school_id, full_name, dob); -- parent search
```

Supabase's built-in Query Performance and Index Advisor tools will guide optimization as data grows.

### Phase 5 — National Scale 🇰🇭
Cambodia has approximately **7,000 government primary schools**. The long-term vision is to provide every one of them with a free, professional, Khmer-first management system.

```
Target impact:
  1%  adoption → 70 schools  → ~21,000 students
  10% adoption → 700 schools → ~210,000 students
```

**Potential partnerships:**
- 🏛️ Ministry of Education, Youth and Sport (MoEYS)
- 🌐 UNICEF Cambodia — education technology
- 🌐 World Bank — Cambodia education digitalization
- 🌐 Room to Read, Aide et Action — rural education NGOs

---

## 💰 Cost Structure

| Item | Cost |
|---|---|
| Vercel (Frontend hosting) | FREE |
| Supabase Pro (Backend + DB + Storage) | $25/month |
| Custom domain (optional) | ~$15/year |
| **Total** | **~$25/month** |

This covers multiple schools on the same infrastructure — making it one of the most cost-effective school management solutions available for Cambodian government schools.

---

## 💡 Why This Matters

Most school management systems available in Cambodia are:
- ❌ Expensive ($200-500/month)
- ❌ Not in Khmer
- ❌ Built for foreign school systems
- ❌ Too complex for rural teachers
- ❌ Require expensive training

This system is:
- ✅ Free for government schools
- ✅ Full Khmer language
- ✅ Built for Cambodia's exact education structure
- ✅ Simple enough for rural teachers
- ✅ Mobile-friendly for parents
- ✅ Already tested in a real school

---

## 👨‍💻 Developer

Built with ❤️ by **Tra** — a young Cambodian developer from Battambang, building technology for his own community and country. 🇰🇭

---

*"One school at a time. One district at a time. One country at a time."* 🚀
