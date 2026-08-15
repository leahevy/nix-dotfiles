import collections
import contextlib
import json
import sys
import threading
import time
from queue import Empty, Full, Queue


class ChatHub:
    def __init__(self, ring_size):
        self.ring_size = ring_size
        self.lock = threading.Lock()
        self.subscribers = {}
        self.rings = {}

    def publish(self, user, event, store=True):
        with self.lock:
            if store:
                ring = self.rings.setdefault(
                    user, collections.deque(maxlen=self.ring_size)
                )
                ring.append(event)
            targets = list(self.subscribers.get(user, ()))
        for q in targets:
            with contextlib.suppress(Full):
                q.put_nowait(event)

    def subscribe(self, user):
        q = Queue(maxsize=100)
        with self.lock:
            backlog = list(self.rings.get(user, ()))
            self.subscribers.setdefault(user, set()).add(q)
        return q, backlog

    def unsubscribe(self, user, q):
        with self.lock:
            subs = self.subscribers.get(user)
            if subs:
                subs.discard(q)
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


class DesktopChannel:
    def __init__(self, brain):
        self.brain = brain
        cfg = brain.cfg
        self.cfg = cfg
        self.recipients = cfg.get("chat_recipients") or {}
        self.default_recipient = cfg.get("chat_default_recipient")
        self.hub = ChatHub(cfg.get("chat_ring_buffer_size", 50))
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
        self.id_lock = threading.Lock()
        self.id_counter = 0

    def next_id(self):
        with self.id_lock:
            self.id_counter += 1
            return self.id_counter

    def publish_message(
        self, user, role, text, reactable=False, title="", url="", quote_id=None
    ):
        event_id = self.next_id()
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
        return True

    def register(self, app, jsonify, request):
        brain = self.brain
        cfg = self.cfg
        hub = self.hub

        def chat_user():
            return request.headers.get("X-Auth-Request-User") or None

        chat_page = brain.read_secret(cfg["chat_page_file"])
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
                fontSize=cfg.get("chat_font_size", 14),
                fontFamily=cfg.get("chat_font_family", "monospace"),
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
                    print("signal-bot: handling a desktop message", file=sys.stderr)
                    budget_key = brain.budget_key_for(user)
                    if budget_key is not None:
                        granted, _ = brain.budget.claim(budget_key, text, notify=False)
                        if not granted:
                            self.publish_message(user, "bot", brain.budget_exhausted)
                            return
                    hub.publish(
                        user,
                        {"kind": "typing", "role": "bot", "on": True},
                        store=False,
                    )
                    try:
                        reply = brain.command_reply(text)
                        if reply is not None:
                            new_id = None
                        else:
                            reply, new_id = brain.call_ha_conversation(
                                text, self.threads.resolve(user)
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
                    bot_id = self.publish_message(
                        user, "bot", reply, reactable=True, quote_id=target_id
                    )
                    self.reactables.remember(user, bot_id, new_id, reply)
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
                            yield f"data: {json.dumps(q.get(timeout=15))}\n\n"
                        except Empty:
                            yield ": keepalive\n\n"
                finally:
                    hub.unsubscribe(user, q)

            return app.response_class(gen(), mimetype="text/event-stream")
