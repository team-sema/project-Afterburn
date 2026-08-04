const CATEGORIES = [
  {
    id: "overview",
    title: "개요",
    desc: "엔진 · 루프 · 폴더",
    file: "overview.md",
  },
  {
    id: "scene-flow",
    title: "씬 플로우",
    desc: "메뉴 · World · 오버레이",
    file: "scene-flow.md",
  },
  {
    id: "components",
    title: "컴포넌트",
    desc: "재사용 커스텀 노드",
    file: "components.md",
  },
  {
    id: "player",
    title: "플레이어",
    desc: "함선 · 통합 무기 목록 · 시설 슬롯",
    file: "player.md",
  },
  {
    id: "enemies",
    title: "적",
    desc: "타입 · 생성기 · Threat",
    file: "enemies.md",
  },
  {
    id: "augments",
    title: "오그먼트",
    desc: "플레이어·적 풀 목록 · 오퍼",
    file: "augments.md",
  },
  {
    id: "combat",
    title: "전투",
    desc: "레이어 · 탄 · 점수 상수",
    file: "combat.md",
  },
  {
    id: "effects",
    title: "이펙트",
    desc: "네온 · 배경 · 폭발",
    file: "effects.md",
  },
  {
    id: "gaps",
    title: "갭 / 확장",
    desc: "미연결 · 백로그 후보",
    file: "gaps.md",
  },
];

const navEl = document.getElementById("cat-nav");
const titleEl = document.getElementById("panel-title");
const pathEl = document.getElementById("panel-path");
const bodyEl = document.getElementById("panel-body");

function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function renderMarkdown(src) {
  const lines = String(src).replace(/\r\n/g, "\n").split("\n");
  const html = [];
  let inUl = false;
  let inOl = false;
  let inTable = false;
  let inCode = false;
  let codeBuf = [];

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

  const closeTable = () => {
    if (inTable) {
      html.push("</tbody></table>");
      inTable = false;
    }
  };

  const inline = (text) => {
    let t = escapeHtml(text);
    t = t.replace(/`([^`]+)`/g, "<code>$1</code>");
    t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    t = t.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    return t;
  };

  const isSep = (line) => /^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$/.test(line);
  const splitRow = (line) =>
    line
      .replace(/^\|/, "")
      .replace(/\|$/, "")
      .split("|")
      .map((c) => c.trim());

  for (const raw of lines) {
    const line = raw;

    if (inCode) {
      if (line.startsWith("```")) {
        html.push(`<pre><code>${escapeHtml(codeBuf.join("\n"))}</code></pre>`);
        codeBuf = [];
        inCode = false;
      } else {
        codeBuf.push(line);
      }
      continue;
    }

    if (line.startsWith("```")) {
      closeLists();
      closeTable();
      inCode = true;
      codeBuf = [];
      continue;
    }

    if (/^\s*$/.test(line)) {
      closeLists();
      closeTable();
      continue;
    }

    if (line.includes("|") && (isSep(line) || splitRow(line).length >= 2)) {
      closeLists();
      if (isSep(line)) continue;
      const cells = splitRow(line);
      if (!inTable) {
        html.push("<table><thead><tr>");
        cells.forEach((c) => html.push(`<th>${inline(c)}</th>`));
        html.push("</tr></thead><tbody>");
        inTable = true;
      } else {
        html.push("<tr>");
        cells.forEach((c) => html.push(`<td>${inline(c)}</td>`));
        html.push("</tr>");
      }
      continue;
    }

    closeTable();

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

  if (inCode) {
    html.push(`<pre><code>${escapeHtml(codeBuf.join("\n"))}</code></pre>`);
  }
  closeLists();
  closeTable();
  return html.join("\n");
}

function renderNav(activeId) {
  navEl.innerHTML = `<h2>Categories</h2>`;
  for (const cat of CATEGORIES) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "cat-btn" + (cat.id === activeId ? " active" : "");
    btn.innerHTML = `
      <span class="cat-title">${escapeHtml(cat.title)}</span>
      <span class="cat-desc">${escapeHtml(cat.desc)}</span>
    `;
    btn.addEventListener("click", () => selectCategory(cat.id, true));
    navEl.appendChild(btn);
  }
}

async function selectCategory(id, pushHash) {
  const cat = CATEGORIES.find((c) => c.id === id) || CATEGORIES[0];
  renderNav(cat.id);
  titleEl.textContent = cat.title;
  pathEl.textContent = `docs/spec/${cat.file}`;
  bodyEl.innerHTML = `<p class="md-error">불러오는 중…</p>`;

  if (pushHash) {
    history.replaceState(null, "", `#${cat.id}`);
  }

  try {
    const res = await fetch(cat.file, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    bodyEl.innerHTML = renderMarkdown(await res.text());
  } catch (err) {
    bodyEl.innerHTML = `<p class="md-error">문서를 불러오지 못했습니다 (${escapeHtml(err.message)}).<br/>로컬에서는 <code>docs</code>에서 HTTP 서버로 열어 주세요.</p>`;
  }
}

function boot() {
  const hash = (location.hash || "").replace(/^#/, "");
  const initial = CATEGORIES.some((c) => c.id === hash) ? hash : "overview";
  selectCategory(initial, !hash);
}

window.addEventListener("hashchange", () => {
  const hash = (location.hash || "").replace(/^#/, "");
  if (CATEGORIES.some((c) => c.id === hash)) selectCategory(hash, false);
});

boot();
