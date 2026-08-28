import collections
import contextlib
import datetime
import json
import sys
import threading
import time
from queue import Empty, Full, Queue

_STREAM_CLOSED = object()


class ChatHub:
    def __init__(self, ring_size, ttl_seconds, max_connections):
        self.ring_size = ring_size
        self.ttl_seconds = ttl_seconds
        self.max_connections = max_connections
        self.lock = threading.Lock()
        self.subscribers = {}
        self.rings = {}

    def publish(self, user, event, store=True):
        with self.lock:
            if store:
                ring = self.rings.setdefault(
                    user, collections.deque(maxlen=self.ring_size)
                )
                ring.append((time.time(), event))
            targets = list(self.subscribers.get(user, ()))
        for q in targets:
            with contextlib.suppress(Full):
                q.put_nowait(event)

    def subscribe(self, user):
        q = Queue(maxsize=100)
        cutoff = time.time() - self.ttl_seconds
        evicted = []
        with self.lock:
            raw = self.rings.get(user, ())
            backlog = [ev for ts, ev in raw if ts >= cutoff]
            subs = self.subscribers.setdefault(user, [])
            subs.append(q)
            while len(subs) > self.max_connections:
                evicted.append(subs.pop(0))
        for old in evicted:
            with contextlib.suppress(Full):
                old.put_nowait(_STREAM_CLOSED)
        return q, backlog

    def unsubscribe(self, user, q):
        with self.lock:
            subs = self.subscribers.get(user)
            if subs:
                with contextlib.suppress(ValueError):
                    subs.remove(q)
                if not subs:
                    del self.subscribers[user]


class DesktopReactables:
    def __init__(self, max_age):
        self.max_age = max_age
        self.lock = threading.Lock()
        self.entries = {}

    def remember(self, user, message_id, conversation_id, text):
        if message_id is None or not text:
            return
        with self.lock:
            self.entries[(user, message_id)] = (
                conversation_id,
                text,
                time.monotonic(),
            )

    def claim(self, user, message_id):
        with self.lock:
            entry = self.entries.pop((user, message_id), None)
        if entry is None:
            return None
        conversation_id, text, stamped = entry
        if time.monotonic() - stamped > self.max_age:
            return None
        return conversation_id, text


class DesktopThreads:
    def __init__(self, path, session_seconds, read_state, write_state, log_error):
        self.path = path
        self.session_seconds = session_seconds
        self.write_state = write_state
        self.log_error = log_error
        self.lock = threading.Lock()
        stored = read_state(path)
        self.threads = stored if isinstance(stored, dict) else {}

    def resolve(self, user):
        with self.lock:
            entry = self.threads.get(user)
            if not isinstance(entry, dict):
                return None
            conversation_id = entry.get("id")
            seen = entry.get("seen", 0)
            if not isinstance(conversation_id, str):
                return None
            if not isinstance(seen, (int, float)):
                return None
            if time.time() - seen > self.session_seconds:
                return None
            return conversation_id

    def remember(self, user, conversation_id):
        if conversation_id is None:
            return
        with self.lock:
            self.threads[user] = {"id": conversation_id, "seen": time.time()}
            try:
                self.write_state(self.path, self.threads)
            except OSError as e:
                self.log_error(
                    f"signal-bot: could not persist the desktop chat threads: {e}"
                )


class DesktopTranscripts:
    def __init__(self, max_messages, follow_up_window):
        self.max_messages = max_messages
        self.follow_up_window = follow_up_window
        self.lock = threading.Lock()
        self.threads = {}

    def _live(self, user):
        entry = self.threads.get(user)
        if entry is None:
            return None
        if time.monotonic() - entry["seen"] > self.follow_up_window():
            del self.threads[user]
            return None
        return entry

    def _touch(self, user):
        entry = self.threads.get(user)
        if entry is None:
            entry = {"seen": 0.0, "recap": False, "log": [], "pending": []}
            self.threads[user] = entry
        entry["seen"] = time.monotonic()
        return entry

    def _prune(self):
        now = time.monotonic()
        window = self.follow_up_window()
        expired = [
            user for user, entry in self.threads.items() if now - entry["seen"] > window
        ]
        for user in expired:
            del self.threads[user]

    def remember_turn(self, user, author, text, pending=False):
        if not text:
            return
        with self.lock:
            entry = self._touch(user)
            entry["log"].append((author, text))
            del entry["log"][: -self.max_messages]
            if pending:
                entry["pending"].append((author, text))
                del entry["pending"][: -self.max_messages]
            self._prune()

    def transcript(self, user):
        with self.lock:
            entry = self._live(user)
            return list(entry["log"]) if entry else []

    def pending_turns(self, user):
        with self.lock:
            entry = self._live(user)
            return list(entry["pending"]) if entry else []

    def needs_recap(self, user):
        with self.lock:
            entry = self._live(user)
            return bool(entry and entry["recap"])

    def mark_recap(self, user, recap_sent=False, drift=False):
        with self.lock:
            entry = self._live(user)
            if entry is None:
                return
            if recap_sent:
                entry["recap"] = False
                entry["pending"].clear()
            elif drift:
                entry["recap"] = True
            self._prune()


