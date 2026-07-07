<script setup>
import { ref, computed, onMounted } from "vue";
import * as XLSX from "xlsx";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/auth";
import { useAcademicYearStore } from "@/stores/academicYear";
import { formatDate, toInputDate } from "@/utils/formatDate";
import { useRouter } from "vue-router";
import {
  CheckIcon,
  XCircleIcon,
  AcademicCapIcon,
  TrashIcon,
} from "@heroicons/vue/24/outline";
import { useToast } from "@/composables/useToast";
import { isFemale } from "@/utils/gender";

const router = useRouter();
const auth = useAuthStore();
const yearStore = useAcademicYearStore();
const { showToast } = useToast();
const students = ref([]);
const classes = ref([]);
const loading = ref(true);
const saving = ref(false);
const search = ref("");
const filterClass = ref("");
const showModal = ref(false);
const isEdit = ref(false);
const deleteTarget = ref(null);

const selectedStudents = ref([]);
const bulkClassId = ref("");
const savingBulk = ref(false);
const showBulkDeleteModal = ref(false);
const deletingBulk = ref(false);
const refactoring = ref(false);
const refactorProgress = ref({ current: 0, total: 0 });

const isPartiallySelected = computed(() => {
  if (selectedStudents.value.length === 0) return false;
  return selectedStudents.value.length < filtered.value.length && !isAllSelected.value;
});

const isAllSelected = computed(() => {
  if (filtered.value.length === 0) return false;
  return filtered.value.every((s) => selectedStudents.value.includes(s.id));
});

function toggleSelectAll(e) {
  if (e.target.checked) {
    selectedStudents.value = filtered.value.map((s) => s.id);
  } else {
    selectedStudents.value = [];
  }
}

function confirmBulkDelete() {
  showBulkDeleteModal.value = true;
}

async function doBulkDelete() {
  if (selectedStudents.value.length === 0) return;
  deletingBulk.value = true;
  const { error } = await supabase
    .from("students")
    .delete()
    .in("id", selectedStudents.value);
  deletingBulk.value = false;
  showBulkDeleteModal.value = false;
  if (error) {
    showToast(error.message, "error");
    return;
  }
  showToast(`បានលុបសិស្សចំនួន ${selectedStudents.value.length} នាក់!`, "success");
  selectedStudents.value = [];
  loadStudents();
}

async function applyBulkClass() {
  if (selectedStudents.value.length === 0 || !bulkClassId.value) return;
  savingBulk.value = true;
  
  const targetClassId = bulkClassId.value === "none" ? null : bulkClassId.value;
  
  const { error } = await supabase
    .from("students")
    .update({ class_id: targetClassId })
    .in("id", selectedStudents.value);
    
  savingBulk.value = false;
  if (error) {
    showToast(error.message, "error");
    return;
  }
  
  showToast(`បានផ្លាស់ប្តូរថ្នាក់សិស្សចំនួន ${selectedStudents.value.length} នាក់!`, "success");
  selectedStudents.value = [];
  bulkClassId.value = "";
  loadStudents();
}

// ── Import state ──────────────────────────────────────────────────────────────
const showImportModal = ref(false);
const importClass = ref("");
const importRows = ref([]);
const importing = ref(false);
const isDragging = ref(false);
const fileInputRef = ref(null);
const detectedClassName = ref(""); // class name read from the Excel header rows
const creatingClass = ref(false);

const validRows = computed(() => importRows.value.filter((r) => r.valid));
const skippedRows = computed(() => importRows.value.filter((r) => !r.valid));
// ─────────────────────────────────────────────────────────────────────────────

const emptyForm = () => ({
  id: null,
  real_id: "",
  full_name: "",
  gender: "",
  dob: "",
  address: "",
  phone_number: "",
  father_name: "",
  father_job: "",
  mother_name: "",
  mother_job: "",
  class_id: "",
  academic_year_id: yearStore.selectedYearId,
  is_scholarship: false,
  is_disability: false,
});
const form = ref(emptyForm());

const filtered = computed(() => {
  let list = students.value;
  if (filterClass.value)
    list = list.filter((s) => s.class_id === filterClass.value);
  const q = search.value.toLowerCase();
  if (q)
    list = list.filter(
      (s) =>
        s.full_name.toLowerCase().includes(q) ||
        (s.real_id || "").toLowerCase().includes(q),
    );
  return list;
});

onMounted(async () => {
  await Promise.all([loadStudents(), loadClasses()]);
});

async function loadStudents() {
  loading.value = true;
  selectedStudents.value = []; // Reset bulk selection
  const { data } = await supabase
    .from("students")
    .select("*, classes(class_name)")
    .eq("academic_year_id", yearStore.selectedYearId)
    .order("full_name");
  students.value = data || [];
  loading.value = false;
}

