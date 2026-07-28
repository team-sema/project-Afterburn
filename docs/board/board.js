const STORAGE_KEY = "afterburn-kanban-v1";
const CARDS_URL = "cards.json";

/** @type {{ updated?: string, source?: string, columns: Array<object>, cards: Array<object> }} */
let boardData = null;
/** @type {Record<string, string>} card id → column from last fetched repo JSON */
let remoteColumnsById = {};

const boardEl = document.getElementById("board");
const metaEl = document.getElementById("meta");
const modalEl = document.getElementById("modal");
const modalTitle = document.getElementById("modal-title");
const modalDesc = document.getElementById("modal-desc");
const modalFile = document.getElementById("modal-file");
const modalBody = document.getElementById("modal-body");

let dragId = null;
let didDrag = false;
let suppressClick = false;

function toast(message) {
  let el = document.querySelector(".toast");
  if (!el) {
    el = document.createElement("div");
    el.className = "toast";
    document.body.appendChild(el);
  }
  el.textContent = message;
  el.classList.add("show");
  clearTimeout(toast._t);
  toast._t = setTimeout(() => el.classList.remove("show"), 2200);
}

function cloneData(data) {
  return JSON.parse(JSON.stringify(data));
}

function saveLocal() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(boardData));
}

function clearLocal() {
  localStorage.removeItem(STORAGE_KEY);
}

function loadLocal() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed?.columns || !parsed?.cards) return null;
    if (!parsed.columns.some((c) => c.id === "ideas")) return null;
    return parsed;
  } catch {
    return null;
  }
}

function rememberRemote(remote) {
  remoteColumnsById = Object.fromEntries(
    (remote.cards || []).map((c) => [c.id, c.column])
  );
}

function columnDiffs() {
  const diffs = [];
  for (const card of boardData.cards) {
    const from = remoteColumnsById[card.id];
    if (from == null) continue;
    if (from === card.column) continue;
    diffs.push({
      id: card.id,
      title: card.title,
      from,
      to: card.column,
      fromTitle: columnTitle(from),
      toTitle: columnTitle(card.column),
    });
  }
  return diffs;
}

function buildAgentPrompt(diffs) {
  const today = new Date().toISOString().slice(0, 10);
  const lines = diffs.map(
    (d) => `- \`${d.id}\` (${d.title}): \`${d.from}\` → \`${d.to}\` (${d.fromTitle} → ${d.toTitle})`
  );

  return [
    "칸반 열 반영 요청 (보드 → 저장소)",
    "",
    "아래는 GitHub Pages 칸반에서 드래그로 옮긴 열 변경입니다.",
    "`docs/board/cards.json`의 해당 카드 `column`을 반영하고, `updated`를 오늘 날짜로 갱신하세요.",
    "`done` / `fix` / `review` 등 이력에 남길 가치가 있으면 `docs/board/cards/<id>.md`에 한 줄 추가하세요.",
    "칸반 파일만 바뀌면 `main`에서 바로 커밋해도 됩니다. 커밋은 내가 요청할 때만 하세요(지금 요청함).",
    "무관한 카드는 건드리지 마세요.",
    "",
    `날짜: ${today}`,
    "변경:",
    ...lines,
    "",
    "커밋 메시지 예: `docs: sync kanban columns from board`",
  ].join("\n");
}

async function copyAgentPrompt() {
  const diffs = columnDiffs();
  if (diffs.length === 0) {
    toast("저장소와 다른 열 이동이 없습니다");
    return;
  }
  const text = buildAgentPrompt(diffs);
  try {
    await navigator.clipboard.writeText(text);
    toast(`프롬프트 복사 · 변경 ${diffs.length}건 → Cursor에 붙여넣기`);
  } catch {
    prompt("Cursor에 붙여넣을 프롬프트:", text);
  }
}

function updateMeta(fromLocal) {
  const n = boardData.cards.length;
  const stamp = boardData.updated || "—";
  const dirty = columnDiffs().length;
  const dirtyPart = dirty > 0 ? ` · 미반영 ${dirty}` : "";
  metaEl.textContent = fromLocal
    ? `임시 저장 · ${n}장 · 원본 ${stamp}${dirtyPart}`
    : `저장소 JSON · ${n}장 · ${stamp}${dirtyPart}`;
}

