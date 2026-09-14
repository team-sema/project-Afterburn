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
            title: "Elite Fighter",
            file: "enemies/elite-fighter.md",
          },
          { id: "enemies/elite-awl", title: "Elite Awl", file: "enemies/elite-awl.md" },
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

NAV.push({ group: true, title: "작업·기록", children: [
  { id: "workflow", title: "작업 방식", file: "feature-workflow.md" },
  { id: "template", title: "기획서 양식", file: "template.md" },
  { id: "ideas", title: "증강 아이디어", file: "augment-todo.md" },
  { id: "tasks", title: "작업 체크리스트", file: "tasks/README.md" },
  { id: "history", title: "과거 변경 이력", file: "history/README.md" }
] });
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
  for (const page of [{"id":"tasks/weapon-augment-acquisition-tasks","file":"tasks/weapon-augment-acquisition-tasks.md","title":"Tasks: weapon-augment-acquisition"},{"id":"tasks/augment-selection-carousel-tasks","file":"tasks/augment-selection-carousel-tasks.md","title":"Tasks: augment-selection-carousel"},{"id":"tasks/bomb-proximity-fuse-tasks","file":"tasks/bomb-proximity-fuse-tasks.md","title":"Tasks: bomb-proximity-fuse"},{"id":"tasks/facility-own-effects-tasks","file":"tasks/facility-own-effects-tasks.md","title":"Tasks: facility-own-effects"},{"id":"tasks/orbital-barrier-one-hit-tasks","file":"tasks/orbital-barrier-one-hit-tasks.md","title":"Tasks: orbital-barrier-one-hit"},{"id":"tasks/offer-category-mix-tasks","file":"tasks/offer-category-mix-tasks.md","title":"Tasks: offer-category-mix"},{"id":"tasks/weapon-replace-delete-reroll-tasks","file":"tasks/weapon-replace-delete-reroll-tasks.md","title":"Tasks: weapon-replace-delete-reroll"},{"id":"tasks/readme-docs-links-tasks","file":"tasks/readme-docs-links-tasks.md","title":"Task: README에 스펙·칸반 링크"},{"id":"tasks/fix-formation-viewport-before-tree-tasks","file":"tasks/fix-formation-viewport-before-tree-tasks.md","title":"Tasks — fix-formation-viewport-before-tree"},{"id":"tasks/tanker-hit-feedback-tasks","file":"tasks/tanker-hit-feedback-tasks.md","title":"tanker-hit-feedback tasks"},{"id":"tasks/unified-weapon-system-tasks","file":"tasks/unified-weapon-system-tasks.md","title":"Tasks: unified-weapon-system"},{"id":"tasks/docs-site-kanban-tasks","file":"tasks/docs-site-kanban-tasks.md","title":"Task: docs 사이트 · 칸반 · 워크플로 이식"},{"id":"tasks/early-game-pacing-tasks","file":"tasks/early-game-pacing-tasks.md","title":"Tasks: early-game-pacing"},{"id":"tasks/weapon-status-focus-detail-tasks","file":"tasks/weapon-status-focus-detail-tasks.md","title":"Tasks — weapon-status-focus-detail"},{"id":"tasks/early-enemy-fire-tuning-tasks","file":"tasks/early-enemy-fire-tuning-tasks.md","title":"Tasks — early-enemy-fire-tuning"},{"id":"tasks/weapon-stats-spec-only-tasks","file":"tasks/weapon-stats-spec-only-tasks.md","title":"Tasks: weapon-stats-spec-only"},{"id":"tasks/submission-copy-ko-tasks","file":"tasks/submission-copy-ko-tasks.md","title":"submission-copy-ko Task"},{"id":"tasks/submission-ai-usage-copy-tasks","file":"tasks/submission-ai-usage-copy-tasks.md","title":"submission-ai-usage-copy Task"},{"id":"tasks/laser-refraction-vfx-tasks","file":"tasks/laser-refraction-vfx-tasks.md","title":"Tasks: laser-refraction-vfx"},{"id":"tasks/weapon-module-levels-tasks","file":"tasks/weapon-module-levels-tasks.md","title":"Tasks: weapon-module-levels"},{"id":"tasks/bomb-formation-escorts-tasks","file":"tasks/bomb-formation-escorts-tasks.md","title":"bomb-formation-escorts tasks"},{"id":"tasks/striker-drone-diamond-tasks","file":"tasks/striker-drone-diamond-tasks.md","title":"Tasks: striker-drone-diamond"},{"id":"tasks/diamond-formation-sizes-tasks","file":"tasks/diamond-formation-sizes-tasks.md","title":"diamond-formation-sizes tasks"},{"id":"tasks/shield-regen-tasks","file":"tasks/shield-regen-tasks.md","title":"Tasks: shield-regen"},{"id":"tasks/docs-consistency-audit-tasks","file":"tasks/docs-consistency-audit-tasks.md","title":"docs-consistency-audit Task"},{"id":"tasks/elite-combat-patterns-tasks","file":"tasks/elite-combat-patterns-tasks.md","title":"엘리트 전투 패턴 개선 AC"},{"id":"tasks/augment-test-lab-tasks","file":"tasks/augment-test-lab-tasks.md","title":"통합 증강 테스트 랩 Tasks"},{"id":"tasks/player-augment-tiers-tasks","file":"tasks/player-augment-tiers-tasks.md","title":"Tasks: player-augment-tiers"},{"id":"tasks/support-cannon-drones-tasks","file":"tasks/support-cannon-drones-tasks.md","title":"보조 캐넌 옵션 드론 Task"},{"id":"tasks/sniper-enemy-tasks","file":"tasks/sniper-enemy-tasks.md","title":"Sniper Enemy Tasks"},{"id":"tasks/threat-elite-progression-tasks","file":"tasks/threat-elite-progression-tasks.md","title":"threat-elite-progression tasks"},{"id":"tasks/spec-enemy-hierarchy-tasks","file":"tasks/spec-enemy-hierarchy-tasks.md","title":"Tasks: spec-enemy-hierarchy"},{"id":"tasks/kanban-manual-cards-tasks","file":"tasks/kanban-manual-cards-tasks.md","title":"Tasks: kanban-manual-cards"},{"id":"tasks/unified-module-slots-tasks","file":"tasks/unified-module-slots-tasks.md","title":"Tasks: unified-module-slots"},{"id":"tasks/notion-kanban-skills-tasks","file":"tasks/notion-kanban-skills-tasks.md","title":"Tasks: notion-kanban-skills"},{"id":"tasks/shield-base-one-tasks","file":"tasks/shield-base-one-tasks.md","title":"Tasks: shield-base-one"},{"id":"tasks/status-ui-templates-tasks","file":"tasks/status-ui-templates-tasks.md","title":"Tasks: status-ui-templates"},{"id":"history/submission-copy-ko","file":"history/submission-copy-ko.md","title":"제출 문서 한국어 카피 정리"},{"id":"history/readme-docs-links","file":"history/readme-docs-links.md","title":"Feature: README에 스펙·칸반 링크"},{"id":"history/shield-regen","file":"history/shield-regen.md","title":"Feature: 실드 재생 · 충전 UI"},{"id":"history/augment-module-slots","file":"history/augment-module-slots.md","title":"Feature: 증강 모듈 슬롯"},{"id":"history/tanker-hit-feedback","file":"history/tanker-hit-feedback.md","title":"Tanker 피격 피드백 강화"},{"id":"history/weapon-augment-acquisition","file":"history/weapon-augment-acquisition.md","title":"Feature: 무기 증강 획득 · 필드 드롭 제거"},{"id":"history/kanban-manual-cards","file":"history/kanban-manual-cards.md","title":"Feature: 칸반 카드 수동 관리"},{"id":"history/offer-category-mix","file":"history/offer-category-mix.md","title":"오퍼 범주 혼합 (획득 / 모듈 / 시설)"},{"id":"history/status-ui-templates","file":"history/status-ui-templates.md","title":"Feature: STATUS HUD UI 템플릿 플레이스홀더"},{"id":"history/early-enemy-fire-tuning","file":"history/early-enemy-fire-tuning.md","title":"초반 적 사격 완화"},{"id":"history/facility-weapon-modules","file":"history/facility-weapon-modules.md","title":"시설 모듈 효과 (FacilityModuleEffect)"},{"id":"history/kanban-v2","file":"history/kanban-v2.md","title":"백로그 칸반 (v2)"},{"id":"history/unified-weapon-system","file":"history/unified-weapon-system.md","title":"Feature: 통합 무기 시스템"},{"id":"history/early-game-pacing","file":"history/early-game-pacing.md","title":"Feature: 초반 페이싱 조정"},{"id":"history/augment-selection-carousel","file":"history/augment-selection-carousel.md","title":"Feature: 증강 선택 캐러셀 UI"},{"id":"history/bomb-formation-escorts","file":"history/bomb-formation-escorts.md","title":"Bomb 편대 호위"},{"id":"history/weapon-status-focus-detail","file":"history/weapon-status-focus-detail.md","title":"Feature: 무기 STATUS 포커스 디테일"},{"id":"history/augment-test-lab","file":"history/augment-test-lab.md","title":"통합 증강 테스트 랩"},{"id":"history/striker-drone-diamond","file":"history/striker-drone-diamond.md","title":"Striker 드론 호위 마름모"},{"id":"history/shield-base-one","file":"history/shield-base-one.md","title":"Feature: 시작 실드 1"},{"id":"history/weapon-stats-spec-only","file":"history/weapon-stats-spec-only.md","title":"Feature: 무기 수치는 스펙만"},{"id":"history/bomb-proximity-fuse","file":"history/bomb-proximity-fuse.md","title":"Feature: 폭탄 근접 자폭"},{"id":"history/submission-ai-usage-copy","file":"history/submission-ai-usage-copy.md","title":"제출 AI 활용 문서 퇴고"},{"id":"history/notion-kanban-skills","file":"history/notion-kanban-skills.md","title":"Feature: Notion 칸반 스킬 연동"},{"id":"history/orbital-barrier-one-hit","file":"history/orbital-barrier-one-hit.md","title":"Feature: 궤도 방벽 적당 1회 피해"},{"id":"history/weapon-module-levels","file":"history/weapon-module-levels.md","title":"Feature: 무기 모듈 레벨 개편"},{"id":"history/laser-refraction-vfx","file":"history/laser-refraction-vfx.md","title":"Feature: 레이저 굴절빔 VFX"},{"id":"history/unified-module-slots","file":"history/unified-module-slots.md","title":"Feature: 범용 모듈 슬롯 통합"},{"id":"history/threat-elite-boss-loop","file":"history/threat-elite-boss-loop.md","title":"Threat 엘리트 · 보스 진행 루프 (초안)"},{"id":"history/fix-formation-viewport-before-tree","file":"history/fix-formation-viewport-before-tree.md","title":"Drone 편대 viewport 트리 가드"},{"id":"history/elite-combat-patterns","file":"history/elite-combat-patterns.md","title":"엘리트 전투 패턴 개선"},{"id":"history/weapon-replace-delete-reroll","file":"history/weapon-replace-delete-reroll.md","title":"Feature: 무기 교체 삭제 · 증강 리롤"},{"id":"history/sniper-enemy","file":"history/sniper-enemy.md","title":"Sniper 저격 적기"},{"id":"history/kanban-agent-prompt-copy","file":"history/kanban-agent-prompt-copy.md","title":"칸반 에이전트 프롬프트 복사"},{"id":"history/spec-enemy-hierarchy","file":"history/spec-enemy-hierarchy.md","title":"Feature: 적·진형·Encounter 스펙 계층 + Pages 가시성"},{"id":"history/diamond-formation-sizes","file":"history/diamond-formation-sizes.md","title":"다이아몬드 편대 크기 (5 / 13)"},{"id":"history/facility-own-effects","file":"history/facility-own-effects.md","title":"Feature: 시설이 효과 담당 (스탯 모듈 제거)"},{"id":"history/docs-site-kanban","file":"history/docs-site-kanban.md","title":"Feature: docs 사이트 · 칸반 · 워크플로 이식"},{"id":"history/docs-consistency-audit","file":"history/docs-consistency-audit.md","title":"문서 정합성 감사"},{"id":"history/player-augment-tiers","file":"history/player-augment-tiers.md","title":"플레이어 증강 티어 기반"},{"id":"history/support-cannon-drones","file":"history/support-cannon-drones.md","title":"보조 캐넌 옵션 드론"},{"id":"tasks/unify-design-docs-tasks","file":"tasks/unify-design-docs-tasks.md","title":"기획 문서 통합 작업"}]) map.set(page.id, page);
  map.set('systems', { id: 'history', title: '과거 변경 이력', file: 'history/README.md' });
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

  const inline = (text) => {
    let t = escapeHtml(text);
    t = t.replace(/`([^`]+)`/g, "<code>$1</code>");
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