async function loadClasses() {
  const { data } = await supabase
    .from("classes")
    .select("id, class_name")
    .eq("academic_year_id", yearStore.selectedYearId)
    .order("class_name");
  classes.value = data || [];
}

function openAdd() {
  isEdit.value = false;
  form.value = emptyForm();
  showModal.value = true;
}

function openEdit(s) {
  isEdit.value = true;
  form.value = { ...s, dob: toInputDate(s.dob) };
  showModal.value = true;
}

async function save() {
  if (!form.value.full_name.trim() || !form.value.dob) {
    showToast("សូមបំពេញឈ្មោះ និងថ្ងៃខែឆ្នាំកំណើត", "error");
    return;
  }
  saving.value = true;
  const { id, classes: _c, ...payload } = form.value;
  if (!payload.class_id) payload.class_id = null;
  const { error } = isEdit.value
    ? await supabase.from("students").update(payload).eq("id", id)
    : await supabase
        .from("students")
        .insert({ ...payload, school_id: auth.schoolId });
  saving.value = false;
  if (error) {
    showToast(error.message, "error");
    return;
  }
  showToast(
    isEdit.value ? "បានកែប្រែព័ត៌មានសិស្ស!" : "បានបន្ថែមសិស្សថ្មី!",
    "success",
  );
  showModal.value = false;
  loadStudents();
}

async function doDelete() {
  const { error } = await supabase
    .from("students")
    .delete()
    .eq("id", deleteTarget.value.id);
  deleteTarget.value = null;
  if (error) {
    showToast(error.message, "error");
    return;
  }
  showToast("បានលុបសិស្ស", "success");
  loadStudents();
}

async function refactorNames() {
  if (refactoring.value) return

  const targetIds = selectedStudents.value.length > 0
    ? selectedStudents.value
    : students.value.map(s => s.id)

  if (targetIds.length === 0) return
  if (!confirm(`ប្តូរឈ្មោះសិស្សចំនួន ${targetIds.length} នាក់ពី "នាមត្រកូល នាមខ្លួន" ទៅជា "នាមខ្លួន នាមត្រកូល"?`)) return

  refactoring.value = true
  refactorProgress.value = { current: 0, total: targetIds.length }
  let updated = 0

  for (const id of targetIds) {
    const s = students.value.find(st => st.id === id)
    if (s) {
      const parts = (s.full_name || '').trim().split(/\s+/)
      if (parts.length >= 2) {
        const swapped = [...parts.slice(1), parts[0]].join(' ')
        const { error } = await supabase.from('students').update({ full_name: swapped }).eq('id', s.id)
        if (!error) updated++
      }
    }
    refactorProgress.value.current++
  }

  refactoring.value = false
  showToast(`បានប្តូរឈ្មោះសិស្សចំនួន ${updated} នាក់!`, 'success')
  selectedStudents.value = []
  loadStudents()
}

function initials(name) {
  return (
    (name || "")
      .split(" ")
      .map((w) => w[0])
      .join("")
      .slice(0, 2)
      .toUpperCase() || "??"
  );
}

// ── Excel Import ──────────────────────────────────────────────────────────────

function openImportModal() {
  importRows.value = [];
  importClass.value = "";
  detectedClassName.value = "";
  isDragging.value = false;
  showImportModal.value = true;
}

function onFileDrop(e) {
  isDragging.value = false;
  const file = e.dataTransfer?.files?.[0];
  if (file) parseExcel(file);
}

function onFileChange(e) {
  const file = e.target.files?.[0];
  if (file) parseExcel(file);
  e.target.value = ""; // reset so re-uploading same file triggers change again
}

function resetImport() {
  importRows.value = [];
  detectedClassName.value = "";
  importClass.value = "";
}

/** Parse DD/MM/YYYY string → YYYY-MM-DD. Returns '' if unrecognised. */
function parseDob(raw) {
  const s = String(raw || "").trim();
  const m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (!m) return "";
  return `${m[3]}-${m[2].padStart(2, "0")}-${m[1].padStart(2, "0")}`;
}

