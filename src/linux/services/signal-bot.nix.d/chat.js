"use strict";

const log = document.getElementById("log");
const typing = document.getElementById("typing");
const form = document.getElementById("compose");
const input = document.getElementById("input");

let reactionButtons = [];
let botAvatar = null;
const messagesById = new Map();
const seenIds = new Set();

const ESCAPABLE = "*_~`|#\\";

function escapeHtml(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

const INLINE_MARKERS = [
  ["**", "b", false],
  ["__", "b", false],
  ["~~", "s", false],
  ["||", "spoiler", false],
  ["`", "code", true],
  ["*", "i", false],
  ["_", "i", false],
];

function renderInline(text) {
  let out = "";
  let i = 0;
  while (i < text.length) {
    const ch = text[i];
    if (ch === "\\" && i + 1 < text.length && ESCAPABLE.includes(text[i + 1])) {
      out += escapeHtml(text[i + 1]);
      i += 2;
      continue;
    }
    let matched = false;
    for (const [marker, tag, literal] of INLINE_MARKERS) {
      if (!text.startsWith(marker, i)) continue;
      const stop = text.indexOf(marker, i + marker.length);
      if (stop < 0) continue;
      const inner = text.slice(i + marker.length, stop);
      const body = literal ? escapeHtml(inner) : renderInline(inner);
      if (tag === "spoiler") {
        out += `<span class="spoiler">${body}</span>`;
      } else {
        out += `<${tag}>${body}</${tag}>`;
      }
      i = stop + marker.length;
      matched = true;
      break;
    }
    if (matched) continue;
    out += escapeHtml(ch);
    i += 1;
  }
  return out;
}

function renderMarkdown(text) {
  const lines = text.split("\n");
  const parts = [];
  let i = 0;
  let paragraph = [];

  function flush() {
    if (paragraph.length) {
      parts.push(paragraph.map(renderInline).join("<br>"));
      paragraph = [];
    }
  }

  while (i < lines.length) {
    const line = lines[i];
    if (line.startsWith("```")) {
      flush();
      const block = [];
      i += 1;
      while (i < lines.length && !lines[i].startsWith("```")) {
        block.push(lines[i]);
        i += 1;
      }
      i += 1;
      parts.push(`<pre>${escapeHtml(block.join("\n"))}</pre>`);
      continue;
    }
    const heading = /^(#{1,6})\s+(.*)$/.exec(line);
    if (heading) {
      flush();
      parts.push(`<b>${renderInline(heading[2])}</b>`);
      i += 1;
      continue;
    }
    paragraph.push(line);
    i += 1;
  }
  flush();
  return parts.join("<br>");
}

function bindSpoilers(node) {
  node.querySelectorAll(".spoiler").forEach((el) => {
    el.addEventListener("click", () => el.classList.add("revealed"));
  });
}

function reactionRow(id) {
  if (!reactionButtons.length) return "";
  const buttons = reactionButtons
    .map(
      (r) =>
        `<button data-emoji="${escapeHtml(r.emoji)}" title="${escapeHtml(
          r.meaning
        )}">${escapeHtml(r.emoji)}</button>`
    )
    .join("");
  return (
    `<div class="reactions collapsed" data-target="${id}">` +
    `<button class="opener" type="button" title="React" aria-label="React">+</button>` +
    `<div class="react-buttons">${buttons}</div></div>`
  );
}

function addMessage(event) {
  if (event.id != null) {
    if (seenIds.has(event.id)) return;
    seenIds.add(event.id);
  }
  const el = document.createElement("div");
  el.className = `msg ${event.role === "user" ? "user" : "bot"}`;
  let html = "";
  if (event.quoteId != null && messagesById.has(event.quoteId)) {
    const quoted = messagesById.get(event.quoteId);
    html += `<div class="quote">${escapeHtml(quoted.slice(0, 200))}</div>`;
  }
  if (event.title) {
    html += `<b>${renderInline(event.title)}</b><br>`;
  }
  html += renderMarkdown(event.text || "");
  if (event.url) {
    const safe = escapeHtml(event.url);
    html += `<br><a href="${safe}" target="_blank" rel="noopener">${safe}</a>`;
  }
  if (event.reactable) {
    html += reactionRow(event.id);
  }
  el.innerHTML = html;
  bindSpoilers(el);
  el.querySelectorAll(".reactions .opener").forEach((btn) => {
    btn.addEventListener("click", () => {
      btn.closest(".reactions").classList.toggle("collapsed");
    });
  });
  el.querySelectorAll(".reactions .react-buttons button").forEach((btn) => {
    btn.addEventListener("click", () => {
      react(event.id, btn.dataset.emoji);
      const row = btn.closest(".reactions");
      if (row) row.classList.add("collapsed");
    });
  });
  messagesById.set(event.id, event.text || "");
  if (event.role !== "user" && botAvatar) {
    const row = document.createElement("div");
    row.className = "row bot";
    const img = document.createElement("img");
    img.className = "avatar";
    img.alt = "";
    img.onload = () => {
      if (log.scrollHeight - log.scrollTop - log.clientHeight < 40) {
        log.scrollTop = log.scrollHeight;
      }
    };
    img.src = botAvatar;
    row.appendChild(img);
    row.appendChild(el);
    log.appendChild(row);
  } else {
    log.appendChild(el);
  }
  log.scrollTop = log.scrollHeight;
}

function setTyping(on) {
  typing.textContent = on ? "the bot is typing..." : "";
}

async function react(targetId, emoji) {
  try {
    await fetch("/v1/chat/react", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ targetId, emoji }),
    });
  } catch (e) {
    console.error("reaction failed", e);
  }
}

async function send(message) {
  try {
    await fetch("/v1/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
    });
  } catch (e) {
    console.error("send failed", e);
  }
}

form.addEventListener("submit", (e) => {
  e.preventDefault();
  const text = input.value.trim();
  input.value = "";
  input.focus();
  if (!text) return;
  send(text);
});

input.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    form.requestSubmit();
  }
});

document.addEventListener("keydown", (e) => {
  if (e.target === input) return;
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  if (e.key.length === 1 || e.key === "Enter" || e.key === "Backspace") {
    input.focus();
  }
});

function connect() {
  const source = new EventSource("/v1/chat/stream");
  source.onmessage = (e) => {
    let event;
    try {
      event = JSON.parse(e.data);
    } catch (err) {
      return;
    }
    if (event.kind === "message") {
      addMessage(event);
    } else if (event.kind === "typing") {
      setTyping(!!event.on);
    }
  };
  source.onerror = () => {
    setTyping(false);
  };
}

async function boot() {
  try {
    const res = await fetch("/v1/chat/config");
    if (res.ok) {
      const cfg = await res.json();
      reactionButtons = cfg.reactionsEnabled ? cfg.emoji || [] : [];
      botAvatar = cfg.avatar ? "/v1/chat/avatar" : null;
      if (cfg.title) {
        document.title = cfg.title;
      }
      const root = document.documentElement.style;
      if (cfg.fontSize) {
        root.setProperty("--font-size", `${cfg.fontSize}px`);
      }
      if (cfg.fontFamily) {
        root.setProperty("--font-family", cfg.fontFamily);
      }
    }
  } catch (e) {
    console.error("config failed", e);
  }
  connect();
  input.focus();
}

boot();
