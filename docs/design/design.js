/**
 * Design (기획) browser — same UX as spec, files under docs/design/.
 */
const NAV = [
  {
    id: "vision",
    title: "방향",
    desc: "재미 · 런 목표",
    file: "vision.md",
  },
  {
    group: true,
    title: "콘텐츠",
    hint: "의도 · 역할",
    children: [
      {
        id: "enemies",
        title: "적",
        desc: "로스터 · 의도",
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
    ],
  },
  {
    group: true,
    title: "워크플로",
    hint: "개발·문서 위치",
    children: [
      {
        id: "workflow",
        title: "/feature · /push",
        desc: "문서 위치 포함",
        file: "feature-workflow.md",
      },
      {
        id: "systems",
        title: "기능 설계 목록",
        desc: "systems/ 인덱스",
        file: "systems/README.md",
      },
    ],
  },
];

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
  return map;
})();

const LAYER_CHIPS = [
  { id: "vision", label: "방향" },
  { id: "enemies", label: "적" },
  { id: "workflow", label: "워크플로" },
];

const DEFAULT_ID = "vision";

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
  if (!hash) return PAGES.get(DEFAULT_ID);
  if (PAGES.has(hash)) return PAGES.get(hash);
  const bare = hash.replace(/\.md$/, "");
  if (PAGES.has(bare)) return PAGES.get(bare);
  return PAGES.get(DEFAULT_ID);
}

function resolveMdHref(href, currentId) {
  if (!href) return null;
  if (href.startsWith("http://") || href.startsWith("https://")) return null;
  // Spec Pages deep link — leave as normal navigation
  if (href.includes("../spec/") || href.startsWith("/spec")) return null;
  if (href.startsWith("#")) {
    const id = href.slice(1).replace(/\.md$/, "");
    return PAGES.has(id) ? id : null;
  }
  if (href.endsWith(".md") || href.includes(".md#")) {
    const [pathPart] = href.split("#");
    const baseDir = (PAGES.get(currentId)?.file || "").replace(/[^/]+$/, "");
    let path = pathPart;
    if (path.startsWith("./")) path = path.slice(2);
    while (path.startsWith("../")) {
      path = path.slice(3);
    }
    const joined = (baseDir + path).replace(/\\/g, "/");
    const norm = joined.replace(/\/+/g, "/").replace(/\.md$/, "");
    for (const [id, page] of PAGES) {
      if (page.file?.replace(/\.md$/, "") === norm) return id;
      if (page.file === joined || page.file === path) return id;
    }
    const guess = path.replace(/\.md$/, "");
    if (PAGES.has(guess)) return guess;
    // enemies/index style
    if (path === "enemies/" || path === "enemies") return "enemies";
    if (guess.startsWith("enemies/")) {
      const id = guess;
      if (PAGES.has(id)) return id;
    }
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
        return `<a href="#${route}" data-doc-link="${route}">${label}</a>`;
      }
      // Pages spec deep links (HTML is always under /design/)
      let outHref = href;
      const specEnemy = href.match(/spec\/enemies\/([a-z0-9-]+)\.md/);
      if (specEnemy) outHref = `../spec/#enemies/${specEnemy[1]}`;
      else if (/spec\/encounters/.test(href)) outHref = "../spec/#encounters";
      else if (/spec\/enemies\/?$/.test(href) || /spec\/enemies\/index/.test(href))
        outHref = "../spec/#enemies";
      else if (href === "../spec/" || href === "../../spec/" || href.endsWith("/spec/"))
        outHref = "../spec/";
      else if (href.startsWith("../spec/#") || href.startsWith("../../spec/#"))
        outHref = href.replace(/^\.\.\/(\.\.\/)?spec\//, "../spec/");
      const safeHref = escapeHtml(outHref);
      const external =
        outHref.startsWith("http://") || outHref.startsWith("https://")
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
    (depth ? ` depth-${depth}` : "");
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
  head.textContent = "기획";
  navEl.appendChild(head);

  for (const entry of NAV) {
    if (entry.group) {
      const wrap = document.createElement("div");
      wrap.className = "nav-group";
      const label = document.createElement("div");
      label.className = "nav-group-label";
      label.innerHTML = `<span>${escapeHtml(entry.title)}</span>${
        entry.hint ? `<small>${escapeHtml(entry.hint)}</small>` : ""
      }`;
      wrap.appendChild(label);
      for (const child of entry.children) {
        wrap.appendChild(makeBtn(child, activeId, 0));
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
      bits.push(
        `<a href="#${acc}" data-doc-link="${acc}">${escapeHtml(label)}</a>`
      );
    } else {
      bits.push(`<span>${escapeHtml(label)}</span>`);
    }
  });
  crumbEl.innerHTML = bits.join(" <span class='crumb-sep'>/</span> ");
}

async function selectPage(id, pushHash) {
  const page = PAGES.get(id) || PAGES.get(DEFAULT_ID);
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
    document.querySelector(".spec-panel")?.scrollTo?.(0, 0);
  } catch (err) {
    bodyEl.innerHTML = `<p class="md-error">문서를 불러오지 못했습니다 (${escapeHtml(
      err.message
    )}).<br/>로컬에서는 <code>docs</code>에서 HTTP 서버로 열어 주세요.</p>`;
  }
}

bodyEl.addEventListener("click", (e) => {
  const a = e.target.closest("a[data-doc-link]");
  if (!a) return;
  e.preventDefault();
  selectPage(a.getAttribute("data-doc-link"), true);
});

crumbEl?.addEventListener("click", (e) => {
  const a = e.target.closest("a[data-doc-link]");
  if (!a) return;
  e.preventDefault();
  selectPage(a.getAttribute("data-doc-link"), true);
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