function parseExcel(file) {
  const reader = new FileReader();
  reader.onload = (e) => {
    const workbook = XLSX.read(new Uint8Array(e.target.result), {
      type: "array",
    });
    const ws = workbook.Sheets[workbook.SheetNames[0]];

    // raw:false → SheetJS formats everything as strings (avoids serial-date numbers)
    const rows = XLSX.utils.sheet_to_json(ws, {
      header: 1,
      raw: false,
      defval: "",
    });

    // ── Detect class name from header rows ────────────────────────────────
    // Matches cells like "ថ្នាក់: 3-ខ" or "ថ្នាក់ : 3ខ"
    detectedClassName.value = "";
    outer: for (const row of rows) {
      for (const cell of row) {
        const s = String(cell || "").trim();
        const m = s.match(/ថ្នាក់\s*[:\s：]+\s*(.+)/);

        if (m) {
          const className = m[1].trim().replace("-", "");
          detectedClassName.value = "ថ្នាក់ទី " + className;
          break outer;
        }
      }
    }

    // Try to auto-match to an existing class (case-insensitive trim)
    if (detectedClassName.value) {
      const match = classes.value.find(
        (c) =>
          c.class_name.trim().toLowerCase() ===
          detectedClassName.value.toLowerCase(),
      );
      importClass.value = match ? match.id : "";
    } else {
      importClass.value = "";
    }

    // ── Parse student data rows ───────────────────────────────────────────
    // Data rows: first cell is a positive integer (the ល.រ column)
    const dataRows = rows.filter((row) =>
      /^\d+$/.test(String(row[0] || "").trim()),
    );

    importRows.value = dataRows.map((row) => {
      const fullName = String(row[1] || "").trim();
      const genderRaw = String(row[2] || "").trim();
      const dobRaw = String(row[3] || "").trim();
      // row[4] = birthplace — not in schema, skip
      const fatherName = String(row[5] || "")
        .trim()
        .replace(/^\s+$/, "");
      const motherName = String(row[6] || "")
        .trim()
        .replace(/^\s+$/, "");
      const address = String(row[7] || "").trim();
      // row[8] = ethnicity — not in schema, skip
      const disability = String(row[9] || "").trim();

      const gender =
        genderRaw === "ស្រី" ? "Female" : genderRaw === "ប្រុស" ? "Male" : "";
      const dob = parseDob(dobRaw);

      const valid = fullName.length > 0 && dob.length > 0;
      const reasons = [];
      if (!fullName) reasons.push("គ្មានឈ្មោះ");
      if (!dob) reasons.push("ថ្ងៃខែឆ្នាំកំណើតខុសទម្រង់");

      return {
        _num: String(row[0]).trim(),
        fullName,
        gender,
        dob,
        dobDisplay: dobRaw,
        fatherName: fatherName || null,
        motherName: motherName || null,
        address: address || null,
        isDisability: disability.length > 0,
        valid,
        reasons,
      };
    });
  };
  reader.readAsArrayBuffer(file);
}

/** Create the detected class on-the-fly, add it to the local list, auto-select it. */
async function createAndAssignClass() {
  creatingClass.value = true;
  const { data, error } = await supabase
    .from("classes")
    .insert({
      class_name: detectedClassName.value,
      school_id: auth.schoolId,
      academic_year_id: yearStore.selectedYearId,
      turn: "morning", // safe default — admin can edit on Classes page
    })
    .select("id, class_name")
    .single();

  creatingClass.value = false;
  if (error) {
    showToast(error.message, "error");
    return;
  }

  // Merge into local list (keep sorted) and auto-select
  classes.value.push(data);
  classes.value.sort((a, b) => a.class_name.localeCompare(b.class_name, "km"));
  importClass.value = data.id;
  showToast(`បានបង្កើតថ្នាក់ "${data.class_name}"`, "success");
}

async function doImport() {
  if (!validRows.value.length) return;
  importing.value = true;

  const payload = validRows.value.map((r) => ({
    full_name: r.fullName,
    gender: r.gender || null,
    dob: r.dob,
    father_name: r.fatherName,
    mother_name: r.motherName,
    address: r.address,
    is_disability: r.isDisability,
    is_scholarship: false,
    is_graduated: false,
    class_id: importClass.value || null,
    academic_year_id: yearStore.selectedYearId,
    school_id: auth.schoolId,
  }));

  const { error } = await supabase.from("students").insert(payload);
  importing.value = false;
  if (error) {
    showToast(error.message, "error");
    return;
  }

  showToast(`បានបន្ថែមសិស្សចំនួន ${validRows.value.length} នាក់!`, "success");
  showImportModal.value = false;
  loadStudents();
}

// ─────────────────────────────────────────────────────────────────────────────
</script>

