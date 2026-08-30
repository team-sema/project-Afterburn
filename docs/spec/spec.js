/**
 * Spec browser — grouped nav + hash routes (e.g. #enemies/drone).
 * Markdown `#id` / relative `*.md` links resolve to the same routes.
 */
const NAV = [
  {
    id: "overview",
    title: "개요",
    desc: "엔진 · 루프 · 폴더",
    file: "overview.md",
  },
  {
    id: "run-pacing",
    title: "런 · 페이싱",
    desc: "Threat · 스폰 · 엘리트 게이트",
    file: "run-pacing.md",
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
    desc: "재사용 노드 · 시설 버프",
    file: "components.md",
  },
  {
    id: "player",
    title: "플레이어",
    desc: "함선 · 무기 · 시설 · 실드",
    file: "player.md",
  },
  {
    group: true,
    title: "적 · 진형 · 조합",
    hint: "유닛 → 슬롯 → Encounter → 풀",
    children: [
      {
        id: "enemies",
        title: "적",
        desc: "유닛 개요",
        file: "enemies/index.md",
        children: [
          { id: "enemies/drone", title: "Drone", file: "enemies/drone.md" },
          { id: "enemies/striker", title: "Striker", file: "enemies/striker.md" },
          { id: "enemies/awl", title: "Awl", file: "enemies/awl.md" },
          { id: "enemies/bomb", title: "Bomb", file: "enemies/bomb.md" },
          {
            id: "enemies/interceptor",
            title: "Interceptor",
            file: "enemies/interceptor.md",
          },
          { id: "enemies/caster", title: "Caster", file: "enemies/caster.md" },
          { id: "enemies/sniper", title: "Sniper", file: "enemies/sniper.md" },
          {
            id: "enemies/elite-fighter",
            title: "Elite",
            file: "enemies/elite-fighter.md",
          },
        ],
      },
      {
        id: "formations",
        title: "진형",
        desc: "슬롯 기하만",
        file: "formations/index.md",
        children: [
          {
            id: "formations/horizontal",
            title: "Horizontal",
            file: "formations/horizontal.md",
          },
          {
            id: "formations/diamond-5",
            title: "Diamond5",
            file: "formations/diamond-5.md",
          },
          {
            id: "formations/diamond-13",
            title: "Diamond13",
            file: "formations/diamond-13.md",
          },
          { id: "formations/v3", title: "V3", file: "formations/v3.md" },
          { id: "formations/x9", title: "X9", file: "formations/x9.md" },
          {
            id: "formations/interceptor-pair",
            title: "Interceptor pair",
            file: "formations/interceptor-pair.md",
          },
          {
            id: "formations/single",
            title: "Single",
            file: "formations/single.md",
          },
        ],
      },
      {
        id: "encounters",
        title: "Encounter",
        desc: "조합 모델",
        file: "encounters/index.md",
        children: [
          {
            id: "encounters/catalog",
            title: "카탈로그",
            file: "encounters/catalog.md",
          },
        ],
      },
    ],
  },
  {
    id: "augments",
    title: "오그먼트",
    desc: "풀 · 시설 · 무기 모듈 · 오퍼",
    file: "augments.md",
  },
  {
    id: "combat",
    title: "전투",
    desc: "레이어 · 피격=1 · 실드",
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

/** Flat id → page meta */
const PAGES = (() => {
  const map = new Map();
  const add = (page) => {
    if (!page?.id) return;
    map.set(page.id, page);
    (page.children || []).forEach(add);
  };
  for (const entry of NAV) {
    if (entry.group) entry.children.forEach(add);
    else add(entry);
  }
  // legacy hash #enemies used to mean enemies.md
  map.set("enemies-legacy", {
    id: "enemies-legacy",
    title: "적 (리다이렉트)",
    file: "enemies.md",
  });
  return map;
})();

const LAYER_CHIPS = [
  { id: "enemies", label: "① 적" },
  { id: "formations", label: "② 진형" },
  { id: "encounters", label: "③ Encounter" },
  { id: "encounters/catalog", label: "카탈로그" },
  { id: "run-pacing", label: "④ 페이싱" },
];

const navEl = document.getElementById("cat-nav");
const titleEl = document.getElementById("panel-title");
const pathEl = document.getElementById("panel-path");
const bodyEl = document.getElementById("panel-body");
const crumbEl = document.getElementById("panel-crumb");
const chipsEl = document.getElementById("layer-chips");

function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function pageFromHash(raw) {
  const hash = (raw || "").replace(/^#/, "");
  if (!hash) return PAGES.get("overview");
  if (PAGES.has(hash)) return PAGES.get(hash);
  // #enemies.md style
  const bare = hash.replace(/\.md$/, "");
  if (PAGES.has(bare)) return PAGES.get(bare);
  return PAGES.get("overview");
}

function resolveMdHref(href, currentId) {
  if (!href) return null;
  if (href.startsWith("http://") || href.startsWith("https://")) return null;
  if (href.startsWith("#")) {
    const id = href.slice(1).replace(/\.md$/, "");
    return PAGES.has(id) ? id : null;
  }
  // relative .md from current file folder
  if (href.endsWith(".md") || href.includes(".md#")) {
    const [pathPart] = href.split("#");
    const baseDir = (PAGES.get(currentId)?.file || "").replace(/[^/]+$/, "");
    let path = pathPart;
    if (path.startsWith("./")) path = path.slice(2);
    while (path.startsWith("../")) {
      path = path.slice(3);
      // pop one segment from baseDir
    }
    const joined = (baseDir + path).replace(/\\/g, "/");
    const norm = joined.replace(/\/+/g, "/").replace(/\.md$/, "");
    // map file path → id
    for (const [id, page] of PAGES) {
      if (page.file?.replace(/\.md$/, "") === norm) return id;
      if (page.file === joined || page.file === path) return id;
    }
    // enemies/drone.md style without folder prefix
    const guess = path.replace(/\.md$/, "");
    if (PAGES.has(guess)) return guess;
  }
  return null;
}

function renderMarkdown(src, currentId) {
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
    t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) => {
      const route = resolveMdHref(href, currentId);
      if (route) {
        return `<a href="#${route}" data-spec-link="${route}">${label}</a>`;
      }
      const safeHref = escapeHtml(href);
      const external =
        href.startsWith("http://") || href.startsWith("https://")
          ? ' target="_blank" rel="noopener"'
          : "";
      return `<a href="${safeHref}"${external}>${label}</a>`;
    });
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

function isActiveBranch(pageId, activeId) {
  if (!activeId) return false;
  return activeId === pageId || activeId.startsWith(pageId + "/");
}

function makeBtn(page, activeId, depth) {
  const btn = document.createElement("button");
  btn.type = "button";
  btn.className =
    "cat-btn" +
    (page.id === activeId ? " active" : "") +
    (depth ? ` depth-${depth}` : "") +
    (isActiveBranch(page.id, activeId) && page.children ? " open" : "");
  btn.dataset.id = page.id;
  const desc = page.desc
    ? `<span class="cat-desc">${escapeHtml(page.desc)}</span>`
    : "";
  btn.innerHTML = `
    <span class="cat-title">${escapeHtml(page.title)}</span>
    ${desc}
  `;
  btn.addEventListener("click", () => selectPage(page.id, true));
  return btn;
}

function renderNav(activeId) {
  navEl.innerHTML = "";
  const head = document.createElement("h2");
  head.textContent = "Categories";
  navEl.appendChild(head);

  for (const entry of NAV) {
    if (entry.group) {
      const wrap = document.createElement("div");
      wrap.className = "nav-group";
      const label = document.createElement("div");
      label.className = "nav-group-label";
      label.innerHTML = `<span>${escapeHtml(entry.title)}</span>${
        entry.hint
          ? `<small>${escapeHtml(entry.hint)}</small>`
          : ""
      }`;
      wrap.appendChild(label);
      for (const child of entry.children) {
        wrap.appendChild(makeBtn(child, activeId, 0));
        // Always expand leaves in this hierarchy group for discoverability.
        if (child.children) {
          for (const leaf of child.children) {
            wrap.appendChild(makeBtn(leaf, activeId, 1));
          }
        }
      }
      navEl.appendChild(wrap);
      continue;
    }
    navEl.appendChild(makeBtn(entry, activeId, 0));
  }
}

function renderChips(activeId) {
  if (!chipsEl) return;
  chipsEl.innerHTML = "";
  for (const chip of LAYER_CHIPS) {
    const a = document.createElement("a");
    a.className =
      "layer-chip" + (isActiveBranch(chip.id, activeId) ? " active" : "");
    a.href = `#${chip.id}`;
    a.textContent = chip.label;
    a.addEventListener("click", (e) => {
      e.preventDefault();
      selectPage(chip.id, true);
    });
    chipsEl.appendChild(a);
  }
}

function renderCrumb(page) {
  if (!crumbEl) return;
  const parts = page.id.split("/");
  if (parts.length === 1) {
    crumbEl.hidden = true;
    crumbEl.textContent = "";
    return;
  }
  crumbEl.hidden = false;
  const bits = [];
  let acc = "";
  parts.forEach((p, i) => {
    acc = i === 0 ? p : `${acc}/${p}`;
    const meta = PAGES.get(acc);
    const label = meta?.title || p;
    if (i < parts.length - 1) {
      bits.push(`<a href="#${acc}" data-spec-link="${acc}">${escapeHtml(label)}</a>`);
    } else {
      bits.push(`<span>${escapeHtml(label)}</span>`);
    }
  });
  crumbEl.innerHTML = bits.join(" <span class='crumb-sep'>/</span> ");
}

async function selectPage(id, pushHash) {
  const page = PAGES.get(id) || PAGES.get("overview");
  renderNav(page.id);
  renderChips(page.id);
  renderCrumb(page);
  titleEl.textContent = page.title;
  pathEl.textContent = `docs/spec/${page.file}`;
  bodyEl.innerHTML = `<p class="md-error">불러오는 중…</p>`;

  if (pushHash) {
    history.replaceState(null, "", `#${page.id}`);
  }

  try {
    const res = await fetch(page.file, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    bodyEl.innerHTML = renderMarkdown(await res.text(), page.id);
    bodyEl.scrollTop = 0;
    document.querySelector(".spec-panel")?.scrollTo?.(0, 0);
  } catch (err) {
    bodyEl.innerHTML = `<p class="md-error">문서를 불러오지 못했습니다 (${escapeHtml(
      err.message
    )}).<br/>로컬에서는 <code>docs</code>에서 HTTP 서버로 열어 주세요.</p>`;
  }
}

bodyEl.addEventListener("click", (e) => {
  const a = e.target.closest("a[data-spec-link]");
  if (!a) return;
  e.preventDefault();
  selectPage(a.getAttribute("data-spec-link"), true);
});

crumbEl?.addEventListener("click", (e) => {
  const a = e.target.closest("a[data-spec-link]");
  if (!a) return;
  e.preventDefault();
  selectPage(a.getAttribute("data-spec-link"), true);
});

function boot() {
  const page = pageFromHash(location.hash);
  selectPage(page.id, !location.hash);
}

window.addEventListener("hashchange", () => {
  const page = pageFromHash(location.hash);
  selectPage(page.id, false);
});

boot();
