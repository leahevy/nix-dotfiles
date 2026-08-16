"use strict";

const log = document.getElementById("log");
const typing = document.getElementById("typing");
const form = document.getElementById("compose");
const input = document.getElementById("input");

let reactionButtons = [];
let botAvatar = null;
let botName = "";
let typingText = "the bot is typing";
let splash = null;
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

function removeSplash() {
  if (splash) {
    splash.remove();
    splash = null;
  }
}

function addMessage(event) {
  if (event.id != null) {
    if (seenIds.has(event.id)) return;
    seenIds.add(event.id);
  }
  removeSplash();
  const el = document.createElement("div");
  el.className =
    `msg ${event.role === "user" ? "user" : "bot"}` +
    (event.failed ? " failed" : "");
  if (event.id != null) el.dataset.id = event.id;
  let html = "";
  if (event.tsStr) {
    if (event.role !== "user" && botName) {
      html += `<div class="ts-row"><span class="bot-name">${escapeHtml(botName)}</span><span class="ts">${escapeHtml(event.tsStr)}</span></div>`;
    } else {
      html += `<div class="ts">${escapeHtml(event.tsStr)}</div>`;
    }
  }
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
      const row = btn.closest(".reactions");
      const nearBottom =
        log.scrollHeight - log.scrollTop - log.clientHeight < 40;
      row.classList.toggle("collapsed");
      if (!row.classList.contains("collapsed") && nearBottom) {
        log.scrollTop = log.scrollHeight;
      }
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
  typing.textContent = on ? `${typingText}...` : "";
}

function flashFailed(targetId) {
  const row = log.querySelector(`.reactions[data-target="${targetId}"]`);
  const bubble = row ? row.closest(".msg") : null;
  if (!bubble) return;
  bubble.classList.remove("flash-failed");
  void bubble.offsetWidth;
  bubble.classList.add("flash-failed");
  setTimeout(() => bubble.classList.remove("flash-failed"), 600);
}

function showReactionChip(targetId, emoji) {
  const msg = log.querySelector(`.msg[data-id="${targetId}"]`);
  if (!msg) return;
  let chip = msg.querySelector(".reaction-chip");
  if (!chip) {
    chip = document.createElement("div");
    chip.className = "reaction-chip";
    msg.appendChild(chip);
    msg.style.marginBottom = "14px";
  }
  chip.textContent = emoji;
  const reactions = msg.querySelector(".reactions");
  if (reactions) reactions.remove();
}

async function react(targetId, emoji) {
  try {
    const res = await fetch("/v1/chat/react", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ targetId, emoji }),
    });
    if (res.status === 401) { window.location.reload(); return; }
    if (res.ok) showReactionChip(targetId, emoji);
    else flashFailed(targetId);
  } catch (e) {
    console.error("reaction failed", e);
    flashFailed(targetId);
  }
}

async function send(message) {
  try {
    const res = await fetch("/v1/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
    });
    if (res.status === 401) { window.location.reload(); return; }
    if (!res.ok) addMessage({ role: "user", text: message, failed: true });
  } catch (e) {
    console.error("send failed", e);
    addMessage({ role: "user", text: message, failed: true });
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
    if (source.readyState === EventSource.CLOSED) {
      setTimeout(connect, 2000);
    }
  };
}

async function boot() {
  try {
    const res = await fetch("/v1/chat/config");
    if (res.status === 401) { window.location.reload(); return; }
    if (res.ok) {
      const cfg = await res.json();
      reactionButtons = cfg.reactionsEnabled ? cfg.emoji || [] : [];
      botAvatar = cfg.avatar ? "/v1/chat/avatar" : null;
      botName = cfg.title || "";
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
      if (cfg.typing) {
        typingText = cfg.typing;
      }
      const splashTitle = cfg.title || "";
      const splashAbout = cfg.about || "";
      if (splashTitle || splashAbout || cfg.avatar) {
        splash = document.createElement("div");
        splash.id = "splash";
        if (cfg.avatar) {
          const img = document.createElement("img");
          img.src = "/v1/chat/avatar";
          img.alt = splashTitle;
          splash.appendChild(img);
        }
        if (splashTitle) {
          const name = document.createElement("div");
          name.id = "splash-name";
          name.textContent = splashTitle;
          splash.appendChild(name);
        }
        if (splashAbout) {
          const about = document.createElement("div");
          about.id = "splash-about";
          about.textContent = splashAbout;
          splash.appendChild(about);
        }
        log.appendChild(splash);
      }
    }
  } catch (e) {
    console.error("config failed", e);
  }
  connect();
  input.focus();
}

boot();