<template>
  <div>
    <!-- Page header -->
    <div class="page-header">
      <div>
        <h1 class="page-title">សិស្ស</h1>
        <p class="page-subtitle">
          សិស្សចំនួន {{ students.length }} នាក់កំពុងសិក្សា
        </p>
      </div>
      <div style="display: flex; gap: 8px">
        <a
          href="/student_import_template.xlsx"
          download="student_import_template.xlsx"
          class="btn btn-ghost"
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            style="width: 16px; height: 16px"
          >
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          ទាញឯកសារគំរូ
        </a>

        <button class="btn btn-ghost" @click="openImportModal">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            style="width: 16px; height: 16px"
          >
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="17 8 12 3 7 8" />
            <line x1="12" y1="3" x2="12" y2="15" />
          </svg>
          នាំចូល Excel
        </button>

        <button class="btn btn-ghost" @click="refactorNames" :disabled="refactoring">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px">
            <polyline points="1 4 1 10 7 10" />
            <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10" />
          </svg>
          {{ refactoring ? 'កំពុងប្តូរ...' : 'ប្តូរឈ្មោះ (នាមខ្លួន នាមត្រកូល)' }}
        </button>
        <button class="btn btn-primary" @click="openAdd">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            style="width: 16px; height: 16px"
          >
            <line x1="12" y1="5" x2="12" y2="19" />
            <line x1="5" y1="12" x2="19" y2="12" />
          </svg>
          បន្ថែមសិស្ស
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div class="filters-bar">
      <div class="search-input-wrap">
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <circle cx="11" cy="11" r="8" />
          <line x1="21" y1="21" x2="16.65" y2="16.65" />
        </svg>
        <input
          class="form-input"
          v-model="search"
          placeholder="ស្វែងរកតាមឈ្មោះ ឬអត្តលេខ..."
        />
      </div>
      <select class="form-select" v-model="filterClass" style="width: 200px">
        <option value="">ថ្នាក់ទាំងអស់</option>
        <option v-for="c in classes" :key="c.id" :value="c.id">
          {{ c.class_name }}
        </option>
      </select>
    </div>

    <!-- Bulk Actions Bar -->
    <div v-if="selectedStudents.length > 0" class="bulk-actions-bar animate-fade-in">
      <div class="bulk-info">
        <input
          type="checkbox"
          :checked="isAllSelected"
          :indeterminate="isPartiallySelected"
          @change="toggleSelectAll"
          style="width: 16px; height: 16px; margin-right: 8px; cursor: pointer;"
        />
        បានជ្រើសរើស <strong>{{ selectedStudents.length }}</strong> នាក់
      </div>
      <div class="bulk-buttons">
        <select class="form-select bulk-select" v-model="bulkClassId">
          <option value="">— ផ្លាស់ប្តូរថ្នាក់រៀនជាក្រុម —</option>
          <option v-for="c in classes" :key="c.id" :value="c.id">
            {{ c.class_name }}
          </option>
          <option value="none">— ដកចេញពីថ្នាក់ —</option>
        </select>
        <button class="btn btn-primary btn-sm" :disabled="!bulkClassId || savingBulk" @click="applyBulkClass">
          {{ savingBulk ? "កំពុងប្តូរ..." : "យល់ព្រមប្តូរថ្នាក់" }}
        </button>
        <button class="btn btn-danger btn-sm" @click="confirmBulkDelete">
          លុបចោលជាក្រុម
        </button>
        <button class="btn btn-ghost btn-sm" @click="selectedStudents = []">
          បោះបង់
        </button>
      </div>
    </div>

    <!-- Student table -->
    <div class="card">
      <div v-if="loading" class="card-body">
        <div
          v-for="i in 6"
          :key="i"
          class="skeleton"
          style="height: 52px; margin-bottom: 10px; border-radius: 8px"
        ></div>
      </div>
      <div v-else-if="filtered.length === 0" class="empty-state">
        <AcademicCapIcon class="w-12 h-12 text-gray-400" />
        <p class="empty-state-title">រកមិនឃើញសិស្សទេ</p>
        <p class="empty-state-desc">បន្ថែមសិស្សដំបូងរបស់អ្នកដើម្បីចាប់ផ្តើម</p>
        <button class="btn btn-primary" @click="openAdd">បន្ថែមសិស្ស</button>
      </div>
      <div v-else class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th style="width: 40px; text-align: center;">
                <input
                  type="checkbox"
                  :checked="isAllSelected"
                  :indeterminate="isPartiallySelected"
                  @change="toggleSelectAll"
                  style="width: 16px; height: 16px; cursor: pointer; vertical-align: middle;"
                />
              </th>
              <th>សិស្ស</th>
              <th>អត្តលេខ</th>
              <th>ភេទ</th>
              <th>ថ្ងៃខែឆ្នាំកំណើត</th>
              <th>ថ្នាក់</th>
              <th>ស្ថានភាព</th>
              <th>សកម្មភាព</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="s in filtered"
              :key="s.id"
              style="cursor: pointer"
              :class="{ 'row-selected': selectedStudents.includes(s.id) }"
              @click="router.push('/admin/students/' + s.id)"
            >
              <td @click.stop style="text-align: center; width: 40px;">
                <input
                  type="checkbox"
                  v-model="selectedStudents"
                  :value="s.id"
                  style="width: 16px; height: 16px; cursor: pointer; vertical-align: middle;"
                />
              </td>
              <td @click.stop>
                <div style="display: flex; align-items: center; gap: 10px">
                  <div class="avatar">{{ initials(s.full_name) }}</div>
                  <div>
                    <div style="font-weight: 600; font-size: 13px">
                      {{ s.full_name }}
                    </div>
                    <div style="font-size: 11px; color: var(--text-muted)">
                      {{ s.father_name ? "ឪពុក: " + s.father_name : "" }}
                    </div>
                  </div>
                </div>
              </td>
              <td style="font-size: 12px; color: var(--text-secondary)">
                {{ s.real_id || "—" }}
              </td>
              <td>
                <span
                  class="badge"
                  :class="s.gender === 'Male' ? 'badge-blue' : 'badge-red'"
                >
                  {{
                    s.gender === "Male"
                      ? "ប្រុស"
                      : isFemale(s.gender)
                        ? "ស្រី"
                        : "—"
                  }}
                </span>
              </td>
              <td style="font-size: 13px">{{ formatDate(s.dob) }}</td>
              <td>
                <span class="badge badge-gray">{{
                  s.classes?.class_name || "—"
                }}</span>
              </td>
              <td>
                <div style="display: flex; gap: 4px">
                  <span v-if="s.is_scholarship" class="badge badge-green"
                    >អាហារូបករណ៍</span
                  >
                  <span v-if="s.is_disability" class="badge badge-yellow"
                    >ពិការភាព</span
                  >
                </div>
              </td>
              <td @click.stop>
                <div class="table-actions">
                  <button
                    class="btn btn-ghost btn-sm btn-icon"
                    @click="router.push('/admin/students/' + s.id)"
                    title="លម្អិត"
                  >
                    <svg
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                      <circle cx="12" cy="12" r="3" />
                    </svg>
                  </button>
                  <button
                    class="btn btn-ghost btn-sm btn-icon"
                    @click="openEdit(s)"
                    title="កែប្រែ"
                  >
                    <svg
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"
                      />
                      <path
                        d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"
                      />
                    </svg>
                  </button>
                  <button
                    class="btn btn-danger btn-sm btn-icon"
                    @click="deleteTarget = s"
                    title="លុប"
                  >
                    <svg
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <polyline points="3 6 5 6 21 6" />
                      <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
                      <path d="M10 11v6M14 11v6" />
                      <path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                    </svg>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ── Add / Edit modal ───────────────────────────────────────────────── -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal modal-lg">
        <div class="modal-header">
          <span class="modal-title">
            {{ isEdit ? "កែប្រែព័ត៌មានសិស្ស" : "បន្ថែមសិស្សថ្មី" }}
          </span>
          <button
            class="btn btn-ghost btn-sm btn-icon"
            @click="showModal = false"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>
        <div class="modal-body">
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px">
            <div class="form-group" style="grid-column: 1/-1">
              <label class="form-label">ឈ្មោះពេញ *</label>
              <input
                class="form-input"
                v-model="form.full_name"
                placeholder="ឧ. ចាន់ សុភា"
              />
            </div>
            <div class="form-group">
              <label class="form-label">អត្តលេខសិស្ស</label>
              <input
                class="form-input"
                v-model="form.real_id"
                placeholder="ឧ. S-001"
              />
            </div>
            <div class="form-group">
              <label class="form-label">ភេទ</label>
              <select class="form-select" v-model="form.gender">
                <option value="">— ជ្រើសរើស —</option>
                <option value="Male">ប្រុស</option>
                <option value="Female">ស្រី</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">ថ្ងៃខែឆ្នាំកំណើត *</label>
              <input class="form-input" type="date" v-model="form.dob" />
            </div>
            <div class="form-group">
              <label class="form-label">ថ្នាក់រៀន</label>
              <select class="form-select" v-model="form.class_id">
                <option value="">— ជ្រើសរើសថ្នាក់ —</option>
                <option v-for="c in classes" :key="c.id" :value="c.id">
                  {{ c.class_name }}
                </option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">លេខទូរស័ព្ទ</label>
              <input
                class="form-input"
                v-model="form.phone_number"
                placeholder="012 345 678"
              />
            </div>
            <div class="form-group" style="grid-column: 1/-1">
              <label class="form-label">អាសយដ្ឋាន</label>
              <textarea
                class="form-textarea"
                v-model="form.address"
                rows="2"
                placeholder="អាសយដ្ឋានផ្ទះ"
              ></textarea>
            </div>
            <div class="form-group">
              <label class="form-label">ឈ្មោះឪពុក</label>
              <input
                class="form-input"
                v-model="form.father_name"
                placeholder="ឈ្មោះឪពុក"
              />
            </div>
            <div class="form-group">
              <label class="form-label">មុខរបរឪពុក</label>
              <input
                class="form-input"
                v-model="form.father_job"
                placeholder="មុខរបរឪពុក"
              />
            </div>
            <div class="form-group">
              <label class="form-label">ឈ្មោះម្ដាយ</label>
              <input
                class="form-input"
                v-model="form.mother_name"
                placeholder="ឈ្មោះម្ដាយ"
              />
            </div>
            <div class="form-group">
              <label class="form-label">មុខរបរម្ដាយ</label>
              <input
                class="form-input"
                v-model="form.mother_job"
                placeholder="មុខរបរម្ដាយ"
              />
            </div>
            <div
              class="form-group"
              style="grid-column: 1/-1; display: flex; gap: 24px"
            >
              <label
                style="
                  display: flex;
                  align-items: center;
                  gap: 8px;
                  cursor: pointer;
                  font-size: 13px;
                "
              >
                <input
                  type="checkbox"
                  v-model="form.is_scholarship"
                  style="width: 15px; height: 15px"
                />
                ទទួលបានអាហារូបករណ៍
              </label>
              <label
                style="
                  display: flex;
                  align-items: center;
                  gap: 8px;
                  cursor: pointer;
                  font-size: 13px;
                "
              >
                <input
                  type="checkbox"
                  v-model="form.is_disability"
                  style="width: 15px; height: 15px"
                />
                មានពិការភាព
              </label>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">
            បោះបង់
          </button>
          <button class="btn btn-primary" @click="save" :disabled="saving">
            {{
              saving
                ? "កំពុងរក្សាទុក..."
                : isEdit
                  ? "រក្សាទុកការកែប្រែ"
                  : "បន្ថែមសិស្ស"
            }}
          </button>
        </div>
      </div>
    </div>

    <!-- ── Delete confirm modal ───────────────────────────────────────────── -->
    <div
      v-if="deleteTarget"
      class="modal-overlay"
      @click.self="deleteTarget = null"
    >
      <div class="modal" style="max-width: 380px">
        <div class="modal-body" style="text-align: center; padding: 32px 24px">
          <TrashIcon
            class="w-10 h-10 text-gray-400"
            style="margin: 0 auto 12px"
          />
          <h3 style="margin-bottom: 8px">លុបសិស្ស?</h3>
          <p style="color: var(--text-secondary); font-size: 13px">
            អ្នកពិតជាចង់លុប <strong>{{ deleteTarget.full_name }}</strong> មែនទេ?
            រាល់ទិន្នន័យពាក់ព័ន្ធទាំងអស់នឹងត្រូវលុបចេញផងដែរ។
          </p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="deleteTarget = null">
            បោះបង់
          </button>
          <button class="btn btn-danger" @click="doDelete">យល់ព្រមលុប</button>
        </div>
      </div>
    </div>

    <!-- ── Refactor progress modal ────────────────────────────────────────────── -->
    <div v-if="refactoring" class="modal-overlay">
      <div class="modal" style="max-width: 400px; text-align:center;">
        <div class="modal-body" style="padding:40px 24px;">
          <h3 style="margin-bottom:12px;">កំពុងប្តូរឈ្មោះសិស្ស...</h3>
          <div style="background:#e2e8f0; border-radius:8px; height:24px; overflow:hidden; margin-bottom:8px;">
            <div style="height:100%; background:linear-gradient(90deg, #3b82f6, #8b5cf6); border-radius:8px; transition:width 0.2s; display:flex; align-items:center; justify-content:center;"
                 :style="{ width: (refactorProgress.total > 0 ? (refactorProgress.current / refactorProgress.total * 100) : 0) + '%' }">
              <span v-if="refactorProgress.current > 0" style="font-size:11px;font-weight:700;color:white;white-space:nowrap;">
                {{ refactorProgress.current }}/{{ refactorProgress.total }}
              </span>
            </div>
          </div>
          <p style="color:var(--text-secondary);font-size:13px;">សូមរង់ចាំមួយភ្លែត</p>
        </div>
      </div>
    </div>

    <!-- ── Bulk Delete confirm modal ───────────────────────────────────────────── -->
    <div
      v-if="showBulkDeleteModal"
      class="modal-overlay"
      @click.self="showBulkDeleteModal = false"
    >
      <div class="modal" style="max-width: 380px">
        <div class="modal-body" style="text-align: center; padding: 32px 24px">
          <TrashIcon
            class="w-10 h-10 text-red-500"
            style="margin: 0 auto 12px"
          />
          <h3 style="margin-bottom: 8px">លុបសិស្សជាក្រុម?</h3>
          <p style="color: var(--text-secondary); font-size: 13px">
            អ្នកពិតជាចង់លុបសិស្សដែលបានជ្រើសរើសទាំង <strong>{{ selectedStudents.length }}</strong> នាក់នេះមែនទេ?
            រាល់ទិន្នន័យពាក់ព័ន្ធទាំងអស់នឹងត្រូវលុបចេញពីប្រព័ន្ធជាអចិន្ត្រៃយ៍។
          </p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showBulkDeleteModal = false">
            បោះបង់
          </button>
          <button class="btn btn-danger" @click="doBulkDelete" :disabled="deletingBulk">
            {{ deletingBulk ? "កំពុងលុប..." : "យល់ព្រមលុបទាំងអស់" }}
          </button>
        </div>
      </div>
    </div>

    <!-- ── Excel Import modal ─────────────────────────────────────────────── -->
    <div
      v-if="showImportModal"
      class="modal-overlay"
      @click.self="showImportModal = false"
    >
      <div
        class="modal"
        style="
          max-width: 800px;
          max-height: 90vh;
          display: flex;
          flex-direction: column;
        "
      >
        <div class="modal-header">
          <span class="modal-title">នាំចូលសិស្សពីឯកសារ Excel</span>
          <button
            class="btn btn-ghost btn-sm btn-icon"
            @click="showImportModal = false"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>

        <div
          class="modal-body"
          style="
            overflow-y: auto;
            flex: 1;
            display: flex;
            flex-direction: column;
            gap: 16px;
          "
        >
          <!-- ── Drop zone (no file yet) ──────────────────────────────── -->
          <div
            v-if="importRows.length === 0"
            class="import-dropzone"
            :class="{ 'import-dropzone--active': isDragging }"
            @dragover.prevent="isDragging = true"
            @dragleave.prevent="isDragging = false"
            @drop.prevent="onFileDrop"
            @click="fileInputRef.click()"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              style="width: 44px; height: 44px; color: var(--text-muted)"
            >
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
              <polyline points="17 8 12 3 7 8" />
              <line x1="12" y1="3" x2="12" y2="15" />
            </svg>
            <p style="margin: 10px 0 4px; font-weight: 600; font-size: 14px">
              ចុចដើម្បីជ្រើស ឬអូសឯកសារ Excel មកទីនេះ
            </p>
            <p style="font-size: 12px; color: var(--text-muted)">
              .xlsx · .xls
            </p>
            <input
              ref="fileInputRef"
              type="file"
              accept=".xlsx,.xls"
              style="display: none"
              @change="onFileChange"
            />
          </div>

          <!-- ── Preview (file has been parsed) ──────────────────────── -->
          <template v-else>
            <!-- Stats + reset -->
            <div
              style="
                display: flex;
                align-items: center;
                gap: 10px;
                flex-wrap: wrap;
              "
            >
              <span
                class="badge badge-green"
                style="font-size: 12px; padding: 4px 10px"
              >
                ✓ {{ validRows.length }} នាក់អាចនាំចូលបាន
              </span>
              <span
                v-if="skippedRows.length"
                class="badge badge-yellow"
                style="font-size: 12px; padding: 4px 10px"
              >
                ⚠ {{ skippedRows.length }} ជួររំលង
              </span>
              <button
                class="btn btn-ghost btn-sm"
                style="margin-left: auto"
                @click="resetImport"
              >
                ← ជ្រើសឯកសារផ្សេង
              </button>
            </div>

            <!-- Class assignment -->
            <div class="form-group" style="margin: 0">
              <label class="form-label">ថ្នាក់រៀន</label>

              <!-- Detected but not found → offer to create -->
              <div
                v-if="detectedClassName && !importClass"
                class="import-class-banner import-class-banner--warn"
              >
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  style="width: 16px; height: 16px; flex-shrink: 0"
                >
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="8" x2="12" y2="12" />
                  <line x1="12" y1="16" x2="12.01" y2="16" />
                </svg>
                <span style="flex: 1">
                  ឯកសារនេះជាថ្នាក់ <strong>{{ detectedClassName }}</strong>
                  ប៉ុន្តែមិនទាន់មានក្នុងប្រព័ន្ធ។
                </span>
                <button
                  class="btn btn-sm btn-primary"
                  style="white-space: nowrap"
                  :disabled="creatingClass"
                  @click="createAndAssignClass"
                >
                  {{
                    creatingClass
                      ? "កំពុងបង្កើត..."
                      : `+ បង្កើតថ្នាក់ "${detectedClassName}"`
                  }}
                </button>
              </div>

              <!-- Detected and matched → success hint -->
              <div
                v-else-if="detectedClassName && importClass"
                class="import-class-banner import-class-banner--success"
              >
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  style="width: 15px; height: 15px; flex-shrink: 0"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                បានរកឃើញថ្នាក់
                <strong>{{ detectedClassName }}</strong> ដោយស្វ័យប្រវត្តិ
              </div>

              <!-- Always-visible dropdown so user can override -->
              <select
                class="form-select"
                v-model="importClass"
                :style="detectedClassName ? 'margin-top:8px;' : ''"
              >
                <option value="">— មិនកំណត់ថ្នាក់ —</option>
                <option v-for="c in classes" :key="c.id" :value="c.id">
                  {{ c.class_name }}
                </option>
              </select>
              <p
                style="
                  font-size: 11px;
                  color: var(--text-muted);
                  margin-top: 4px;
                "
              >
                ថ្នាក់នេះនឹងត្រូវបានកំណត់ទៅសិស្សទាំងអស់ដែលបាននាំចូល។
              </p>
            </div>

            <!-- Preview table -->
            <div
              style="
                overflow-x: auto;
                border: 1px solid var(--border);
                border-radius: 8px;
              "
            >
              <table style="min-width: 620px">
                <thead>
                  <tr>
                    <th style="width: 36px">#</th>
                    <th>ឈ្មោះ</th>
                    <th style="width: 72px">ភេទ</th>
                    <th style="width: 110px">ថ្ងៃខែឆ្នាំ</th>
                    <th>ឪពុក</th>
                    <th>ម្ដាយ</th>
                    <th style="width: 60px">ពិការ</th>
                    <th style="width: 72px">ស្ថានភាព</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="r in importRows"
                    :key="r._num"
                    :style="
                      !r.valid
                        ? 'opacity:.4;background:var(--bg-secondary,#f9fafb);'
                        : ''
                    "
                  >
                    <td style="font-size: 12px; color: var(--text-muted)">
                      {{ r._num }}
                    </td>
                    <td style="font-weight: 600; font-size: 13px">
                      {{ r.fullName || "—" }}
                    </td>
                    <td>
                      <span
                        v-if="r.gender"
                        class="badge"
                        :class="
                          r.gender === 'Male' ? 'badge-blue' : 'badge-red'
                        "
                      >
                        {{ r.gender === "Male" ? "ប្រុស" : "ស្រី" }}
                      </span>
                      <span
                        v-else
                        style="color: var(--text-muted); font-size: 12px"
                        >—</span
                      >
                    </td>
                    <td style="font-size: 12px">{{ r.dobDisplay || "—" }}</td>
                    <td style="font-size: 12px">{{ r.fatherName || "—" }}</td>
                    <td style="font-size: 12px">{{ r.motherName || "—" }}</td>
                    <td style="text-align: center">
                      <span
                        v-if="r.isDisability"
                        class="badge badge-yellow"
                        style="font-size: 11px"
                        >បាទ</span
                      >
                      <span
                        v-else
                        style="color: var(--text-muted); font-size: 12px"
                        >—</span
                      >
                    </td>
                    <td>
                      <span
                        v-if="r.valid"
                        class="badge badge-green"
                        style="font-size: 11px"
                        >OK</span
                      >
                      <span
                        v-else
                        class="badge badge-red"
                        style="font-size: 11px"
                        :title="r.reasons.join(', ')"
                        >រំលង</span
                      >
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <p
              v-if="skippedRows.length"
              style="font-size: 12px; color: var(--text-muted); margin: 0"
            >
              ⚠ ជួររំលង = គ្មានឈ្មោះ ឬថ្ងៃខែឆ្នាំកំណើតមិនត្រឹមត្រូវ
              (ត្រូវការទម្រង់ DD/MM/YYYY)។
            </p>
          </template>
        </div>

        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showImportModal = false">
            បោះបង់
          </button>
          <button
            v-if="importRows.length > 0"
            class="btn btn-primary"
            :disabled="importing || validRows.length === 0"
            @click="doImport"
          >
            {{
              importing
                ? "កំពុងបន្ថែម..."
                : `បន្ថែមសិស្ស ${validRows.length} នាក់`
            }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ── Drop zone ────────────────────────────────────────────────────────────── */
.import-dropzone {
  border: 2px dashed var(--border);
  border-radius: 12px;
  padding: 48px 24px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  cursor: pointer;
  transition:
    border-color 0.15s,
    background 0.15s;
  color: var(--text-secondary);
  user-select: none;
}
.import-dropzone:hover,
.import-dropzone--active {
  border-color: var(--primary);
  background: color-mix(in srgb, var(--primary) 5%, transparent);
}

/* ── Class detection banners ──────────────────────────────────────────────── */
.import-class-banner {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 13px;
}
.import-class-banner--warn {
  background: #fffbeb;
  border: 1px solid #fcd34d;
  color: #92400e;
}
.import-class-banner--success {
  background: #f0fdf4;
  border: 1px solid #86efac;
  color: #166534;
}

/* ── Bulk actions bar ─────────────────────────────────────────────────────── */
.bulk-actions-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  background: var(--bg-info);
  border: 1px solid var(--border-info);
  border-radius: 10px;
  margin-bottom: 16px;
  gap: 16px;
  flex-wrap: wrap;
}
.bulk-info {
  display: flex;
  align-items: center;
  font-size: 13px;
  color: var(--color-info);
}
.bulk-buttons {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.bulk-select {
  width: auto;
  min-width: 180px;
  padding: 6px 12px;
  font-size: 13px;
}
.row-selected td {
  background: var(--bg-info) !important;
}
.row-selected:hover td {
  background: color-mix(in srgb, var(--primary-50) 80%, white) !important;
}
</style>