function cardsInColumn(columnId) {
  return boardData.cards.filter((c) => c.column === columnId);
}

function cardDescription(card) {
  return card.description || card.body || "";
}

function render() {
  boardEl.innerHTML = "";
  for (const col of boardData.columns) {
    const cards = cardsInColumn(col.id);
    const column = document.createElement("section");
    column.className = "column";
    column.dataset.col = col.id;

    column.innerHTML = `
      <div class="column-head">
        <div class="column-title-row">
          <div class="column-title"><span class="dot" aria-hidden="true"></span>${escapeHtml(col.title)}</div>
          <span class="count">${cards.length}</span>
        </div>
        ${col.hint ? `<p class="column-hint">${escapeHtml(col.hint)}</p>` : ""}
      </div>
      <div class="cards" data-column="${col.id}"></div>
    `;

    const list = column.querySelector(".cards");
    for (const card of cards) {
      list.appendChild(renderCard(card));
    }

    list.addEventListener("dragover", onDragOver);
    list.addEventListener("dragleave", onDragLeave);
    list.addEventListener("drop", onDrop);
    boardEl.appendChild(column);
  }
}

function renderCard(card) {
  const el = document.createElement("article");
  el.className = "card";
  el.draggable = true;
  el.dataset.id = card.id;
  el.tabIndex = 0;

  const desc = cardDescription(card);
  const tags = (card.tags || [])
    .map((t) => `<span class="tag">${escapeHtml(t)}</span>`)
    .join("");

  el.innerHTML = `
    <h3 class="card-title">${escapeHtml(card.title)}</h3>
    ${desc ? `<p class="card-desc">${escapeHtml(desc)}</p>` : ""}
    ${tags ? `<div class="tags">${tags}</div>` : ""}
  `;

  el.addEventListener("dragstart", onDragStart);
  el.addEventListener("dragend", onDragEnd);
  el.addEventListener("click", () => {
    if (suppressClick) {
      suppressClick = false;
      return;
    }
    openCard(card.id);
  });
  el.addEventListener("keydown", (e) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      openCard(card.id);
    }
  });
  return el;
}

function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function onDragStart(e) {
  dragId = e.currentTarget.dataset.id;
  didDrag = false;
  e.currentTarget.classList.add("dragging");
  e.dataTransfer.effectAllowed = "move";
  e.dataTransfer.setData("text/plain", dragId);
}

function onDragEnd(e) {
  e.currentTarget.classList.remove("dragging");
  if (didDrag) suppressClick = true;
  dragId = null;
  didDrag = false;
  document.querySelectorAll(".column.drag-over").forEach((c) => c.classList.remove("drag-over"));
}

function onDragOver(e) {
  e.preventDefault();
  e.dataTransfer.dropEffect = "move";
  e.currentTarget.closest(".column")?.classList.add("drag-over");
}

function onDragLeave(e) {
  if (!e.currentTarget.contains(e.relatedTarget)) {
    e.currentTarget.closest(".column")?.classList.remove("drag-over");
  }
}

function onDrop(e) {
  e.preventDefault();
  const column = e.currentTarget.closest(".column");
  column?.classList.remove("drag-over");
  const id = e.dataTransfer.getData("text/plain") || dragId;
  const nextCol = e.currentTarget.dataset.column;
  if (!id || !nextCol) return;

  const card = boardData.cards.find((c) => c.id === id);
  if (!card || card.column === nextCol) return;

  didDrag = true;
  card.column = nextCol;
  saveLocal();
  updateMeta(true);
  render();
  toast(`「${card.title}」 → ${columnTitle(nextCol)}`);
}

function columnTitle(id) {
  return boardData.columns.find((c) => c.id === id)?.title || id;
}