class DesktopChannel:
    def __init__(self, brain):
        self.brain = brain
        cfg = brain.cfg
        self.cfg = cfg
        self.recipients = cfg.get("chat_recipients") or {}
        self.default_recipient = cfg.get("chat_default_recipient")
        ttl_hours = cfg["chat_ring_buffer_ttl_hours"]
        self.ts_format = cfg["chat_timestamp_format"]
        self.hub = ChatHub(
            cfg["chat_ring_buffer_size"],
            ttl_hours * 3600,
            cfg.get("chat_max_stream_connections") or 3,
        )
        self.reactables = DesktopReactables(
            brain.reactions_config["target_max_age_seconds"]
        )
        self.threads = DesktopThreads(
            cfg["chat_threads_file"],
            brain.ha_session_seconds,
            brain.read_json_state,
            brain.write_json_state,
            brain.log_error,
        )
        self.transcripts = DesktopTranscripts(
            brain.context_max_messages, brain.follow_up_window
        )
        self.id_lock = threading.Lock()
        self.id_counter = int(time.time() * 1000)

    def next_id(self):
        with self.id_lock:
            self.id_counter += 1
            return self.id_counter

    def speaker_label(self, user):
        for name, oauth_user in self.recipients.items():
            if oauth_user == user:
                return name
        return self.default_recipient or user

    def publish_message(
        self, user, role, text, reactable=False, title="", url="", quote_id=None
    ):
        event_id = self.next_id()
        ts_str = datetime.datetime.now().strftime(self.ts_format)
        self.hub.publish(
            user,
            {
                "kind": "message",
                "id": event_id,
                "role": role,
                "text": text,
                "reactable": bool(reactable),
                "title": title,
                "url": url,
                "quoteId": quote_id,
                "tsStr": ts_str,
            },
        )
        return event_id

    def reaction_buttons(self):
        buttons = []
        for entry in self.brain.reactions_config["emoji"].values():
            emoji = entry.get("emoji") or []
            if emoji:
                buttons.append({"emoji": emoji[0], "meaning": entry.get("meaning", "")})
        return buttons

    def deliver(self, recipient_name, message, title, url):
        name = recipient_name or self.default_recipient
        user = self.recipients.get(name) if name else None
        if not user:
            return False
        bot_id = self.publish_message(
            user,
            "bot",
            message,
            reactable=self.brain.reactions_enabled,
            title=title,
            url=url,
        )
        self.reactables.remember(user, bot_id, None, message)
        self.transcripts.remember_turn(
            user, self.brain.bot_label, message, pending=True
        )
        return True

    def register(self, app, jsonify, request):
        brain = self.brain
        cfg = self.cfg
        hub = self.hub

        def chat_user():
            return request.headers.get("X-Auth-Request-User") or None

        chat_page_raw = brain.read_secret(cfg["chat_page_file"])
        chat_theme = brain.read_secret(cfg["chat_theme_file"])
        chat_page = chat_page_raw.replace(
            "</style>", "\n" + chat_theme + "\n</style>", 1
        )
        chat_script = brain.read_secret(cfg["chat_script_file"])

        avatar_mimes = {
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "webp": "image/webp",
        }
        avatar_bytes = None
        avatar_mime = None
        avatar_path = cfg.get("profile_avatar")
        if avatar_path:
            try:
                with open(avatar_path, "rb") as fh:
                    avatar_bytes = fh.read()
                ext = avatar_path.rsplit(".", 1)[-1].lower()
                avatar_mime = avatar_mimes.get(ext, "application/octet-stream")
            except OSError as e:
                avatar_bytes = None
                brain.log_error(
                    f"signal-bot: could not read the desktop chat avatar: {e}"
                )

        @app.route("/")
        @app.route("/chat")
        def http_chat_page():
            if not chat_user():
                return jsonify(error="unauthorized"), 401
            return app.response_class(chat_page, mimetype="text/html")

        @app.route("/chat.js")
        def http_chat_script():
            if not chat_user():
                return jsonify(error="unauthorized"), 401
            return app.response_class(chat_script, mimetype="text/javascript")

        @app.route("/v1/chat/whoami")
        def http_chat_whoami():
            return jsonify(user=chat_user())

        @app.route("/v1/chat/config")
        def http_chat_config():
            if not chat_user():
                return jsonify(error="unauthorized"), 401
            return jsonify(
                reactionsEnabled=brain.reactions_enabled,
                emoji=self.reaction_buttons(),
                title=cfg.get("profile_given_name") or "Signal Chat",
                about=cfg.get("profile_about") or "",
                fontSize=cfg["chat_font_size"],
                fontFamily=cfg["chat_font_family"],
                typing=cfg.get("chat_typing_text") or "",
                avatar=avatar_bytes is not None,
            )

        @app.route("/v1/chat/avatar")
        def http_chat_avatar():
            if not chat_user():
                return jsonify(error="unauthorized"), 401
            if avatar_bytes is None:
                return jsonify(error="no avatar set"), 404
            return app.response_class(avatar_bytes, mimetype=avatar_mime)

        @app.route("/v1/chat", methods=["POST"])
        def http_chat():
            user = chat_user()
            if not user:
                return jsonify(error="unauthorized"), 401
            body = request.get_json(silent=True) or {}
            text = body.get("message")
            if not isinstance(text, str) or not text.strip():
                return jsonify(error="message must be a non empty string"), 400
            text = text.strip()
            self.publish_message(user, "user", text)

            def work():
                try:
                    if not brain.is_known_desktop_user(user):
                        return
                    is_builtin = brain.is_builtin_command(text)
                    if not is_builtin:
                        print("signal-bot: handling a desktop message", file=sys.stderr)
                    budget_key = None
                    if not is_builtin:
                        brain.memory_record(
                            f"desktop:{user}", self.speaker_label(user), text
                        )
                        if brain.daily_transcript_record:
                            brain.daily_transcript_record(
                                self.speaker_label(user),
                                text,
                                is_bot=False,
                                key=f"desktop:{user}",
                            )
                        budget_key = brain.budget_key_for(user)
                        if budget_key is not None:
                            granted, _ = brain.budget.claim(
                                budget_key, text, notify=False
                            )
                            if not granted:
                                self.publish_message(
                                    user, "bot", brain.budget_exhausted
                                )
                                return
                    hub.publish(
                        user,
                        {"kind": "typing", "role": "bot", "on": True},
                        store=False,
                    )
                    try:
                        reply, script_turn = brain.command_reply(
                            text, is_admin=brain.is_desktop_admin(user)
                        )
                        if reply is brain.silent_drop:
                            return
                        if reply is not None:
                            new_id = None
                            if script_turn is not None:
                                self.transcripts.remember_turn(
                                    user,
                                    self.speaker_label(user),
                                    script_turn,
                                    pending=True,
                                )
                                if isinstance(reply, str):
                                    self.transcripts.remember_turn(
                                        user, brain.bot_label, reply, pending=True
                                    )
                                    brain.memory_record(
                                        f"desktop:{user}", brain.bot_label, reply
                                    )
                        else:
                            cs = brain.is_conversational_script(text)
                            if cs is not None:
                                command_name, script_command, command_argument = cs
                                entries = self.transcripts.transcript(user)
                                recap = brain.render_recap(
                                    self.cfg, entries, brain.context_max_chars
                                )
                                sender_argument = brain.with_desktop_sender(
                                    self.speaker_label(user), command_argument
                                )
                                prompt = (
                                    brain.with_context_recap(
                                        self.cfg, recap, sender_argument
                                    )
                                    if recap
                                    else sender_argument
                                )
                                self.transcripts.remember_turn(
                                    user, self.speaker_label(user), text, pending=True
                                )
                                prompt = f"{brain.context_prefix()}\n\n{prompt}"
                                reply, script_ok = brain.call_script(
                                    command_name, script_command, prompt
                                )
                                new_id = None
                                if script_ok and isinstance(reply, str):
                                    self.transcripts.remember_turn(
                                        user, brain.bot_label, reply, pending=True
                                    )
                                    brain.memory_record(
                                        f"desktop:{user}", brain.bot_label, reply
                                    )
                            else:
                                conversation_id = self.threads.resolve(user)
                                if (
                                    conversation_id is None
                                    or self.transcripts.needs_recap(user)
                                ):
                                    entries = self.transcripts.transcript(user)
                                else:
                                    entries = self.transcripts.pending_turns(user)
                                recap = brain.render_recap(
                                    self.cfg, entries, brain.context_max_chars
                                )
                                sender_text = brain.with_desktop_sender(
                                    self.speaker_label(user), text
                                )
                                prompt = (
                                    brain.with_context_recap(
                                        self.cfg, recap, sender_text
                                    )
                                    if recap
                                    else sender_text
                                )
                                self.transcripts.remember_turn(
                                    user, self.speaker_label(user), text
                                )
                                if conversation_id is None:
                                    prompt = f"{brain.context_prefix()}\n\n{prompt}"
                                reply, new_id = brain.call_ha_conversation(
                                    prompt, conversation_id
                                )
                                delivered = new_id is not None
                                drift = bool(
                                    conversation_id
                                    and new_id
                                    and new_id != conversation_id
                                )
                                self.transcripts.mark_recap(
                                    user,
                                    recap_sent=bool(recap) and delivered,
                                    drift=drift,
                                )
                                if delivered and isinstance(reply, str):
                                    self.transcripts.remember_turn(
                                        user, brain.bot_label, reply
                                    )
                                    brain.memory_record(
                                        f"desktop:{user}", brain.bot_label, reply
                                    )
                                if recap and delivered and budget_key is not None:
                                    brain.budget.charge_context(budget_key, recap)
                    finally:
                        hub.publish(
                            user,
                            {"kind": "typing", "role": "bot", "on": False},
                            store=False,
                        )
                    if new_id:
                        self.threads.remember(user, new_id)
                    if budget_key is not None and isinstance(reply, str):
                        brain.budget.charge(budget_key, reply)
                    bot_id = self.publish_message(
                        user, "bot", reply, reactable=brain.reactions_enabled
                    )
                    self.reactables.remember(user, bot_id, new_id, reply)
                except Exception as e:
                    brain.log_error(
                        f"signal-bot: a desktop chat turn failed: "
                        f"{type(e).__name__}: {e}"
                    )

            threading.Thread(target=work, daemon=True).start()
            return jsonify(status="accepted"), 202

        @app.route("/v1/chat/react", methods=["POST"])
        def http_chat_react():
            user = chat_user()
            if not user:
                return jsonify(error="unauthorized"), 401
            if not brain.reactions_enabled:
                return jsonify(error="reactions are disabled"), 403
            body = request.get_json(silent=True) or {}
            target_id = body.get("targetId")
            emoji = body.get("emoji")
            if not isinstance(emoji, str) or not emoji:
                return jsonify(error="emoji required"), 400
            claimed = self.reactables.claim(user, target_id)
            if claimed is None:
                return jsonify(error="target not reactable"), 409
            conversation_id, reacted_text = claimed

            def work():
                try:
                    print("signal-bot: handling a desktop reaction", file=sys.stderr)
                    budget_key = brain.budget_key_for(user)
                    if budget_key is not None:
                        granted, _ = brain.budget.claim(
                            budget_key, reacted_text or emoji, notify=False
                        )
                        if not granted:
                            self.publish_message(user, "bot", brain.budget_exhausted)
                            return
                    hub.publish(
                        user, {"kind": "typing", "role": "bot", "on": True}, store=False
                    )
                    try:
                        reply, new_id = brain.reaction_reply(
                            conversation_id, reacted_text, emoji
                        )
                    finally:
                        hub.publish(
                            user,
                            {"kind": "typing", "role": "bot", "on": False},
                            store=False,
                        )
                    if new_id:
                        self.threads.remember(user, new_id)
                    if budget_key is not None and isinstance(reply, str):
                        brain.budget.charge(budget_key, reply)
                    self.publish_message(
                        user, "bot", reply, reactable=False, quote_id=target_id
                    )
                except Exception as e:
                    brain.log_error(
                        f"signal-bot: a desktop reaction failed: "
                        f"{type(e).__name__}: {e}"
                    )

            threading.Thread(target=work, daemon=True).start()
            return jsonify(status="accepted"), 202

        @app.route("/v1/chat/stream")
        def http_chat_stream():
            user = chat_user()
            if not user:
                return jsonify(error="unauthorized"), 401
            q, backlog = hub.subscribe(user)

            def gen():
                try:
                    for event in backlog:
                        yield f"data: {json.dumps(event)}\n\n"
                    while True:
                        try:
                            event = q.get(timeout=3)
                            if event is _STREAM_CLOSED:
                                return
                            yield f"data: {json.dumps(event)}\n\n"
                        except Empty:
                            yield ": keepalive\n\n"
                finally:
                    hub.unsubscribe(user, q)

            return app.response_class(gen(), mimetype="text/event-stream")
