/**
 * Spec browser — grouped nav + hash routes (e.g. #enemies/drone).
 * Markdown `#id` / relative `*.md` links resolve to the same routes.
 */
const NAV = [
  { id: 'guide', title: '기획서 안내', file: 'README.md' },
  { id: 'vision', title: '게임 방향', file: 'vision.md' },
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
    hint: "목록을 누르면 하위가 열린다",
    children: [
      {
        id: "enemies",
        title: "일반 적",
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
          { id: "enemies/tanker", title: "Tanker", file: "enemies/tanker.md" },
          { id: "enemies/caster", title: "Caster", file: "enemies/caster.md" },
          { id: "enemies/sniper", title: "Sniper", file: "enemies/sniper.md" },
        ],
      },
      {
        id: "elites",
        title: "엘리트",
        desc: "독립 콘텐츠 · 구현/시안 구분",
        file: "elites/index.md",
        children: [
          { id: "elites/elite-fighter", title: "Elite Fighter", file: "elites/elite-fighter.md" },
          { id: "elites/elite-awl", title: "Elite Awl", file: "elites/elite-awl.md" },
          { id: "elites/elite-bomb", title: "Elite Bomb (시안)", file: "elites/elite-bomb.md" },
          { id: "elites/elite-caster", title: "Elite Caster (시안)", file: "elites/elite-caster.md" },
        ],
      },
      {
        id: "bosses",
        title: "보스",
        desc: "BOSS 관문 전용",
        file: "bosses/index.md",
        children: [
          { id: "bosses/wall", title: "Wall (프로토타입)", file: "bosses/wall.md" },
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
          { id: "formations/v5", title: "V5", file: "formations/v5.md" },
          { id: "formations/v7", title: "V7", file: "formations/v7.md" },
          { id: "formations/v9", title: "V9", file: "formations/v9.md" },
          {
            id: "formations/inverted-v3",
            title: "Inverted V3",
            file: "formations/inverted-v3.md",
          },
          {
            id: "formations/inverted-v5",
            title: "Inverted V5",
            file: "formations/inverted-v5.md",
          },
          {
            id: "formations/inverted-v7",
            title: "Inverted V7",
            file: "formations/inverted-v7.md",
          },
          { id: "formations/x5", title: "X5", file: "formations/x5.md" },
          { id: "formations/x9", title: "X9", file: "formations/x9.md" },
          {
            id: "formations/triangle6",
            title: "Triangle6",
            file: "formations/triangle6.md",
          },
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
          {
            id: "formations/vertical",
            title: "Vertical",
            file: "formations/vertical.md",
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
    group: true,
    title: "함선 · 무기 모듈",
    hint: "목록을 누르면 하위가 열린다",
    children: [
      {
        id: "ship-modules",
        title: "함선 모듈",
        desc: "시설 효과 13종",
        file: "ship-modules/index.md",
        children: [
          {
            id: "ship-modules/weapon-room",
            title: "무기실",
            file: "ship-modules/weapon-room.md",
          },
          {
            id: "ship-modules/reactor",
            title: "동력로",
            file: "ship-modules/reactor.md",
          },
          {
            id: "ship-modules/engine",
            title: "엔진",
            file: "ship-modules/engine.md",
          },
          { id: "ship-modules/hull", title: "선체", file: "ship-modules/hull.md" },
          {
            id: "ship-modules/radar",
            title: "레이더",
            file: "ship-modules/radar.md",
          },
          {
            id: "ship-modules/shield",
            title: "실드",
            file: "ship-modules/shield.md",
          },
        ],
      },
      {
        id: "weapon-modules",
        title: "무기 모듈",
        desc: "획득 · 무기별 강화",
        file: "weapon-modules/index.md",
        children: [
          {
            id: "weapon-modules/blaster",
            title: "블래스터",
            file: "weapon-modules/blaster.md",
          },
          {
            id: "weapon-modules/laser",
            title: "레이저",
            file: "weapon-modules/laser.md",
          },
          {
            id: "weapon-modules/shotgun",
            title: "샷건",
            file: "weapon-modules/shotgun.md",
          },
          {
            id: "weapon-modules/aux-cannon",
            title: "보조 캐넌",
            file: "weapon-modules/aux-cannon.md",
          },
          {
            id: "weapon-modules/plasma-bomb",
            title: "플라즈마",
            file: "weapon-modules/plasma-bomb.md",
          },
          {
            id: "weapon-modules/homing-missile",
            title: "유도탄",
            file: "weapon-modules/homing-missile.md",
          },
          {
            id: "weapon-modules/orbital-barrier",
            title: "궤도 방벽",
            file: "weapon-modules/orbital-barrier.md",
          },
        ],
      },
    ],
  },
  {
    id: "augments",
    title: "오그먼트",
    desc: "풀 · 오퍼 · 트리거",
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

const REFERENCE_PAGES = [
  { id: "workflow", title: "작업 방식", file: "feature-workflow.md" },
  { id: "template", title: "기획서 양식", file: "template.md" },
  { id: "ideas", title: "증강 아이디어", file: "augment-todo.md" },
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
  REFERENCE_PAGES.forEach(add);
  // legacy hash #enemies used to mean enemies.md
  map.set("enemies-legacy", {
    id: "enemies-legacy",
    title: "적 (리다이렉트)",
    file: "enemies.md",
  });
  for (const page of [
    { id: "enemies/elite-fighter", file: "enemies/elite-fighter.md", title: "Elite Fighter (이동됨)" },
    { id: "enemies/elite-awl", file: "enemies/elite-awl.md", title: "Elite Awl (이동됨)" },
  ]) map.set(page.id, page);
  return map;
})();

const LAYER_CHIPS = [
  { id: "enemies", label: "일반 적" },
  { id: "elites", label: "엘리트" },
  { id: "bosses", label: "보스" },
  { id: "formations", label: "② 진형" },
  { id: "encounters", label: "③ Encounter" },
  { id: "ship-modules", label: "함선 모듈" },
  { id: "weapon-modules", label: "무기 모듈" },
  { id: "run-pacing", label: "페이싱" },
];

const navEl = document.getElementById("cat-nav");
const titleEl = document.getElementById("panel-title");
const pathEl = document.getElementById("panel-path");
const bodyEl = document.getElementById("panel-body");
const crumbEl = document.getElementById("panel-crumb");
const chipsEl = document.getElementById("layer-chips");

/** Manual expand overrides (id → true). Active-branch pages stay open anyway. */
const manualExpanded = new Set();

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
  if (!href || /^(?:https?:|mailto:)/.test(href)) return null;
  if (href.startsWith("#")) {
    const id = href.slice(1).replace(/\.md$/, "");
    return PAGES.has(id) ? id : null;
  }
  const base = new URL(PAGES.get(currentId)?.file || "overview.md", location.href);
  const resolved = new URL(href, base);
  for (const [id, page] of PAGES) {
    if (new URL(page.file, location.href).pathname === resolved.pathname) return id;
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

  const imageHtml = (alt, href) => {
    const base = new URL(PAGES.get(currentId)?.file || "overview.md", location.href);
    const safeSrc = escapeHtml(new URL(href, base).href);
    const safeAlt = escapeHtml(alt || "");
    const tint =
      /facility_/i.test(href) || /facility_/i.test(alt)
        ? " enemy-look--cyan"
        : /weapon_/i.test(href) || /weapon_/i.test(alt)
          ? " enemy-look--blue"
          : /interceptor/i.test(href) || /interceptor/i.test(alt)
            ? " enemy-look--orange"
            : /elite/i.test(href) || /elite/i.test(alt)
              ? " enemy-look--crimson"
              : " enemy-look--pink";
    return `<figure class="enemy-look${tint}"><img src="${safeSrc}" alt="${safeAlt}" loading="lazy" /></figure>`;
  };

  const inline = (text) => {
    let t = escapeHtml(text);
    t = t.replace(/`([^`]+)`/g, "<code>$1</code>");
    // Images before links so ![alt](url) is not treated as a link.
    t = t.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_, alt, href) => imageHtml(alt, href));
    t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) => {
      const route = resolveMdHref(href, currentId);
      if (route) {
        return `<a href="#${route}" data-spec-link="${route}">${label}</a>`;
      }
      const base = new URL(PAGES.get(currentId)?.file || 'overview.md', location.href);
      const safeHref = escapeHtml(new URL(href, base).href);
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
    const onlyImage = line.match(/^!\[([^\]]*)\]\(([^)]+)\)\s*$/);
    if (onlyImage) {
      html.push(imageHtml(onlyImage[1], onlyImage[2]));
      continue;
    }
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

function isTreeOpen(page, activeId) {
  if (!page.children?.length) return false;
  // A child route keeps ancestors open.
  if (activeId && activeId.startsWith(page.id + "/")) return true;
  return manualExpanded.has(page.id);
}

function makeBtn(page, activeId, depth) {
  const hasKids = Boolean(page.children?.length);
  const open = isTreeOpen(page, activeId);
  const btn = document.createElement("button");
  btn.type = "button";
  btn.className =
    "cat-btn" +
    (page.id === activeId ? " active" : "") +
    (depth ? ` depth-${depth}` : "") +
    (hasKids ? " has-children" : "") +
    (open ? " open" : "");
  btn.dataset.id = page.id;
  const desc = page.desc
    ? `<span class="cat-desc">${escapeHtml(page.desc)}</span>`
    : "";
  const caret = hasKids
    ? `<span class="nav-caret" aria-hidden="true">${open ? "▾" : "▸"}</span>`
    : `<span class="nav-caret-spacer" aria-hidden="true"></span>`;
  btn.innerHTML = `
    ${caret}
    <span class="cat-copy">
      <span class="cat-title">${escapeHtml(page.title)}</span>
      ${desc}
    </span>
  `;
  btn.addEventListener("click", () => {
    if (hasKids) {
      // Same parent again while already here → collapse. Otherwise expand.
      if (page.id === activeId && manualExpanded.has(page.id)) {
        manualExpanded.delete(page.id);
      } else {
        manualExpanded.add(page.id);
      }
    }
    selectPage(page.id, true);
  });
  return btn;
}

function appendNavTree(parentEl, page, activeId, depth) {
  parentEl.appendChild(makeBtn(page, activeId, depth));
  if (!page.children?.length || !isTreeOpen(page, activeId)) return;
  for (const child of page.children) {
    appendNavTree(parentEl, child, activeId, depth + 1);
  }
}

function renderNav(activeId) {
  navEl.innerHTML = "";
  const head = document.createElement("h2");
  head.textContent = "기획서";
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
        appendNavTree(wrap, child, activeId, 0);
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
  pathEl.textContent = `docs/design/${page.file}`;
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