async function openCard(cardId) {
  const card = boardData.cards.find((c) => c.id === cardId);
  if (!card) return;

  modalTitle.textContent = card.title;
  modalDesc.textContent = cardDescription(card);
  modalFile.textContent = card.file || `(파일 없음: ${card.id}.md)`;
  modalBody.innerHTML = `<p class="md-error">불러오는 중…</p>`;
  modalEl.hidden = false;
  document.body.style.overflow = "hidden";

  if (!card.file) {
    modalBody.innerHTML = `<p class="md-error">이 카드에 연결된 MD 파일이 없습니다.</p>`;
    return;
  }

  try {
    const res = await fetch(card.file, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const md = await res.text();
    modalBody.innerHTML = renderMarkdown(md);
  } catch (err) {
    modalBody.innerHTML = `<p class="md-error">MD를 불러오지 못했습니다 (${escapeHtml(err.message)}).<br/>경로: <code>${escapeHtml(card.file)}</code></p>`;
  }
}

function closeModal() {
  modalEl.hidden = true;
  document.body.style.overflow = "";
}

/** 아주 작은 마크다운 서브셋 (제목·인용·목록·인라인 코드·링크·문단). */
function renderMarkdown(src) {
  const lines = String(src).replace(/\r\n/g, "\n").split("\n");
  const html = [];
  let inUl = false;
  let inOl = false;

  const closeLists = () => {
    if (inUl) {
      html.push("</ul>");
      inUl = false;
    }
    if (inOl) {
      html.push("</ol>");
      inOl = false;
    }
  };

  const inline = (text) => {
    let t = escapeHtml(text);
    t = t.replace(/`([^`]+)`/g, "<code>$1</code>");
    t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
    t = t.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    return t;
  };

  for (const raw of lines) {
    const line = raw;
    if (/^\s*$/.test(line)) {
      closeLists();
      continue;
    }
    if (line.startsWith("### ")) {
      closeLists();
      html.push(`<h3>${inline(line.slice(4))}</h3>`);
      continue;
    }
    if (line.startsWith("## ")) {
      closeLists();
      html.push(`<h2>${inline(line.slice(3))}</h2>`);
      continue;
    }
    if (line.startsWith("# ")) {
      closeLists();
      html.push(`<h1>${inline(line.slice(2))}</h1>`);
      continue;
    }
    if (line.startsWith("> ")) {
      closeLists();
      html.push(`<blockquote>${inline(line.slice(2))}</blockquote>`);
      continue;
    }
    if (/^[-*] /.test(line)) {
      if (!inUl) {
        closeLists();
        html.push("<ul>");
        inUl = true;
      }
      html.push(`<li>${inline(line.replace(/^[-*] /, ""))}</li>`);
      continue;
    }
    if (/^\d+\. /.test(line)) {
      if (!inOl) {
        closeLists();
        html.push("<ol>");
        inOl = true;
      }
      html.push(`<li>${inline(line.replace(/^\d+\. /, ""))}</li>`);
      continue;
    }
    closeLists();
    html.push(`<p>${inline(line)}</p>`);
  }
  closeLists();
  return html.join("\n");
}

async function boot() {
  const res = await fetch(CARDS_URL, { cache: "no-store" });
  if (!res.ok) throw new Error(`cards.json load failed: ${res.status}`);
  const remote = await res.json();
  rememberRemote(remote);
  const local = loadLocal();

  if (local) {
    boardData = local;
    const localById = Object.fromEntries(local.cards.map((c) => [c.id, c]));
    boardData.columns = remote.columns;
    boardData.cards = remote.cards.map((remoteCard) => {
      const prev = localById[remoteCard.id];
      if (!prev) return remoteCard;
      return {
        ...remoteCard,
        column: prev.column || remoteCard.column,
      };
    });
    updateMeta(true);
  } else {
    boardData = cloneData(remote);
    updateMeta(false);
  }

  render();
}

document.getElementById("btn-prompt").addEventListener("click", copyAgentPrompt);
document.getElementById("btn-reset").addEventListener("click", async () => {
  clearLocal();
  const res = await fetch(CARDS_URL, { cache: "no-store" });
  const remote = await res.json();
  rememberRemote(remote);
  boardData = cloneData(remote);
  updateMeta(false);
  render();
  toast("저장소 JSON으로 되돌렸습니다");
});

document.getElementById("modal-close").addEventListener("click", closeModal);
modalEl.addEventListener("click", (e) => {
  if (e.target?.dataset?.close) closeModal();
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !modalEl.hidden) closeModal();
});

boot().catch((err) => {
  boardEl.innerHTML = `<p class="hint">보드를 불러오지 못했습니다: ${escapeHtml(err.message)}</p>`;
  console.error(err);
});
