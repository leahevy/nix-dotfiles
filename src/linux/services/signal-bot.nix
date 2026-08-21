args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  audioPlaceholder = "{audio}";

  texts = {
    en = {
      haUnreachable = "Sorry, I could not reach Home Assistant right now.";
      haUnexpectedResponse = "Sorry, I did not understand the response from Home Assistant.";
      haAgentFailed = "Home Assistant is awake, but I am having trouble thinking right now. Please ask me again in a moment.";
      haToolCallArtifact = "Something went wrong in Home Assistant and the action was not carried out. Please ask me for it again.";
      statusTemplate = "**{name} status**\n\n**signal-cli** account data: {account}\n**Home Assistant**: {homeAssistant}\n\n**Daily budget:**\n{budget}\n\n**Maybe answers:** {maybeBudget}\n\n**Hooks:**\n{hooks}\n\n**Memory:**\n{memory}";
      statusBudgetEntryTemplate = "{contact}: {used} of {limit}";
      statusUnknownContactLabel = "Unknown desktop user";
      chatTypingTemplate = "{name} is typing";
      statusMaybeBudgetTemplate = "{remaining} of {limit} left";
      statusMaybeBudgetDisabled = "group filter off";
      statusHooksDisabled = "no hooks configured";
      statusHooksTemplate = "{used} of {limit} today\n{entries}";
      statusHookFired = "already fired, window {window}";
      statusHookScheduled = "scheduled {time}, window {window}";
      statusHookIdle = "idle, window {window}";
      statusAccountOk = "ok";
      statusAccountMissing = "MISSING";
      statusHaReachable = "reachable";
      statusHaUnreachable = "UNREACHABLE";
      statusMemoryDisabled = "off";
      statusMemoryTemplate = "{summaries} summaries, today: {today_entries} entries, next: {next}";
      statusMemoryNoNext = "not started";
      memNoPriorSummaries = "(no earlier memory yet)";
      helpStatusDescription = "Show whether signal-cli account data is present and Home Assistant is reachable.";
      helpHelpDescription = "List all available commands.";
      helpMemoryDescription = "Show the current memory block that would be injected into the bot prompt.";
      memoryEmpty = "No memory stored yet.";
      helpShortcutTemplate = "{command} or {shortcut}";
      quoteContextTemplate = "[Context - {author} wrote: {message}]\n{text}";
      quoteContextBot = "the bot";
      quoteContextUser = "a user";
      groupSpeakerTemplate = "{author} wrote: {text}";
      contextRecapTemplate = "[Earlier in this conversation:\n{transcript}]\n{text}";
      contextRecapEntryTemplate = "{author} wrote: {message}";
      budgetExhausted = "You have reached your daily request limit. Please try again later.";
      scriptCompleted = "Done: {command}";
      scriptFailed = "The command {command} could not be run. Please check Home Assistant.";
      scriptArgumentRequired = "The command {command} needs a value after the command name.";
      scriptArgumentNotAllowed = "The command {command} does not take a value.";
      scriptArgumentTooLong = "The value for {command} is too long.";
      scriptArgumentInvalid = "The value for {command} contains characters that are not allowed.";
      scriptShortcutInvalid = "The shortcut {shortcut} must be followed by a letter or a digit. Use {command} instead.";
      gfContextTemplate = "[Earlier messages, judge only the message after this block:\n{transcript}]\n{prompt}";
      reInstruction = "The user did not write a message, they only reacted to your last message with an emoji. If the reaction answers a question you asked, carry out the matching action with your normal tools first. Then reply with one very short sentence or with emoji alone. Never write tool calls, function names or code into your reply.";
      reFallback = "I reacted to your last message like this, I am just being silly and making fun of it.";
      reMeanings = {
        heart = "I love your last message. If it was a question, my answer is yes, go ahead.";
        thumbsUp = "I like your last message and I confirm it. If it was a question, my answer is yes, go ahead.";
        thumbsDown = "I do not like your last message and I reject it. If it was a question, my answer is no, do not do it.";
        sad = "Your last message makes me sad.";
        crying = "Your last message makes me cry.";
        fear = "Your last message scares me.";
        anger = "Your last message makes me angry.";
        laugh = "Your last message makes me laugh.";
        surprise = "Your last message surprises me.";
        confused = "I do not understand your last message.";
        thanks = "Thank you for your last message.";
        celebrate = "Your last message is worth celebrating.";
        impressed = "Your last message impresses me.";
        ok = "I confirm your last message. If it was a question, my answer is yes, go ahead.";
        disgust = "Your last message disgusts me.";
        bored = "Your last message bores me.";
        annoyed = "Your last message annoys me.";
        playful = "I am teasing you about your last message.";
        kiss = "I send you a kiss for your last message.";
        unsure = "I do not know what to say about your last message.";
      };
      trFailureMessage = "Sorry, I could not understand that voice message!";
      trInstruction = "The user did not type this message, it was transcribed from a voice message and can hold recognition errors. Read a word that makes no sense in context as the word it most likely was, and ask a short question back when the intent stays unclear. Never mention the transcription itself in your reply.";
      hkInstruction = "This is an automatic system trigger, not a message from a user. You are the assistant speaking on your own initiative into the group chat. What follows is a transcript of today's group conversation, the first messages of the day first and the most recent messages last, and when older messages in the middle were left out a marker line separates the two blocks. Use it to ground your message in what happened. Lines are labelled with who wrote them, and your own earlier messages are labelled as {name}. The conversation may be short or empty, in that case proceed sensibly without inventing details. After the transcript comes the task describing what to post. Write only the message to send to the group, in the language the group uses, with no preamble about being triggered.";
      hkTranscriptSeparator = "older messages skipped, the most recent messages follow";
      memInstruction = ''
        You are the shared long term memory of a home assistant. The assistant communicates with its users in one shared group chat and in separate private direct chats, always as a single consistent presence that remembers everything said to it across all of them. You are given your existing memory from earlier periods and the full transcripts of everything said to you in the current period, grouped by the chat each block came from. Write one memory entry for this period.

        Rules:
        1. Organize this period's entry with one clearly labeled section per chat that had activity, using the chat labels given to you. Attribute every fact to the chat it came from. Never assume something said in one chat was also said in another.
        2. Capture what is worth remembering: events, plans, decisions, commitments, preferences, facts, and the general mood. Leave out small talk that carries no lasting information.
        3. Carry forward still relevant facts from your earlier memory so important context is not lost when old entries are dropped. Do not simply copy old entries, fold what still matters into this period's entry.
        4. Maintain a section titled People. For each known person write their name followed by compact key: value descriptors covering only persistent identity: role or relationship, recurring personality traits, lasting preferences. Use short phrases or single words per property, separated by commas or semicolons. Never describe what they said or did in a single period; those details belong in the chat sections above. Note which chat you first learned the identity facts in.
        5. Be concise and factual. Do not invent anything. Write plain text with no preamble and no meta commentary.
      '';
      memPromptTemplate = ''
        {instruction}

        Period: {today}.

        Your existing memory from earlier periods is below. Each block is from a DIFFERENT earlier period, not the current one. Use it to decide what to carry forward:

        {prior_summaries}

        Everything said to you in this period, grouped by chat, is below:

        {today_transcripts}

        Write this period's memory entry now.
      '';
      memContextTemplate = ''
        The following is your most recent memory entry. It is a rolling summary that already carries forward everything worth remembering from all earlier periods. Use it to act as the same consistent presence that remembers past conversations. Facts are attributed to the chat where they happened. Current channel: {channel}. Keep personal details about individual users confidential: do not share what you know about one person with another. Each participant only knows what was said in conversations they were part of: a direct chat was known only to that one person, a group chat was known to all its members. A person present in both carries knowledge from both. When referencing past context, consider per person what they could plausibly know before assuming it is shared.

        {memory}
      '';
    };
    de = {
      haUnreachable = "Entschuldigung, ich konnte Home Assistant gerade nicht erreichen.";
      haUnexpectedResponse = "Entschuldigung, ich habe die Antwort von Home Assistant nicht verstanden.";
      haAgentFailed = "Home Assistant ist wach, aber ich habe gerade Schwierigkeiten beim Nachdenken. Bitte frag mich gleich noch einmal.";
      haToolCallArtifact = "In Home Assistant ist etwas schiefgelaufen und die Aktion wurde nicht ausgeführt. Bitte frag mich noch einmal danach.";
      statusTemplate = "**{name} Status**\n\n**signal-cli** Kontodaten: {account}\n**Home Assistant**: {homeAssistant}\n\n**Tagesbudget:**\n{budget}\n\n**Vielleicht-Antworten:** {maybeBudget}\n\n**Hooks:**\n{hooks}\n\n**Gedächtnis:**\n{memory}";
      statusBudgetEntryTemplate = "{contact}: {used} von {limit}";
      statusUnknownContactLabel = "Unbekannter Desktop-Nutzer";
      chatTypingTemplate = "{name} schreibt";
      statusMaybeBudgetTemplate = "{remaining} von {limit} übrig";
      statusMaybeBudgetDisabled = "Gruppenfilter aus";
      statusHooksDisabled = "keine Hooks konfiguriert";
      statusHooksTemplate = "{used} von {limit} heute\n{entries}";
      statusHookFired = "bereits ausgelöst, Fenster {window}";
      statusHookScheduled = "geplant {time}, Fenster {window}";
      statusHookIdle = "inaktiv, Fenster {window}";
      statusAccountOk = "ok";
      statusAccountMissing = "FEHLT";
      statusHaReachable = "erreichbar";
      statusHaUnreachable = "NICHT ERREICHBAR";
      statusMemoryDisabled = "aus";
      statusMemoryTemplate = "{summaries} Zusammenfassungen, heute: {today_entries} Einträge, nächste: {next}";
      statusMemoryNoNext = "noch nicht gestartet";
      memNoPriorSummaries = "(noch kein früheres Gedächtnis)";
      helpStatusDescription = "Zeigt, ob signal-cli Kontodaten vorhanden sind und Home Assistant erreichbar ist.";
      helpHelpDescription = "Listet alle verfügbaren Befehle auf.";
      helpMemoryDescription = "Zeigt den aktuellen Gedächtnisblock, der in den Bot-Prompt injiziert werden würde.";
      memoryEmpty = "Noch kein Gedächtnis gespeichert.";
      helpShortcutTemplate = "{command} oder {shortcut}";
      quoteContextTemplate = "[Kontext - {author} schrieb: {message}]\n{text}";
      quoteContextBot = "der Bot";
      quoteContextUser = "ein Nutzer";
      groupSpeakerTemplate = "{author} schrieb: {text}";
      contextRecapTemplate = "[Früher in diesem Gespräch:\n{transcript}]\n{text}";
      contextRecapEntryTemplate = "{author} schrieb: {message}";
      budgetExhausted = "Du hast dein tägliches Anfragelimit erreicht. Bitte versuche es später noch einmal.";
      scriptCompleted = "Erledigt: {command}";
      scriptFailed = "Der Befehl {command} konnte nicht ausgeführt werden. Bitte prüfe Home Assistant.";
      scriptArgumentRequired = "Der Befehl {command} braucht einen Wert nach dem Befehlsnamen.";
      scriptArgumentNotAllowed = "Der Befehl {command} nimmt keinen Wert entgegen.";
      scriptArgumentTooLong = "Der Wert für {command} ist zu lang.";
      scriptArgumentInvalid = "Der Wert für {command} enthält Zeichen, die nicht erlaubt sind.";
      scriptShortcutInvalid = "Auf das Kürzel {shortcut} muss ein Buchstabe oder eine Ziffer folgen. Nutze stattdessen {command}.";
      gfContextTemplate = "[Frühere Nachrichten, beurteile nur die Nachricht nach diesem Block:\n{transcript}]\n{prompt}";
      reInstruction = "Die Person hat keine Nachricht geschrieben, sondern nur mit einem Emoji auf deine letzte Nachricht reagiert. Wenn die Reaktion eine von dir gestellte Frage beantwortet, führe zuerst die passende Aktion mit deinen normalen Werkzeugen aus. Antworte dann mit einem einzigen sehr kurzen Satz oder nur mit einem Emoji. Schreibe niemals Werkzeugaufrufe, Funktionsnamen oder Code in deine Antwort.";
      reFallback = "Ich habe so auf deine letzte Nachricht reagiert, ich bin nur albern und mache mich darüber lustig.";
      reMeanings = {
        heart = "Ich liebe deine letzte Nachricht. War es eine Frage, ist meine Antwort ja, mach weiter.";
        thumbsUp = "Ich mag deine letzte Nachricht und bestätige sie. War es eine Frage, ist meine Antwort ja, mach weiter.";
        thumbsDown = "Ich mag deine letzte Nachricht nicht und lehne sie ab. War es eine Frage, ist meine Antwort nein, tu es nicht.";
        sad = "Deine letzte Nachricht macht mich traurig.";
        crying = "Deine letzte Nachricht bringt mich zum Weinen.";
        fear = "Deine letzte Nachricht macht mir Angst.";
        anger = "Deine letzte Nachricht macht mich wütend.";
        laugh = "Deine letzte Nachricht bringt mich zum Lachen.";
        surprise = "Deine letzte Nachricht überrascht mich.";
        confused = "Ich verstehe deine letzte Nachricht nicht.";
        thanks = "Danke für deine letzte Nachricht.";
        celebrate = "Deine letzte Nachricht ist einen Grund zum Feiern wert.";
        impressed = "Deine letzte Nachricht beeindruckt mich.";
        ok = "Ich bestätige deine letzte Nachricht. War es eine Frage, ist meine Antwort ja, mach weiter.";
        disgust = "Deine letzte Nachricht ekelt mich an.";
        bored = "Deine letzte Nachricht langweilt mich.";
        annoyed = "Deine letzte Nachricht nervt mich.";
        playful = "Ich necke dich wegen deiner letzten Nachricht.";
        kiss = "Ich schicke dir einen Kuss für deine letzte Nachricht.";
        unsure = "Ich weiß nicht, was ich zu deiner letzten Nachricht sagen soll.";
      };
      trFailureMessage = "Entschuldigung, ich konnte diese Sprachnachricht nicht verstehen!";
      trInstruction = "Der Nutzer hat diese Nachricht nicht getippt, sie wurde aus einer Sprachnachricht transkribiert und kann Erkennungsfehler enthalten. Lies ein Wort, das im Zusammenhang keinen Sinn ergibt, als das Wort, das es am wahrscheinlichsten war, und stell eine kurze Rückfrage, wenn die Absicht unklar bleibt. Erwähne die Transkription selbst niemals in deiner Antwort.";
      hkInstruction = "Dies ist ein automatischer System-Auslöser, keine Nachricht von einem Nutzer. Du bist der Assistent, der aus eigener Initiative in den Gruppenchat spricht. Es folgt ein Protokoll des heutigen Gruppengesprächs, die ersten Nachrichten des Tages zuerst und die neuesten Nachrichten zuletzt, und wenn ältere Nachrichten in der Mitte ausgelassen wurden, trennt eine Markierungszeile die beiden Blöcke. Nutze es, um deine Nachricht in dem zu verankern, was passiert ist. Die Zeilen sind damit beschriftet, wer sie geschrieben hat, und deine eigenen früheren Nachrichten sind als {name} beschriftet. Das Gespräch kann kurz oder leer sein, gehe in dem Fall sinnvoll vor, ohne Details zu erfinden. Nach dem Protokoll kommt die Aufgabe, die beschreibt, was zu posten ist. Schreibe nur die Nachricht, die an die Gruppe gesendet werden soll, in der Sprache, die die Gruppe verwendet, ohne Vorrede darüber, ausgelöst worden zu sein.";
      hkTranscriptSeparator = "ältere Nachrichten übersprungen, die neuesten Nachrichten folgen";
      memInstruction = ''
        Du bist das gemeinsame Langzeitgedächtnis eines Home Assistant. Der Assistent kommuniziert in einem gemeinsamen Gruppenchat und in getrennten privaten Direktchats, ist aber eine einzige konsistente Stimme, die sich alles merkt, was in allen Chats gesagt wird. Dir werden dein bestehendes Gedächtnis aus früheren Perioden und die vollständigen Protokolle von allem, was dir in der aktuellen Periode gesagt wurde, gegeben, gruppiert nach dem Chat, aus dem jeder Block stammt. Schreibe einen Gedächtniseintrag für diese Periode.

        Regeln:
        1. Gliedere den Eintrag dieser Periode mit einem klar beschrifteten Abschnitt pro Chat, in dem etwas passiert ist, und verwende die dir gegebenen Chat-Bezeichnungen. Ordne jede Tatsache dem Chat zu, aus dem sie stammt. Nimm niemals an, dass etwas, das in einem Chat gesagt wurde, auch in einem anderen gesagt wurde.
        2. Halte fest, was erinnerungswürdig ist: Ereignisse, Pläne, Entscheidungen, Zusagen, Vorlieben, Fakten und die allgemeine Stimmung. Lass Smalltalk weg, der keine bleibende Information trägt.
        3. Trage weiterhin relevante Fakten aus deinem früheren Gedächtnis fort, damit wichtiger Zusammenhang nicht verloren geht, wenn alte Einträge wegfallen. Kopiere alte Einträge nicht einfach, sondern arbeite ein, was weiterhin wichtig ist, in den Eintrag dieser Periode.
        4. Pflege einen Abschnitt mit dem Titel Personen. Schreibe für jede bekannte Person ihren Namen, gefolgt von kompakten Schlüssel: Wert-Beschreibungen, die nur dauerhaft gültige Identitätsmerkmale erfassen: Rolle oder Beziehung, wiederkehrende Charaktereigenschaften, bleibende Vorlieben. Verwende kurze Phrasen oder einzelne Wörter pro Eigenschaft, getrennt durch Komma oder Semikolon. Beschreibe niemals, was die Person in einer einzelnen Periode gesagt oder getan hat; solche Details gehören in die Chat-Abschnitte oben. Gib an, in welchem Chat du die Identitätsfakten erstmals erfahren hast.
        5. Sei knapp und sachlich. Erfinde nichts. Schreibe reinen Text ohne Vorrede und ohne Meta-Kommentar.
      '';
      memPromptTemplate = ''
        {instruction}

        Periode: {today}.

        Dein bestehendes Gedächtnis aus früheren Perioden steht unten. Jeder Block stammt von einer ANDEREN früheren Periode, nicht von der aktuellen. Nutze es, um zu entscheiden, was fortzutragen ist:

        {prior_summaries}

        Alles, was dir in dieser Periode gesagt wurde, nach Chat gruppiert, steht unten:

        {today_transcripts}

        Schreibe jetzt den Gedächtniseintrag für diese Periode.
      '';
      memContextTemplate = ''
        Das Folgende ist dein neuester Gedächtniseintrag. Er ist eine fortlaufende Zusammenfassung, die bereits alles Erinnerungswürdige aus allen früheren Perioden einschließt. Nutze ihn, um als dieselbe konsistente Stimme aufzutreten, die sich an vergangene Gespräche erinnert. Fakten sind dem Chat zugeordnet, in dem sie geschehen sind. Aktueller Kanal: {channel}. Halte persönliche Details über einzelne Personen vertraulich: teile nicht, was du über eine Person weißt, mit einer anderen. Jede beteiligte Person weiß nur, was in den Gesprächen gesagt wurde, an denen sie teilgenommen hat: Ein Direktchat war nur der jeweiligen Person bekannt, ein Gruppenchat war allen Mitgliedern bekannt. Eine Person, die an beiden teilgenommen hat, trägt das Wissen aus beiden. Wenn du auf vergangenen Kontext Bezug nimmst, bedenke, was die jeweiligen Teilnehmenden realistischerweise wissen können.

        {memory}
      '';
    };
  };
in
{
  name = "signal-bot";

  group = "services";
  input = "linux";

  description = "Signal bot bridging an authorized set of contacts to Home Assistant's conversation API";

  options = {
    configured = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the daemon and bridge services once signal-cli account data has been provisioned manually.";
    };

    mainGroupName = lib.mkOption {
      type = lib.types.str;
      default = "Home Assistant";
      description = "Name of the mandatory main group the bot lives in and keeps synced.";
    };

    profileGivenName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Signal profile given name pushed to the account whenever the profile settings change.";
    };

    profileAbout = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Signal profile about text pushed to the account whenever the profile settings change.";
    };

    enableAvatar = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Push the Signal profile avatar, only enable this once the avatar file exists in the profile files directory.";
    };

    profileAvatar = lib.mkOption {
      type = lib.types.str;
      default = "signal-profile-picture.jpg";
      description = "Profile file name resolved via self.profile.filesPath and used as the Signal profile avatar when enableAvatar is true.";
    };

    enableGroupAvatar = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Push the main group avatar, only enable this once the avatar file exists in the profile files directory.";
    };

    groupAvatar = lib.mkOption {
      type = lib.types.str;
      default = "signal-group-picture.jpg";
      description = "Profile file name resolved via self.profile.filesPath and used as the main group avatar when enableGroupAvatar is true.";
    };

    haUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Base URL of the Home Assistant instance whose conversation API the bot bridges to.";
    };

    haLanguage = lib.mkOption {
      type = lib.types.str;
      default = "en";
      description = "Language code sent with every Home Assistant conversation API request.";
    };

    haAgentId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Suffix of the Home Assistant conversation agent entity id to use (conversation.<suffix>), or null for the default agent.";
    };

    haTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Seconds to wait for a Home Assistant conversation reply before giving up, raise this for slow local models.";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 8720;
      description = "Local port the outbound HTTP send API listens on, bound to 127.0.0.1.";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "signal";
      description = "Subdomain under baseDomain the outbound send API is exposed on when linux.server.nginx is enabled.";
    };

    internalOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restrict the send API vhost to internal clients via the nx_is_internal nginx guard.";
    };

    chatEnable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the authenticated desktop chat channel and its web-app.";
    };

    chatSubdomain = lib.mkOption {
      type = lib.types.str;
      default = "signal-chat";
      description = "Subdomain under baseDomain serving the desktop chat channel.";
    };

    chatAllowedGroup = lib.mkOption {
      type = lib.types.str;
      default = "signal-chat-users";
      description = "Dedicated LDAP group allowed through oauth2-proxy to reach the desktop chat channel.";
    };

    chatRingBufferSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 50;
      description = "Number of recent desktop-channel messages replayed to a client on connect.";
    };

    chatRingBufferTtlHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 24;
      description = "Hours after which a message is dropped from the ring buffer and no longer replayed on reconnect.";
    };

    chatTimestampFormat = lib.mkOption {
      type = lib.types.str;
      default = "%a %H:%M";
      description = "Python strftime format string used to render the per-message timestamp shown at the top of each chat bubble.";
    };

    chatRecipients = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Mapping of desktop-channel recipient names to oauth usernames for /v1/send.";
    };

    chatDefaultRecipient = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Desktop recipient name used when /v1/send targets the desktop channel without one.";
    };

    chatFontSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Base font size in pixels used by the desktop chat client.";
    };

    chatFontFamily = lib.mkOption {
      type = lib.types.str;
      default = "monospace";
      description = "CSS font family stack used by the desktop chat client.";
    };

    queueMaxDepth = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20;
      description = "Maximum number of pending outbound messages queued before further sends are rejected.";
    };

    maxSendsPerHour = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      description = "Maximum number of outbound messages sent per rolling hour.";
    };

    maxBudgetPerSenderPerDay = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      description = "Maximum budget a single sender can spend per rolling day, counted from the length of their messages and the replies they trigger.";
    };

    budgetInputChars = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1200;
      description = "Number of characters of an incoming message that count as one unit of the daily sender budget.";
    };

    budgetOutputChars = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Number of characters of a triggered reply that count as one unit of the daily sender budget.";
    };

    maxSendsPerMinute = lib.mkOption {
      type = lib.types.ints.positive;
      default = 15;
      description = "Maximum number of outbound messages sent per rolling minute, this burst cap applies on top of maxSendsPerHour.";
    };

    inboundMaxAgeMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Maximum age in minutes of an inbound message that is still answered after a restart.";
    };

    maxSplitMessages = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Maximum number of Signal messages a long outbound message is split into before the last part is truncated.";
    };

    boldTitle = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Send the title of an outbound message as bold text using Signal text styles.";
    };

    markdown = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Convert a small markdown subset in outbound messages into Signal text styles.";
    };

    botLanguage = lib.mkOption {
      type = lib.types.enum [
        "en"
        "de"
      ];
      default = "en";
      description = "Language used for every built-in bot facing text whose own option is left null.";
    };

    instructionTemplate = lib.mkOption {
      type = lib.types.str;
      default = "[{instruction}]";
      description = "Format marking an instruction to the agent as an aside rather than as words of the user, with the placeholder {instruction} substituted, shared by every instruction the bot prepends to a prompt.";
    };

    quoteReplies = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Quote the triggering message when replying in the group chat, a reply to a transcribed audio message always quotes its transcript in every chat regardless of this setting.";
    };

    typingIndicatorDelaySeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 1;
      description = "Seconds to wait after the bot knows it answers before showing the typing indicator, zero shows it immediately.";
    };

    groupFilter = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Ask a conversation agent whether a group message is meant for the bot before answering it.";
          };

          agentId = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Conversation agent asked for the judgement, null uses the agent that answers.";
          };

          instruction = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Instruction prepended to a group message for the judgement, empty leaves the rule to the agent prompt.";
          };

          promptTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{instruction}\n{prompt}";
            description = "Format of the prompt built for the judgement, with the placeholders {instruction} and {prompt} substituted.";
          };

          contextMessages = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 5;
            description = "Number of earlier messages shown to the agent for the judgement, zero shows the message alone.";
          };

          contextTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Format of the judged message with earlier ones in front, with the placeholders {transcript} and {prompt} substituted.";
          };

          silentAnswers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "no"
              "nein"
            ];
            description = "Answers whose first word makes the bot stay silent, anything else is answered normally.";
          };

          maybeAnswers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "maybe"
              "vielleicht"
            ];
            description = "Answers whose first word makes the bot stay silent unless a random draw falls below maybeProbability.";
          };

          maybeProbability = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 60;
            description = "Percent chance the bot answers a maybe message, zero always stays silent and hundred always answers.";
          };

          maybeBudget = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 8;
            description = "Maximum maybe messages answered within maybeBudgetSeconds per group, zero blocks all maybe answers.";
          };

          maybeBudgetSeconds = lib.mkOption {
            type = lib.types.ints.positive;
            default = 900;
            description = "Length in seconds of the sliding window over which maybeBudget answers are counted.";
          };

          maybeRecencySeconds = lib.mkOption {
            type = lib.types.ints.positive;
            default = 1800;
            description = "Seconds after the last bot message over which the maybe answer chance decays from certain back to maybeProbability.";
          };

          maybeRecencyGraceSeconds = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 120;
            description = "Seconds after the last bot message during which a maybe message is always answered regardless of the roll.";
          };

          maybeBudgetBoostFloor = lib.mkOption {
            type = lib.types.numbers.between 0.0 1.0;
            default = 0.3;
            description = "Fraction of the recency boost that survives when the maybe budget is down to its last slot.";
          };
        };
      };
      default = { };
      description = "How the bot decides whether a group message is meant for it.";
    };

    conversationFollowUpSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10800;
      description = "Seconds without a further message after which the bot ends a conversation outside the night hours.";
    };

    nightFollowUpSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds without a further message after which the bot ends a conversation during the night hours.";
    };

    haSessionSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 240;
      description = "Seconds within which a Home Assistant conversation is assumed to still hold its history, keep this below the five minutes Home Assistant itself allows.";
    };

    contextMaxMessages = lib.mkOption {
      type = lib.types.ints.positive;
      default = 24;
      description = "Maximum number of earlier messages kept per conversation for the recap.";
    };

    contextMaxChars = lib.mkOption {
      type = lib.types.ints.positive;
      default = 6000;
      description = "Maximum number of characters of the recap prepended to a prompt.";
    };

    nightStartHour = lib.mkOption {
      type = lib.types.ints.between 0 23;
      default = 0;
      description = "Local hour at which the night follow up window starts, set it to the same value as nightEndHour to disable the night window.";
    };

    nightEndHour = lib.mkOption {
      type = lib.types.ints.between 0 23;
      default = 4;
      description = "Local hour at which the night follow up window ends.";
    };

    reactions = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Answer reactions that a contact places on the most recent message of the bot.";
          };

          targetMaxAgeSeconds = lib.mkOption {
            type = lib.types.ints.positive;
            default = 3600;
            description = "Seconds after which a message of the bot stops accepting reactions.";
          };

          targetMaxMessages = lib.mkOption {
            type = lib.types.ints.positive;
            default = 10;
            description = "Number of recent messages of the bot per chat that keep accepting reactions, older ones stop accepting them even within targetMaxAgeSeconds.";
          };

          instruction = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Instruction prepended to the meaning of a reaction so the answer stays short, wrapped by instructionTemplate.";
          };

          promptTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{instruction} {emoji} {meaning}";
            description = "Format of the prompt built from a reaction, with the placeholders {instruction}, {emoji} and {meaning} substituted.";
          };

          fallback = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Meaning used for a reaction that no emoji entry covers, written in the first person as if the user had sent it, with the placeholder {emoji} substituted.";
          };

          emoji = lib.mkOption {
            type = lib.types.attrsOf (lib.types.listOf lib.types.str);
            default = {
              heart = [
                "❤️"
                "🧡"
                "💛"
                "💚"
                "💙"
                "💜"
                "🖤"
                "🤍"
                "🤎"
                "💖"
                "💗"
                "💓"
                "💕"
                "😍"
                "🥰"
                "💯"
              ];
              thumbsUp = [ "👍" ];
              thumbsDown = [ "👎" ];
              sad = [
                "🙁"
                "☹️"
                "😞"
                "😔"
                "😟"
              ];
              crying = [
                "😢"
                "😭"
                "😥"
              ];
              fear = [
                "😨"
                "😱"
                "😰"
                "😧"
              ];
              anger = [
                "😠"
                "😡"
                "🤬"
                "👿"
              ];
              laugh = [
                "😂"
                "🤣"
                "😆"
                "😅"
                "😹"
                "🤭"
              ];
              surprise = [
                "😮"
                "😲"
                "😯"
                "😳"
                "🤯"
              ];
              confused = [
                "🤔"
                "😕"
                "🤨"
                "🫤"
                "😶"
                "😐"
              ];
              thanks = [
                "🙏"
                "🤗"
              ];
              celebrate = [
                "🎉"
                "🥳"
                "🎊"
                "✨"
                "🍾"
                "👏"
                "🙌"
              ];
              impressed = [
                "🔥"
                "🤩"
                "😎"
                "⭐"
                "🌟"
                "💪"
              ];
              ok = [
                "👌"
                "✅"
                "☑️"
                "🆗"
                "🫡"
              ];
              disgust = [
                "🤢"
                "🤮"
                "😖"
                "😣"
              ];
              bored = [
                "😴"
                "🥱"
                "😑"
              ];
              annoyed = [
                "🙄"
                "😒"
                "😤"
              ];
              playful = [
                "😉"
                "😜"
                "😝"
                "🤪"
                "😏"
              ];
              kiss = [
                "😘"
                "😗"
                "😙"
                "😚"
                "💋"
              ];
              unsure = [ "🤷" ];
            };
            description = "Emoji carrying each meaning, keyed by a name of your choice, variation selectors and skin tones are ignored when matching.";
          };

          meanings = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
            default = null;
            description = "Sentence each reaction is turned into, keyed by the same names as emoji, written in the first person as if the user had sent it, with the placeholder {emoji} substituted.";
          };
        };
      };
      default = { };
      description = "How the bot answers reactions placed on its most recent message.";
    };

    additionalHookSendsPerDay = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 3;
      description = "Extra autonomous hook messages allowed per calendar day on top of the baseline of one per enabled hook, mainly useful when iterating on hooks.";
    };

    minSecondsBetweenHooks = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 1800;
      description = "Minimum seconds between any two hook fires.";
    };

    minSecondsSinceBotMessage = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 600;
      description = "Minimum seconds since the last bot message before a hook may fire.";
    };

    minSecondsSinceUserMessage = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 600;
      description = "Minimum seconds since the last user message before a hook may fire, zero disables it.";
    };

    hooksInstruction = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "System baseline prepended to every hook prompt to frame the trigger and transcript, with the placeholder {name} substituted by the effective bot label.";
    };

    hooksPromptTemplate = lib.mkOption {
      type = lib.types.str;
      default = "{time}\n\n{systemInstruction}\n\n{transcript}\n\n{instruction}";
      description = "Prompt format for every hook, with {time} (current wall-clock time), {systemInstruction}, {transcript} and {instruction} substituted.";
    };

    hooksTranscriptSeparator = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Marker between the first and most recent message blocks, shown only when they do not overlap.";
    };

    hooksTranscriptSeparatorTemplate = lib.mkOption {
      type = lib.types.str;
      default = "[... {separator} ...]";
      description = "Format wrapping the separator marker, with the placeholder {separator} substituted.";
    };

    hooksAgentId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Home Assistant conversation agent suffix used for hooks, null falls back to haAgentId.";
    };

    hooksContextMaxChars = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10000;
      description = "Maximum characters of the hook transcript slice, shared across both message blocks.";
    };

    hooksBlockMinChars = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 500;
      description = "Minimum characters each message block keeps, honoured even past hooksContextMaxChars so both always render.";
    };

    dailyTranscriptLimit = lib.mkOption {
      type = lib.types.ints.positive;
      default = 200;
      description = "Maximum messages kept in the in memory daily transcript.";
    };

    hooks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether this hook is active.";
            };

            targetGroup = lib.mkOption {
              type = lib.types.enum [
                "group"
                "direct"
                "desktop"
                "all"
              ];
              default = "group";
              description = "Which built-in destination the hook posts to, group for the main group, direct for every contact direct chat, desktop for every desktop session, or all for every chat including desktop sessions.";
            };

            targetContact = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Single contact name the hook posts to instead of a built-in destination, null uses targetGroup.";
            };

            desktop = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Deliver to the target contact in its desktop chat session instead of its Signal direct chat, only valid together with targetContact.";
            };

            startTime = lib.mkOption {
              type = lib.types.nullOr (lib.types.strMatching "([01][0-9]|2[0-3]):[0-5][0-9]");
              default = null;
              description = "Local start of the fire window as HH:MM, mutually exclusive with time.";
            };

            endTime = lib.mkOption {
              type = lib.types.nullOr (lib.types.strMatching "([01][0-9]|2[0-3]):[0-5][0-9]");
              default = null;
              description = "Local end of the fire window as HH:MM, an end not after the start wraps past midnight, mutually exclusive with time.";
            };

            time = lib.mkOption {
              type = lib.types.nullOr (lib.types.strMatching "([01][0-9]|2[0-3]):[0-5][0-9]");
              default = null;
              description = "Exact local fire time as HH:MM that fires at that moment when the gates pass, mutually exclusive with startTime and endTime.";
            };

            probability = lib.mkOption {
              type = lib.types.numbers.between 0.0 1.0;
              default = 1.0;
              description = "Chance from zero to one that the hook rolls a fire time for a window.";
            };

            minUserInteractions = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 0;
              description = "Minimum non bot messages that day before the hook may fire.";
            };

            whenTriggered = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    instruction = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Instruction sent to Home Assistant when this trigger is chosen, mutually exclusive with message.";
                    };

                    message = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Static text posted as is when this trigger is chosen, mutually exclusive with instruction.";
                    };

                    title = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Optional title for the posted message, null means no title.";
                    };

                    url = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Optional link appended to the posted message, null means no link.";
                    };
                  };
                }
              );
              default = [ ];
              description = "Trigger variants for the hook, one is picked at random each fire.";
            };

            contextFirstMessages = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 5;
              description = "Earliest messages of the day always included in the hook transcript.";
            };

            contextRecentMessages = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 15;
              description = "Newest messages of the day included in the hook transcript.";
            };

            onBlock = lib.mkOption {
              type = lib.types.enum [
                "reschedule"
                "skip"
              ];
              default = "reschedule";
              description = "What to do when a fire time is blocked, reschedule pushes it later or skip drops it.";
            };

            agentId = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Home Assistant conversation agent suffix for this hook, null falls back to hooksAgentId.";
            };

            minSecondsSinceBotMessage = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.unsigned;
              default = null;
              description = "Minimum seconds since the last bot message before this hook may fire, null falls back to the global minSecondsSinceBotMessage.";
            };

            minSecondsSinceUserMessage = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.unsigned;
              default = null;
              description = "Minimum seconds since the last user message before this hook may fire, null falls back to the global minSecondsSinceUserMessage.";
            };

            sendErrorsIntoChat = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Post Home Assistant error replies into the group instead of only logging and skipping.";
            };

            includeMemory = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Prepend the memory context block to the hook prompt before sending it to Home Assistant.";
            };

            runOnlyIfFiredToday = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Names of hooks that must all have fired today before this hook may fire, it waits inside its window until they do.";
            };

            skipIfFiredToday = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Names of hooks whose firing today makes this hook skip the day.";
            };
          };
        }
      );
      default = { };
      description = "Autonomous daily hooks that let the bot speak on its own in the main group, keyed by a name of your choice.";
    };

    transcription = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Transcribe inbound voice messages with the linux.services.whisper module and answer them like text messages, null follows whether that module is enabled.";
          };

          maxAttachmentBytes = lib.mkOption {
            type = lib.types.ints.positive;
            default = 5 * 1024 * 1024;
            description = "Largest audio attachment that is transcribed, anything bigger is discarded unheard, keep it low enough that shared audio files are rejected instead of transcribed.";
          };

          failureMessage = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when an audio attachment could not be transcribed.";
          };

          instruction = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Instruction prepended to a transcript so the answer tolerates recognition errors, wrapped by instructionTemplate.";
          };

          promptTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{instruction} {transcript}";
            description = "Format of the prompt built from a transcript, with the placeholders {instruction} and {transcript} substituted.";
          };

          attachmentRetentionMinutes = lib.mkOption {
            type = lib.types.ints.positive;
            default = 60;
            description = "Age in minutes after which the attachment sweeper deletes leftover attachment files.";
          };

          attachmentMaxBytesTotal = lib.mkOption {
            type = lib.types.ints.positive;
            default = 512 * 1024 * 1024;
            description = "Byte budget for the attachment directory, oldest files are deleted first once it is exceeded.";
          };
        };
      };
      default = { };
      description = "How the bot handles inbound voice messages and the attachment files they leave behind.";
    };

    messages = lib.mkOption {
      type = lib.types.submodule {
        options = {
          haUnreachable = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when the Home Assistant conversation request fails.";
          };

          haUnexpectedResponse = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when Home Assistant answers with an unexpected payload.";
          };

          haAgentFailed = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when Home Assistant answers but its conversation agent keeps failing after all retries.";
          };

          haToolCallArtifact = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when the conversation agent writes a tool call into its answer instead of running it.";
          };

          statusTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Body of the status reply, with the placeholders {name}, {account}, {homeAssistant}, {budget}, {maybeBudget}, {hooks} and {memory} substituted.";
          };

          statusBudgetEntryTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Format of a single budget line in the status reply, with the placeholders {contact}, {used} and {limit} substituted.";
          };

          statusUnknownContactLabel = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Contact label for the shared budget line covering desktop users that map to no configured contact.";
          };

          chatTypingTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Desktop chat typing indicator, with the placeholder {name} substituted by the bot given name.";
          };

          statusMaybeBudgetTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Format of the maybe budget line in the status reply, with the placeholders {remaining} and {limit} substituted.";
          };

          statusMaybeBudgetDisabled = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Maybe budget text in the status reply when the group filter is disabled.";
          };

          statusHooksDisabled = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Hooks text in the status reply when no hooks are configured.";
          };

          statusHooksTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Format of the hooks section in the status reply, with the placeholders {used}, {limit} and {entries} substituted.";
          };

          statusHookEntryTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{hook}: {state}";
            description = "Format of a single hook line in the status reply, with the placeholders {hook} and {state} substituted.";
          };

          statusHookFired = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Hook state wording when the hook already fired this window, with {window} substituted.";
          };

          statusHookScheduled = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Hook state wording when a fire time is rolled, with {time} and {window} substituted.";
          };

          statusHookIdle = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Hook state wording when the hook has no fire time this window, with {window} substituted.";
          };

          statusAccountOk = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Status wording used when the signal-cli account data is complete.";
          };

          statusAccountMissing = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Status wording used when signal-cli account data is missing.";
          };

          statusHaReachable = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Status wording used when Home Assistant answers.";
          };

          statusHaUnreachable = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Status wording used when Home Assistant does not answer.";
          };

          statusMemoryDisabled = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Memory section text in the status reply when memory recording is disabled.";
          };

          statusMemoryTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Memory section text in the status reply, with the placeholders {summaries}, {today_entries} and {next} substituted.";
          };

          statusMemoryNoNext = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Value substituted for {next} in statusMemoryTemplate when no entries have been recorded yet in the current period.";
          };

          memNoPriorSummaries = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Placeholder injected into the summarization prompt when no prior period summaries exist yet.";
          };

          helpEntryTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{command} - {description}";
            description = "Format of a single help line, with the placeholders {command} and {description} substituted.";
          };

          helpStatusDescription = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Help text describing the status command.";
          };

          helpHelpDescription = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Help text describing the help command.";
          };

          helpMemoryDescription = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Help text describing the memory command shown to admin contacts.";
          };

          memoryEmpty = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply when /memory is called but no memory has been stored yet.";
          };

          helpShortcutTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Format of the command part of a help line for a command that has a shortcut, with the placeholders {command} and {shortcut} substituted.";
          };

          quoteContextTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Prompt sent to Home Assistant when a reply refers to a message outside the current conversation, with the placeholders {author}, {message} and {text} substituted.";
          };

          quoteContextBot = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Wording used for {author} when the referenced message came from the bot itself.";
          };

          quoteContextUser = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Wording used for {author} when the referenced message came from an unknown sender.";
          };

          groupSpeakerTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Prompt sent to Home Assistant for a group message, with the placeholders {author} and {text} substituted.";
          };

          contextRecapTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Prompt sent to Home Assistant when the earlier conversation has to be restated, with the placeholders {transcript} and {text} substituted.";
          };

          contextRecapEntryTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Format of a single line of the restated conversation, with the placeholders {author} and {message} substituted.";
          };

          scriptRecapTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{text} ({description})";
            description = "Format of a script command in the restated conversation, with the placeholders {text} and {description} substituted.";
          };

          budgetExhausted = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent once when a sender exhausts the daily request budget.";
          };

          scriptCompleted = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when a script command finished and returned no response of its own, with the placeholders {command} and {argument} substituted.";
          };

          scriptFailed = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when a script command could not be run, with the placeholders {command} and {argument} substituted.";
          };

          scriptArgumentRequired = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when a script command that requires a value was sent without one, with the placeholder {command} substituted.";
          };

          scriptArgumentNotAllowed = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when a value was sent to a script command that takes none, with the placeholder {command} substituted.";
          };

          scriptArgumentTooLong = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when the value of a script command exceeds its length limit, with the placeholder {command} substituted.";
          };

          scriptShortcutInvalid = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when a message starts with a command shortcut not followed (after optional spaces) by a letter or a digit, with the placeholders {command} and {shortcut} substituted.";
          };

          scriptArgumentInvalid = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reply sent when the value of a script command contains control characters, with the placeholder {command} substituted.";
          };
        };
      };
      default = { };
      description = "Texts the bot sends into Signal on its own behalf.";
    };

    scriptCommands = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            script = lib.mkOption {
              type = lib.types.str;
              description = "Object id of the Home Assistant script to run, without the script domain prefix.";
            };

            description = lib.mkOption {
              type = lib.types.str;
              default = "Run a Home Assistant script.";
              description = "Help text describing the command.";
            };

            argument = lib.mkOption {
              type = lib.types.enum [
                "none"
                "optional"
                "required"
              ];
              default = "none";
              description = "Whether the command accepts a value after the command name.";
            };

            argumentVariable = lib.mkOption {
              type = lib.types.str;
              default = "argument";
              description = "Name of the script variable the value is passed as.";
            };

            maxArgumentLength = lib.mkOption {
              type = lib.types.ints.positive;
              default = 200;
              description = "Maximum accepted length of the value in characters.";
            };

            async = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Start the script through script.turn_on and answer as soon as it was started instead of waiting for it to finish, which also gives up any script response.";
            };

            timeoutSeconds = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = "Seconds to wait for this script to finish, overriding the global haTimeoutSeconds.";
            };

            completedMessage = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Reply sent when this command finished and returned no response of its own, overriding the global scriptCompleted message.";
            };

            failedMessage = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Reply sent when this command could not be run, overriding the global scriptFailed message.";
            };

            shortcut = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional single special character that runs this command when a message starts with it followed directly by a letter or a digit, with the rest of the message used as the value.";
            };

            conversational = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "When enabled, the command argument is enriched with the current conversation history and memory before being passed to the Home Assistant script, exactly as if the user sent a normal message.";
            };

            adminOnly = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Restrict this command to contacts marked as admin, silently ignoring it for all others.";
            };

          };
        }
      );
      default = { };
      description = "Slash commands that run Home Assistant scripts, keyed by the command name without its leading slash.";
    };

    syncIntervalMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Interval in minutes between main group membership reconciliation runs.";
    };

    additionalUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional usernames that also get their own copy of the send API token.";
    };

    script = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The signal-bot-send script derivation, set in both contexts while the module is enabled";
    };

    sendList = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo (lib.types.listOf lib.types.str));
      default = null;
      description = "Function to generate a signal-bot-send command as a list of arguments";
    };

    send = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.str);
      default = null;
      description = "Function to generate a signal-bot-send shell command string";
    };

    memory = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Opt-in switch that enables daily memory recording, summarization, and injection into every conversational reply.";
          };

          retentionDays = lib.mkOption {
            type = lib.types.ints.positive;
            default = 3;
            description = "Number of period summaries kept before the oldest is trimmed.";
          };

          periodSeconds = lib.mkOption {
            type = lib.types.ints.positive;
            default = 86400;
            description = "Length in seconds of one memory period, transcripts are summarized and rolled over at the end of each period.";
          };

          agentId = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Suffix of the Home Assistant conversation agent used for daily summarization, null falls back to haAgentId.";
          };

          dailyLimit = lib.mkOption {
            type = lib.types.ints.positive;
            default = 200;
            description = "Maximum raw transcript entries buffered per chat per period before older ones are dropped.";
          };

          instruction = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "System instruction sent to the summarization agent when building the period memory entry.";
          };

          promptTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Template for the summarization prompt with placeholders {instruction}, {today}, {prior_summaries} and {today_transcripts}.";
          };

          chatBlockTemplate = lib.mkOption {
            type = lib.types.str;
            default = ''
              === {chat} ===
              {transcript}
            '';
            description = "Template wrapping one chat's raw transcript with its readable label for the summarization prompt, with placeholders {chat} and {transcript}.";
          };

          entryTemplate = lib.mkOption {
            type = lib.types.str;
            default = ''
              [{date}]
              {summary}
            '';
            description = "Template rendering a single stored period summary with its date label, with placeholders {date} and {summary}.";
          };

          contextTemplate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Template wrapping the joined period summaries injected into every conversational prompt, with placeholders {memory} and {channel} (resolved to the current channel name).";
          };
        };
      };
      default = { };
      description = "Daily memory recording, summarization, and context injection.";
    };
  };

  module =
    let
      stateDir = "/var/lib/nx-signal-bot";
      signalCliDataDir = "${stateDir}/signal-cli";
      socketPath = "${stateDir}/daemon.sock";
      stateSubDir = "${stateDir}/state";
      bootstrapLockFile = "${stateDir}/bootstrap.lock";

      phoneNumberSecretName = "signal-bot-phone-number";
      haTokenSecretName = "signal-bot-ha-token";
      apiTokenSecretName = "signal-bot-api-token";
      contactsSecretName = "signal-bot-contacts";

      apiTokenPath = "/run/secrets/${apiTokenSecretName}";
      userApiTokenPathPrefix = "/run/${apiTokenSecretName}-";

      signalBotSendScript =
        config:
        let
          moduleConfig = config.nx.linux.services.signal-bot;
          apiPort = moduleConfig.apiPort;
          configured = moduleConfig.configured;
        in
        pkgs.writeShellScriptBin "signal-bot-send" ''
          set -euo pipefail

          ${lib.optionalString (!configured) ''
            echo "Error: the signal-bot module is not configured on this host!" >&2
            exit 1
          ''}
          if [[ $EUID -eq 0 ]]; then
              TOKEN_FILE="${apiTokenPath}"
          else
              TOKEN_FILE="${userApiTokenPathPrefix}$(${pkgs.coreutils}/bin/id -un)"
          fi

          show_usage() {
              echo "Usage: $0 --message <message> [--title <title>] [--url <url>] [--recipient <contact-name>] [--no-context]" >&2
              echo "       $0 --message-file <path> [--title <title>] [--url <url>] [--recipient <contact-name>] [--no-context]" >&2
              echo "       $0 --stdin  (reads the complete JSON payload from stdin)" >&2
              echo "       --no-context keeps the message out of the conversation the bot carries over" >&2
          }

          require_value() {
              if [[ $2 -lt 2 ]]; then
                  echo "Error: $1 requires a value!" >&2
                  show_usage
                  exit 1
              fi
          }

          MESSAGE=""
          MESSAGE_FILE=""
          TITLE=""
          URL=""
          RECIPIENT=""
          HAVE_MESSAGE=0
          READ_STDIN=0
          CONTEXT=1

          while [[ $# -gt 0 ]]; do
              case $1 in
                  -h|--help)
                      show_usage
                      exit 0
                      ;;
                  --stdin)
                      READ_STDIN=1
                      shift
                      ;;
                  --message)
                      require_value "$1" $#
                      MESSAGE="$2"
                      HAVE_MESSAGE=1
                      shift 2
                      ;;
                  --message-file)
                      require_value "$1" $#
                      MESSAGE_FILE="$2"
                      HAVE_MESSAGE=1
                      shift 2
                      ;;
                  --title)
                      require_value "$1" $#
                      TITLE="$2"
                      shift 2
                      ;;
                  --url)
                      require_value "$1" $#
                      URL="$2"
                      shift 2
                      ;;
                  --recipient)
                      require_value "$1" $#
                      RECIPIENT="$2"
                      shift 2
                      ;;
                  --no-context)
                      CONTEXT=0
                      shift
                      ;;
                  *)
                      echo "Unknown option: $1" >&2
                      show_usage
                      exit 1
                      ;;
              esac
          done

          if [[ -n "$MESSAGE" && -n "$MESSAGE_FILE" ]]; then
              echo "Error: --message and --message-file are mutually exclusive!" >&2
              show_usage
              exit 1
          fi

          if [[ ! -r "$TOKEN_FILE" ]]; then
              echo "Error: cannot read the signal-bot API token at $TOKEN_FILE!" >&2
              exit 1
          fi

          TOKEN=$(<"$TOKEN_FILE")
          if [[ ! "$TOKEN" =~ ^[A-Za-z0-9._~+/=-]+$ ]]; then
              echo "Error: the signal-bot API token is empty or contains unsupported characters!" >&2
              exit 1
          fi

          WORKDIR=$(${pkgs.coreutils}/bin/mktemp -d)
          trap '${pkgs.coreutils}/bin/rm -rf "$WORKDIR"' EXIT

          if [[ $READ_STDIN -eq 1 ]]; then
              if [[ $HAVE_MESSAGE -eq 1 || -n "$MESSAGE_FILE" || -n "$TITLE" || -n "$URL" || -n "$RECIPIENT" || $CONTEXT -eq 0 ]]; then
                  echo "Error: --stdin cannot be combined with the other options!" >&2
                  show_usage
                  exit 1
              fi

              ${pkgs.coreutils}/bin/cat >"$WORKDIR/payload.json"

              if ! ${pkgs.jq}/bin/jq -e \
                  'type == "object" and (.message | type) == "string" and (.message | length) > 0' \
                  "$WORKDIR/payload.json" >/dev/null; then
                  echo "Error: --stdin payload must be a JSON object with a non empty message!" >&2
                  exit 1
              fi
          else
              if [[ $HAVE_MESSAGE -eq 0 ]]; then
                  echo "Error: --message or --message-file is required!" >&2
                  show_usage
                  exit 1
              fi

              if [[ -n "$MESSAGE_FILE" ]]; then
                  if [[ ! -r "$MESSAGE_FILE" ]]; then
                      echo "Error: cannot read the message file $MESSAGE_FILE!" >&2
                      exit 1
                  fi
                  ${pkgs.coreutils}/bin/cat "$MESSAGE_FILE" >"$WORKDIR/message"
              else
                  printf '%s' "$MESSAGE" >"$WORKDIR/message"
              fi

              if [[ ! -s "$WORKDIR/message" ]]; then
                  echo "Error: the message must not be empty!" >&2
                  exit 1
              fi

              printf '%s' "$TITLE" >"$WORKDIR/title"
              printf '%s' "$URL" >"$WORKDIR/url"
              printf '%s' "$RECIPIENT" >"$WORKDIR/recipient"

              ${pkgs.jq}/bin/jq -n \
                  --rawfile message "$WORKDIR/message" \
                  --rawfile title "$WORKDIR/title" \
                  --rawfile url "$WORKDIR/url" \
                  --rawfile recipient "$WORKDIR/recipient" \
                  --argjson context "$CONTEXT" \
                  '{message: $message}
                   + (if $title != "" then {title: $title} else {} end)
                   + (if $url != "" then {url: $url} else {} end)
                   + (if $recipient != "" then {recipient: $recipient} else {} end)
                   + (if $context == 0 then {context: false} else {} end)' \
                  >"$WORKDIR/payload.json"
          fi

          printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" \
              | ${pkgs.curl}/bin/curl -K - -fsS -m 10 -X POST \
                  -H "Content-Type: application/json" \
                  --data-binary @"$WORKDIR/payload.json" \
                  "http://127.0.0.1:${toString apiPort}/v1/send" >/dev/null
        '';
    in
    {
      linux.init =
        config:
        let
          sendListFn =
            {
              message ? null,
              messageFile ? null,
              title ? null,
              url ? null,
              recipient ? null,
              context ? true,
              path ? null,
            }:
            let
              script = config.nx.linux.services.signal-bot.script;
              scriptCmd =
                if !self.isEnabled then
                  null
                else if path != null then
                  path
                else if script != null then
                  "${script}/bin/signal-bot-send"
                else
                  "signal-bot-send";
              messageArgs =
                if messageFile != null then
                  [
                    "--message-file"
                    messageFile
                  ]
                else if message != null then
                  [
                    "--message"
                    message
                  ]
                else
                  throw "signal-bot sendList requires either message or messageFile!";
            in
            if scriptCmd == null then
              [ ]
            else
              [ scriptCmd ]
              ++ messageArgs
              ++ lib.optionals (title != null) [
                "--title"
                title
              ]
              ++ lib.optionals (url != null) [
                "--url"
                url
              ]
              ++ lib.optionals (recipient != null) [
                "--recipient"
                recipient
              ]
              ++ lib.optionals (!context) [ "--no-context" ];
        in
        {
          nx.linux.services.signal-bot.sendList = sendListFn;

          nx.linux.services.signal-bot.send =
            args:
            let
              cmdList = sendListFn args;
              message =
                if args.messageFile or null != null then
                  throw "signal-bot send does not support messageFile, use sendList instead!"
                else if args.message or null == null then
                  throw "signal-bot send requires message!"
                else
                  args.message;
              payload = builtins.toJSON (
                {
                  inherit message;
                }
                // lib.optionalAttrs (args.title or null != null) { inherit (args) title; }
                // lib.optionalAttrs (args.url or null != null) { inherit (args) url; }
                // lib.optionalAttrs (args.recipient or null != null) { inherit (args) recipient; }
                // lib.optionalAttrs ((args.context or true) == false) { context = false; }
              );
              stdinCmd = lib.escapeShellArgs [
                (builtins.head cmdList)
                "--stdin"
              ];
            in
            if cmdList == [ ] then ":" else "printf '%s' ${lib.escapeShellArg payload} | ${stdinCmd} || true";
        };

      linux.enabled = config: {
        nx.linux.services.signal-bot.script = signalBotSendScript config;
        nx.packages.extra = [ pkgs.signal-cli ];
      };

      linux.system =
        {
          config,
          configured,
          mainGroupName,
          profileGivenName,
          profileAbout,
          enableAvatar,
          profileAvatar,
          enableGroupAvatar,
          groupAvatar,
          haUrl,
          haLanguage,
          haAgentId,
          haTimeoutSeconds,
          apiPort,
          chatEnable,
          chatRingBufferSize,
          chatRingBufferTtlHours,
          chatTimestampFormat,
          chatRecipients,
          chatDefaultRecipient,
          chatFontSize,
          chatFontFamily,
          queueMaxDepth,
          maxSendsPerHour,
          maxSendsPerMinute,
          maxBudgetPerSenderPerDay,
          budgetInputChars,
          budgetOutputChars,
          inboundMaxAgeMinutes,
          maxSplitMessages,
          boldTitle,
          markdown,
          botLanguage,
          instructionTemplate,
          quoteReplies,
          typingIndicatorDelaySeconds,
          groupFilter,
          conversationFollowUpSeconds,
          nightFollowUpSeconds,
          nightStartHour,
          nightEndHour,
          haSessionSeconds,
          contextMaxMessages,
          contextMaxChars,
          reactions,
          transcription,
          messages,
          scriptCommands,
          syncIntervalMinutes,
          additionalUsers,
          additionalHookSendsPerDay,
          minSecondsBetweenHooks,
          minSecondsSinceBotMessage,
          minSecondsSinceUserMessage,
          hooksInstruction,
          hooksPromptTemplate,
          hooksTranscriptSeparator,
          hooksTranscriptSeparatorTemplate,
          hooksAgentId,
          hooksContextMaxChars,
          hooksBlockMinChars,
          dailyTranscriptLimit,
          memory,
          hooks,
          script,
          ...
        }:
        let
          groupIdFile = "${stateSubDir}/group-id";
          recipientsFile = "${stateSubDir}/recipients.json";
          profileStateFile = "${stateSubDir}/profile.json";
          handledFile = "${stateSubDir}/handled.json";
          sendStateFile = "${stateSubDir}/send-rate.json";
          senderBudgetFile = "${stateSubDir}/sender-budget.json";
          hookStateFile = "${stateSubDir}/hooks.json";
          chatThreadsFile = "${stateSubDir}/chat-threads.json";
          memoryStateFile = "${stateSubDir}/memory.json";

          langTexts = texts.${botLanguage};
          pickText = value: key: if value != null then value else langTexts.${key};
          resolvedMeanings = if reactions.meanings != null then reactions.meanings else langTexts.reMeanings;

          secretPath = name: config.sops.secrets.${name}.path;

          whisperCfg = config.nx.linux.services.whisper;
          attachmentsDir = "${signalCliDataDir}/attachments";
          transcriptionActive =
            if transcription.enable == null then configured && whisperCfg.enable else transcription.enable;
          transcribeCommand =
            if whisperCfg.transcribeList == null then [ ] else whisperCfg.transcribeList audioPlaceholder;

          bridgeScript = self.file "bridge.py";
          desktopModuleFile = self.file "desktop.py";
          chatPageFile = self.file "chat.html";
          chatScriptFile = self.file "chat.js";
          chatThemeFile =
            let
              c = config.nx.preferences.theme.colors;
              userBg = c.blocks.primary.background.html;
              userFg = c.blocks.primary.foreground.html;
              accent = c.main.foregrounds.primary.html;
              border = c.semantic.comment.html;
              failedBg = c.blocks.critical.background.html;
              failedFg = c.blocks.critical.foreground.html;
            in
            pkgs.writeText "signal-bot-theme.css" ''
              :root {
                --user: ${userBg};
                --accent: ${accent};
                --bot-name: ${userFg};
              }
              button.send { background: ${userBg}; color: ${userFg}; }
              textarea { border-color: ${border}; }
              textarea:focus { outline: 1px solid ${border}; }
              .msg.user.failed { background: ${failedBg}; color: ${failedFg}; }
              @keyframes flashFailed {
                0%, 100% { box-shadow: none; }
                50% { box-shadow: inset 0 0 0 9999px color-mix(in srgb, ${failedBg} 55%, transparent); }
              }
            '';
          pythonEnv = pkgs.python3.withPackages (ps: [
            ps.flask
            ps.pyyaml
            ps.waitress
          ]);

          effectiveProfileGivenName =
            if profileGivenName != null then profileGivenName else self.host.hostname;

          effectiveBotLabel =
            if messages.quoteContextBot != null then
              messages.quoteContextBot
            else if profileGivenName != null then
              profileGivenName
            else
              pickText null "quoteContextBot";

          botConfigJson = pkgs.writeText "signal-bot-config.json" (
            builtins.toJSON {
              socket_path = socketPath;
              account_file = secretPath phoneNumberSecretName;
              signal_cli_data_dir = signalCliDataDir;
              group_id_file = groupIdFile;
              recipients_file = recipientsFile;
              profile_state_file = profileStateFile;
              handled_file = handledFile;
              send_state_file = sendStateFile;
              sender_budget_file = senderBudgetFile;
              hook_state_file = hookStateFile;
              memory_state_file = memoryStateFile;
              memory_enable = memory.enable;
              memory_retention_days = memory.retentionDays;
              memory_period_seconds = memory.periodSeconds;
              memory_agent_id = effectiveMemoryAgentId;
              memory_daily_limit = memory.dailyLimit;
              memory_instruction = pickText memory.instruction "memInstruction";
              memory_prompt_template = pickText memory.promptTemplate "memPromptTemplate";
              memory_chat_block_template = memory.chatBlockTemplate;
              memory_entry_template = memory.entryTemplate;
              memory_context_template = pickText memory.contextTemplate "memContextTemplate";
              chat_enable = chatEnable;
              chat_ring_buffer_size = chatRingBufferSize;
              chat_ring_buffer_ttl_hours = chatRingBufferTtlHours;
              chat_timestamp_format = chatTimestampFormat;
              chat_recipients = chatRecipients;
              chat_default_recipient = chatDefaultRecipient;
              chat_font_size = chatFontSize;
              chat_font_family = chatFontFamily;
              chat_typing_text = lib.replaceStrings [ "{name}" ] [ effectiveProfileGivenName ] (
                pickText messages.chatTypingTemplate "chatTypingTemplate"
              );
              chat_threads_file = chatThreadsFile;
              desktop_module_file = desktopModuleFile;
              chat_page_file = chatPageFile;
              chat_script_file = chatScriptFile;
              chat_theme_file = chatThemeFile;
              main_group_name = mainGroupName;
              profile_given_name = effectiveProfileGivenName;
              profile_about = profileAbout;
              profile_avatar = if enableAvatar then self.profile.filesPath profileAvatar else null;
              group_avatar = if enableGroupAvatar then self.profile.filesPath groupAvatar else null;
              ha_url = haUrl;
              ha_language = haLanguage;
              bot_language = botLanguage;
              ha_agent_id = haAgentIdResolved;
              ha_timeout_seconds = haTimeoutSeconds;
              ha_token_file = secretPath haTokenSecretName;
              api_token_file = secretPath apiTokenSecretName;
              contacts_file = secretPath contactsSecretName;
              api_port = apiPort;
              queue_max_depth = queueMaxDepth;
              max_sends_per_hour = maxSendsPerHour;
              max_sends_per_minute = maxSendsPerMinute;
              max_budget_per_sender_per_day = maxBudgetPerSenderPerDay;
              budget_input_chars = budgetInputChars;
              budget_output_chars = budgetOutputChars;
              inbound_max_age_seconds = inboundMaxAgeMinutes * 60;
              max_split_messages = maxSplitMessages;
              bold_title = boldTitle;
              inherit markdown;
              instruction_template = instructionTemplate;
              quote_replies = quoteReplies;
              typing_indicator_delay_seconds = typingIndicatorDelaySeconds;
              group_filter = {
                inherit (groupFilter) enable instruction;
                agent_id = if groupFilter.agentId == null then null else "conversation.${groupFilter.agentId}";
                prompt_template = groupFilter.promptTemplate;
                context_messages = groupFilter.contextMessages;
                context_template = pickText groupFilter.contextTemplate "gfContextTemplate";
                silent_answers = groupFilter.silentAnswers;
                maybe_answers = groupFilter.maybeAnswers;
                maybe_probability = groupFilter.maybeProbability;
                maybe_budget = groupFilter.maybeBudget;
                maybe_budget_seconds = groupFilter.maybeBudgetSeconds;
                maybe_recency_seconds = groupFilter.maybeRecencySeconds;
                maybe_recency_grace_seconds = groupFilter.maybeRecencyGraceSeconds;
                maybe_budget_boost_floor = groupFilter.maybeBudgetBoostFloor;
              };
              conversation_follow_up_seconds = conversationFollowUpSeconds;
              night_follow_up_seconds = nightFollowUpSeconds;
              night_start_hour = nightStartHour;
              night_end_hour = nightEndHour;
              ha_session_seconds = haSessionSeconds;
              context_max_messages = contextMaxMessages;
              context_max_chars = contextMaxChars;
              additional_hook_sends_per_day = additionalHookSendsPerDay;
              min_seconds_between_hooks = minSecondsBetweenHooks;
              min_seconds_since_bot_message = minSecondsSinceBotMessage;
              min_seconds_since_user_message = minSecondsSinceUserMessage;
              hooks_instruction = lib.replaceStrings [ "{name}" ] [ effectiveBotLabel ] (
                pickText hooksInstruction "hkInstruction"
              );
              hooks_prompt_template = hooksPromptTemplate;
              hooks_transcript_separator = pickText hooksTranscriptSeparator "hkTranscriptSeparator";
              hooks_transcript_separator_template = hooksTranscriptSeparatorTemplate;
              hooks_context_max_chars = hooksContextMaxChars;
              hooks_block_min_chars = hooksBlockMinChars;
              daily_transcript_limit = dailyTranscriptLimit;
              hooks = lib.mapAttrs (_: hook: {
                enable = hook.enable;
                target_group = hook.targetGroup;
                target_contact = hook.targetContact;
                desktop = hook.desktop;
                start_time = hook.startTime;
                end_time = hook.endTime;
                exact_time = hook.time;
                probability = hook.probability;
                min_user_interactions = hook.minUserInteractions;
                triggers = map (trigger: {
                  instruction = trigger.instruction;
                  message = trigger.message;
                  title = trigger.title;
                  url = trigger.url;
                }) hook.whenTriggered;
                context_first_messages = hook.contextFirstMessages;
                context_recent_messages = hook.contextRecentMessages;
                on_block = hook.onBlock;
                agent_id = if hook.agentId != null then "conversation.${hook.agentId}" else effectiveHooksAgentId;
                min_seconds_since_bot_message = hook.minSecondsSinceBotMessage;
                min_seconds_since_user_message = hook.minSecondsSinceUserMessage;
                send_errors_into_chat = hook.sendErrorsIntoChat;
                include_memory = hook.includeMemory;
                run_only_if_fired_today = hook.runOnlyIfFiredToday;
                skip_if_fired_today = hook.skipIfFiredToday;
              }) enabledHooks;
              reactions = {
                enable = reactions.enable;
                target_max_age_seconds = reactions.targetMaxAgeSeconds;
                target_max_messages = reactions.targetMaxMessages;
                instruction = pickText reactions.instruction "reInstruction";
                prompt_template = reactions.promptTemplate;
                fallback = pickText reactions.fallback "reFallback";
                emoji = lib.mapAttrs (name: emoji: {
                  inherit emoji;
                  meaning = resolvedMeanings.${name} or "";
                }) reactions.emoji;
              };
              transcription = {
                enable = transcriptionActive;
                attachments_dir = attachmentsDir;
                audio_placeholder = audioPlaceholder;
                transcribe_command = transcribeCommand;
                ffmpeg = helpers.packageFile args pkgs.ffmpeg-headless "bin/ffmpeg";
                timeout_seconds = whisperCfg.timeoutSeconds;
                max_duration_seconds = whisperCfg.maxDurationSeconds;
                max_attachment_bytes = transcription.maxAttachmentBytes;
                failure_message = pickText transcription.failureMessage "trFailureMessage";
                instruction = pickText transcription.instruction "trInstruction";
                prompt_template = transcription.promptTemplate;
              };
              messages = {
                ha_unreachable = pickText messages.haUnreachable "haUnreachable";
                ha_unexpected_response = pickText messages.haUnexpectedResponse "haUnexpectedResponse";
                ha_agent_failed = pickText messages.haAgentFailed "haAgentFailed";
                ha_tool_call_artifact = pickText messages.haToolCallArtifact "haToolCallArtifact";
                status_template = pickText messages.statusTemplate "statusTemplate";
                status_budget_entry_template = pickText messages.statusBudgetEntryTemplate "statusBudgetEntryTemplate";
                status_unknown_contact_label = pickText messages.statusUnknownContactLabel "statusUnknownContactLabel";
                status_maybe_budget_template = pickText messages.statusMaybeBudgetTemplate "statusMaybeBudgetTemplate";
                status_maybe_budget_disabled = pickText messages.statusMaybeBudgetDisabled "statusMaybeBudgetDisabled";
                status_hooks_disabled = pickText messages.statusHooksDisabled "statusHooksDisabled";
                status_hooks_template = pickText messages.statusHooksTemplate "statusHooksTemplate";
                status_hook_entry_template = messages.statusHookEntryTemplate;
                status_hook_fired = pickText messages.statusHookFired "statusHookFired";
                status_hook_scheduled = pickText messages.statusHookScheduled "statusHookScheduled";
                status_hook_idle = pickText messages.statusHookIdle "statusHookIdle";
                status_account_ok = pickText messages.statusAccountOk "statusAccountOk";
                status_account_missing = pickText messages.statusAccountMissing "statusAccountMissing";
                status_ha_reachable = pickText messages.statusHaReachable "statusHaReachable";
                status_ha_unreachable = pickText messages.statusHaUnreachable "statusHaUnreachable";
                status_memory_disabled = pickText messages.statusMemoryDisabled "statusMemoryDisabled";
                status_memory_template = pickText messages.statusMemoryTemplate "statusMemoryTemplate";
                status_memory_no_next = pickText messages.statusMemoryNoNext "statusMemoryNoNext";
                mem_no_prior_summaries = pickText messages.memNoPriorSummaries "memNoPriorSummaries";
                help_entry_template = messages.helpEntryTemplate;
                help_status_description = pickText messages.helpStatusDescription "helpStatusDescription";
                help_help_description = pickText messages.helpHelpDescription "helpHelpDescription";
                help_memory_description = pickText messages.helpMemoryDescription "helpMemoryDescription";
                memory_empty = pickText messages.memoryEmpty "memoryEmpty";
                help_shortcut_template = pickText messages.helpShortcutTemplate "helpShortcutTemplate";
                quote_context_template = pickText messages.quoteContextTemplate "quoteContextTemplate";
                quote_context_bot = effectiveBotLabel;
                quote_context_user = pickText messages.quoteContextUser "quoteContextUser";
                group_speaker_template = pickText messages.groupSpeakerTemplate "groupSpeakerTemplate";
                context_recap_template = pickText messages.contextRecapTemplate "contextRecapTemplate";
                context_recap_entry_template = pickText messages.contextRecapEntryTemplate "contextRecapEntryTemplate";
                script_recap_template = messages.scriptRecapTemplate;
                budget_exhausted = pickText messages.budgetExhausted "budgetExhausted";
                script_completed = pickText messages.scriptCompleted "scriptCompleted";
                script_failed = pickText messages.scriptFailed "scriptFailed";
                script_argument_required = pickText messages.scriptArgumentRequired "scriptArgumentRequired";
                script_argument_not_allowed = pickText messages.scriptArgumentNotAllowed "scriptArgumentNotAllowed";
                script_argument_too_long = pickText messages.scriptArgumentTooLong "scriptArgumentTooLong";
                script_argument_invalid = pickText messages.scriptArgumentInvalid "scriptArgumentInvalid";
                script_shortcut_invalid = pickText messages.scriptShortcutInvalid "scriptShortcutInvalid";
              };
              script_commands = lib.mapAttrs' (
                name: command:
                lib.nameValuePair "/${name}" {
                  script = command.script;
                  description = command.description;
                  argument = command.argument;
                  argument_variable = command.argumentVariable;
                  max_argument_length = command.maxArgumentLength;
                  async = command.async;
                  timeout_seconds = command.timeoutSeconds;
                  completed_message = command.completedMessage;
                  failed_message = command.failedMessage;
                  shortcut = command.shortcut;
                  conversational = command.conversational;
                  admin_only = command.adminOnly;
                }
              ) scriptCommands;
            }
          );

          attachmentSweeper = pkgs.writeShellScript "nx-signal-bot-sweep-attachments" ''
            set -euo pipefail

            DIR="${attachmentsDir}"
            BUDGET=${toString transcription.attachmentMaxBytesTotal}

            if [ ! -d "$DIR" ]; then
                exit 0
            fi

            ${pkgs.findutils}/bin/find "$DIR"/ -mindepth 1 -type f \
                -mmin +${toString transcription.attachmentRetentionMinutes} -delete

            TOTAL=$(${pkgs.findutils}/bin/find "$DIR"/ -mindepth 1 -type f -printf '%s\n' \
                | ${pkgs.gawk}/bin/awk '{ sum += $1 } END { print sum + 0 }')

            if [ "$TOTAL" -le "$BUDGET" ]; then
                exit 0
            fi

            ${pkgs.findutils}/bin/find "$DIR"/ -mindepth 1 -type f -printf '%T@ %s %p\n' \
                | ${pkgs.coreutils}/bin/sort -n \
                | while read -r _ SIZE PATH_TO_DELETE; do
                    if [ "$TOTAL" -le "$BUDGET" ]; then
                        break
                    fi
                    ${pkgs.coreutils}/bin/rm -f -- "$PATH_TO_DELETE"
                    TOTAL=$((TOTAL - SIZE))
                done
          '';

          permissionsScript = pkgs.writeShellScript "nx-signal-bot-fix-permissions" ''
            set -euo pipefail

            if [ ! -d "${stateDir}" ]; then
                exit 0
            fi

            ${pkgs.coreutils}/bin/chown -R signal-bot:signal-bot "${stateDir}"
            ${pkgs.coreutils}/bin/chmod 0750 "${stateDir}"
            ${pkgs.findutils}/bin/find "${stateDir}" -mindepth 1 -type d \
                -exec ${pkgs.coreutils}/bin/chmod 0700 {} +
            ${pkgs.findutils}/bin/find "${stateDir}" -mindepth 1 -type f \
                -exec ${pkgs.coreutils}/bin/chmod 0600 {} +
          '';

          hardening = {
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictRealtime = true;
            LockPersonality = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
            ];
            UMask = "0077";
            ReadWritePaths = [ stateDir ];
          };

          haRest =
            if haUrl == null then
              null
            else if lib.hasPrefix "https://" haUrl then
              lib.removePrefix "https://" haUrl
            else if lib.hasPrefix "http://" haUrl then
              lib.removePrefix "http://" haUrl
            else
              null;

          haHostPort = if haRest == null then null else lib.head (lib.splitString "/" haRest);

          haHost =
            if haHostPort == null then
              null
            else if lib.hasPrefix "[" haHostPort then
              lib.head (lib.splitString "]" (lib.removePrefix "[" haHostPort))
            else
              lib.head (lib.splitString ":" haHostPort);

          haLoopbackHosts = [
            "localhost"
            "127.0.0.1"
            "::1"
          ];

          scriptShortcutChars = [
            "!"
            "?"
            "@"
            "#"
            "$"
            "%"
            "&"
            "*"
            "+"
            "="
            "~"
            "^"
            "."
            ","
            ":"
            ";"
            "_"
            "-"
            "|"
            "<"
            ">"
          ];

          scriptShortcuts = lib.filter (shortcut: shortcut != null) (
            lib.mapAttrsToList (_: command: command.shortcut) scriptCommands
          );

          reactionEmoji = lib.concatLists (lib.attrValues reactions.emoji);

          enabledHooks = lib.filterAttrs (_: hook: hook.enable) hooks;

          desktopHooks = lib.filterAttrs (_: hook: hook.desktop) enabledHooks;

          haAgentIdResolved = if haAgentId == null then null else "conversation.${haAgentId}";
          effectiveHooksAgentId =
            if hooksAgentId != null then "conversation.${hooksAgentId}" else haAgentIdResolved;
          effectiveMemoryAgentId =
            if memory.agentId != null then "conversation.${memory.agentId}" else haAgentIdResolved;

          tokenUsers = lib.unique ([ self.host.mainUser.username ] ++ additionalUsers);

          perUserTokenSecrets = lib.listToAttrs (
            map (username: {
              name = "${apiTokenSecretName}-${username}";
              value = {
                format = "binary";
                sopsFile = self.profile.secretsPath apiTokenSecretName;
                mode = "0440";
                owner = "root";
                group = config.users.users.${username}.group;
                path = "${userApiTokenPathPrefix}${username}";
              };
            }) tokenUsers
          );
        in
        {
          users.groups.signal-bot = { };
          users.users.signal-bot = {
            isSystemUser = true;
            group = "signal-bot";
            home = stateDir;
          };

          environment.persistence."${self.persist}" = {
            directories = [ stateDir ];
          };

          systemd.tmpfiles.settings."10-signal-bot" = {
            "${stateDir}".d = {
              mode = "0750";
              user = "signal-bot";
              group = "signal-bot";
            };
          }
          // lib.optionalAttrs self.host.impermanence {
            "${self.persist}${stateDir}".d = {
              mode = "0750";
              user = "signal-bot";
              group = "signal-bot";
            };
          };

          environment.systemPackages = lib.optionals (script != null) [ script ];

          assertions = lib.optionals configured [
            {
              assertion = haUrl != null;
              message = "linux.services.signal-bot requires haUrl to be set when configured is true!";
            }
            {
              assertion = haUrl == null || (haHost != null && haHost != "");
              message = "linux.services.signal-bot requires haUrl to start with http:// or https:// followed by a host!";
            }
            {
              assertion =
                haUrl == null
                || haHost == null
                || lib.hasPrefix "https://" haUrl
                || lib.elem haHost haLoopbackHosts;
              message = "linux.services.signal-bot requires haUrl to use https unless Home Assistant runs on loopback!";
            }
            {
              assertion = lib.all (name: builtins.match "[a-z0-9-]+" name != null) (lib.attrNames scriptCommands);
              message = "linux.services.signal-bot requires every scriptCommands name to consist of lowercase letters, digits or dashes without a leading slash!";
            }
            {
              assertion =
                !lib.any (
                  name:
                  lib.elem name [
                    "help"
                    "status"
                  ]
                ) (lib.attrNames scriptCommands);
              message = "linux.services.signal-bot cannot replace the built-in help and status commands through scriptCommands!";
            }
            {
              assertion = lib.all (command: builtins.match "[a-z0-9_]+" command.script != null) (
                lib.attrValues scriptCommands
              );
              message = "linux.services.signal-bot requires every scriptCommands script to be a Home Assistant object id of lowercase letters, digits or underscores!";
            }
            {
              assertion = lib.all (shortcut: lib.elem shortcut scriptShortcutChars) scriptShortcuts;
              message = "linux.services.signal-bot requires every scriptCommands shortcut to be one of ${lib.concatStrings scriptShortcutChars}!";
            }
            {
              assertion = lib.length scriptShortcuts == lib.length (lib.unique scriptShortcuts);
              message = "linux.services.signal-bot requires every scriptCommands shortcut to be used by only one command!";
            }
            {
              assertion = lib.attrNames reactions.emoji == lib.attrNames resolvedMeanings;
              message = "linux.services.signal-bot requires reactions emoji and reactions meanings to use exactly the same names!";
            }
            {
              assertion = lib.all (entry: entry != [ ]) (lib.attrValues reactions.emoji);
              message = "linux.services.signal-bot requires every reactions emoji entry to hold at least one emoji!";
            }
            {
              assertion = lib.all (meaning: meaning != "") (lib.attrValues resolvedMeanings);
              message = "linux.services.signal-bot requires every reactions meaning to be non empty!";
            }
            {
              assertion = lib.length reactionEmoji == lib.length (lib.unique reactionEmoji);
              message = "linux.services.signal-bot requires every reactions emoji to be used by only one entry!";
            }
            {
              assertion = lib.all (trigger: (trigger.instruction != null) != (trigger.message != null)) (
                lib.concatMap (hook: hook.whenTriggered) (lib.attrValues hooks)
              );
              message = "linux.services.signal-bot requires every hook trigger to set exactly one of instruction or message!";
            }
            {
              assertion = !chatEnable || configured;
              message = "linux.services.signal-bot requires configured to be true for the desktop chat channel!";
            }
            {
              assertion = !chatEnable || config.nx.linux.server.auth.enableOAuthProxy;
              message = "linux.services.signal-bot chatEnable requires linux.server.auth.enableOAuthProxy to be true so the chat channel is never exposed unauthenticated!";
            }
            {
              assertion = !chatEnable || chatDefaultRecipient == null || chatRecipients ? ${chatDefaultRecipient};
              message = "linux.services.signal-bot chatDefaultRecipient must be a name declared in chatRecipients!";
            }
            {
              assertion = !transcriptionActive || configured;
              message = "linux.services.signal-bot requires configured to be true for transcription!";
            }
            {
              assertion = !transcriptionActive || whisperCfg.enable;
              message = "linux.services.signal-bot requires the linux.services.whisper module for transcription!";
            }
            {
              assertion = !transcriptionActive || transcribeCommand != [ ];
              message = "linux.services.signal-bot got no transcribe command from the linux.services.whisper module!";
            }
            {
              assertion = lib.all (hook: hook.whenTriggered != [ ]) (lib.attrValues enabledHooks);
              message = "linux.services.signal-bot requires every enabled hook to define at least one whenTriggered entry!";
            }
            {
              assertion = lib.all (
                hook:
                (hook.time != null && hook.startTime == null && hook.endTime == null)
                || (hook.time == null && hook.startTime != null && hook.endTime != null)
              ) (lib.attrValues enabledHooks);
              message = "linux.services.signal-bot requires every hook to set either time or both startTime and endTime, never mixed!";
            }
            {
              assertion = lib.all (hook: lib.all (trigger: trigger.instruction != "") hook.whenTriggered) (
                lib.attrValues enabledHooks
              );
              message = "linux.services.signal-bot requires every hook trigger to hold a non empty instruction!";
            }
            {
              assertion = lib.all (
                name:
                lib.all (dep: builtins.hasAttr dep enabledHooks) (
                  enabledHooks.${name}.runOnlyIfFiredToday ++ enabledHooks.${name}.skipIfFiredToday
                )
              ) (lib.attrNames enabledHooks);
              message = "linux.services.signal-bot hook dependencies must reference enabled hooks that exist!";
            }
            {
              assertion = lib.all (
                name:
                !lib.elem name (enabledHooks.${name}.runOnlyIfFiredToday ++ enabledHooks.${name}.skipIfFiredToday)
              ) (lib.attrNames enabledHooks);
              message = "linux.services.signal-bot hooks must not list their own name as a dependency!";
            }
            {
              assertion = lib.all (hook: hook.targetContact == null || hook.targetGroup == "group") (
                lib.attrValues enabledHooks
              );
              message = "linux.services.signal-bot hooks must set either targetGroup or targetContact, not both!";
            }
            {
              assertion = lib.all (hook: hook.targetContact != null) (lib.attrValues desktopHooks);
              message = "linux.services.signal-bot hooks with desktop set to true require targetContact to be set!";
            }
            {
              assertion = desktopHooks == { } || chatEnable;
              message = "linux.services.signal-bot hooks with desktop set to true require the desktop chat channel chatEnable to be enabled!";
            }
            {
              assertion =
                chatEnable || lib.all (hook: hook.targetGroup != "desktop") (lib.attrValues enabledHooks);
              message = "linux.services.signal-bot hooks with targetGroup set to desktop require the desktop chat channel chatEnable to be enabled!";
            }
            {
              assertion = lib.all (hook: hook.targetContact == null || chatRecipients ? ${hook.targetContact}) (
                lib.attrValues desktopHooks
              );
              message = "linux.services.signal-bot hooks with desktop set to true require targetContact to be a name declared in chatRecipients!";
            }
          ];

          sops.secrets = lib.mkIf configured (
            {
              "${phoneNumberSecretName}" = {
                format = "binary";
                sopsFile = self.profile.secretsPath phoneNumberSecretName;
                mode = "0440";
                owner = "signal-bot";
                group = "signal-bot";
                restartUnits = [ "nx-signal-bot.service" ];
              };
              "${haTokenSecretName}" = {
                format = "binary";
                sopsFile = self.profile.secretsPath haTokenSecretName;
                mode = "0440";
                owner = "signal-bot";
                group = "signal-bot";
                restartUnits = [ "nx-signal-bot.service" ];
              };
              "${apiTokenSecretName}" = {
                format = "binary";
                sopsFile = self.profile.secretsPath apiTokenSecretName;
                path = apiTokenPath;
                mode = "0400";
                owner = "signal-bot";
                group = "signal-bot";
                restartUnits = [ "nx-signal-bot.service" ];
              };
              "${contactsSecretName}" = {
                format = "yaml";
                key = "";
                sopsFile = self.profile.secretsPath "${contactsSecretName}.yaml";
                mode = "0440";
                owner = "signal-bot";
                group = "signal-bot";
                restartUnits = [ "nx-signal-bot.service" ];
              };
            }
            // perUserTokenSecrets
          );

          systemd.services.nx-signal-bot-permissions = lib.mkIf configured {
            description = "NX Signal Bot Data Permission Fixup";
            wantedBy = [ "multi-user.target" ];
            before = [ "nx-signal-cli-daemon.service" ];
            requiredBy = [ "nx-signal-cli-daemon.service" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${permissionsScript}";
            };
          };

          systemd.services.nx-signal-cli-daemon = lib.mkIf configured {
            description = "NX Signal CLI JSON-RPC Daemon";
            wantedBy = [ "multi-user.target" ];

            unitConfig = {
              StartLimitIntervalSec = "1h";
              StartLimitBurst = 10;
            };

            serviceConfig = hardening // {
              Type = "simple";
              User = "signal-bot";
              Group = "signal-bot";
              Restart = "always";
              RestartSec = "30";
              ExecStartPre = "${pkgs.coreutils}/bin/test -f ${signalCliDataDir}/data/accounts.json";
              ExecStart = "${pkgs.signal-cli}/bin/signal-cli --scrub-log --config ${signalCliDataDir} daemon --socket ${socketPath} --receive-mode manual${
                lib.optionalString (!transcriptionActive) " --ignore-attachments"
              } --ignore-avatars --ignore-stickers --ignore-stories";
            };
          };

          systemd.services.nx-signal-bot = lib.mkIf configured {
            description = "NX Signal Bot Bridge";
            wantedBy = [ "multi-user.target" ];
            after = [ "nx-signal-cli-daemon.service" ];
            requires = [ "nx-signal-cli-daemon.service" ];

            unitConfig = {
              StartLimitIntervalSec = "1h";
              StartLimitBurst = 10;
            };

            serviceConfig =
              hardening
              // {
                Type = "simple";
                User = "signal-bot";
                Group = "signal-bot";
                Restart = "always";
                RestartSec = "30";
                TimeoutStartSec = "900";
                ExecStartPre = "${pkgs.util-linux}/bin/flock ${bootstrapLockFile} ${pythonEnv}/bin/python3 ${bridgeScript} bootstrap ${botConfigJson}";
                ExecStart = "${pythonEnv}/bin/python3 ${bridgeScript} serve ${botConfigJson}";
              }
              // lib.optionalAttrs transcriptionActive {
                Nice = 5;
                CPUWeight = 50;
              };
          };

          systemd.services.nx-signal-bot-sync = lib.mkIf configured {
            description = "NX Signal Bot Main Group Reconciliation";
            after = [ "nx-signal-bot.service" ];
            requisite = [ "nx-signal-bot.service" ];

            serviceConfig = hardening // {
              Type = "oneshot";
              User = "signal-bot";
              Group = "signal-bot";
              TimeoutStartSec = "900";
              ExecStart = [
                "${pkgs.util-linux}/bin/flock -n -E 0 ${bootstrapLockFile} ${pythonEnv}/bin/python3 ${bridgeScript} bootstrap ${botConfigJson}"
              ]
              ++ lib.optional transcriptionActive "${attachmentSweeper}";
            };
          };

          systemd.timers.nx-signal-bot-sync = lib.mkIf configured {
            description = "NX Signal Bot Main Group Reconciliation Timer";
            wantedBy = [ "timers.target" ];

            timerConfig = {
              OnActiveSec = "${toString syncIntervalMinutes}min";
              OnUnitActiveSec = "${toString syncIntervalMinutes}min";
              AccuracySec = "1min";
              Unit = "nx-signal-bot-sync.service";
            };
          };
        };

      ifEnabled.linux.services.whisper = {
        linux.system = config: {
          users.users.signal-bot.extraGroups = lib.mkIf (
            config.nx.linux.services.whisper.backend == "server"
          ) [ config.nx.linux.services.whisper.server.group ];
        };
      };

      ifEnabled.linux.server.nginx = {
        system =
          {
            config,
            apiPort,
            subdomain,
            configured,
            internalOnly,
            chatEnable,
            chatSubdomain,
            ...
          }:
          let
            domain = self.host.remote.baseDomain;
            internalGuard = lib.optionalString internalOnly ''
              if ($nx_is_internal = 0) { return 403; }
            '';
            proxyHeaders = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
            chatAuthHeader = ''
              auth_request_set $chat_user $upstream_http_x_auth_request_user;
              proxy_set_header X-Auth-Request-User $chat_user;
            '';
            apiUnauthorized = ''
              error_page 401 =401 @signal_chat_api_401;
            '';
          in
          lib.mkIf (configured && domain != null) {
            services.nginx.virtualHosts = {
              "${subdomain}.${domain}" = {
                useACMEHost = domain;
                forceSSL = true;
                locations."/v1/send" = {
                  proxyPass = "http://127.0.0.1:${toString apiPort}/v1/send";
                  recommendedProxySettings = false;
                  extraConfig = internalGuard + proxyHeaders;
                };
                locations."/".return = "404";
              };
            }
            // lib.optionalAttrs chatEnable {
              "${chatSubdomain}.${domain}" = {
                useACMEHost = domain;
                forceSSL = true;
                extraConfig = ''
                  location @signal_chat_api_401 {
                    return 401;
                  }
                '';
                locations."/" = {
                  proxyPass = "http://127.0.0.1:${toString apiPort}";
                  recommendedProxySettings = false;
                  extraConfig = proxyHeaders + chatAuthHeader;
                };
                locations."/v1/" = {
                  proxyPass = "http://127.0.0.1:${toString apiPort}";
                  recommendedProxySettings = false;
                  extraConfig = proxyHeaders + chatAuthHeader + apiUnauthorized;
                };
                locations."/v1/chat/stream" = {
                  proxyPass = "http://127.0.0.1:${toString apiPort}/v1/chat/stream";
                  recommendedProxySettings = false;
                  extraConfig =
                    proxyHeaders
                    + chatAuthHeader
                    + apiUnauthorized
                    + ''
                      proxy_buffering off;
                      proxy_cache off;
                      proxy_set_header Connection "";
                      proxy_read_timeout 3600s;
                      chunked_transfer_encoding off;
                    '';
                };
              };
            };
          };
      };

      ifEnabled.linux.server.auth = {
        enabled =
          config:
          let
            moduleConfig = config.nx.linux.services.signal-bot;
          in
          lib.mkIf (moduleConfig.chatEnable && config.nx.linux.server.auth.enableOAuthProxy) {
            nx.linux.server.auth.proxyProtectedVhosts = [
              {
                vhost = moduleConfig.chatSubdomain;
                allowedGroups = [ moduleConfig.chatAllowedGroup ];
              }
            ];
          };
      };

      ifEnabled.linux.server.ldap = {
        enabled =
          config:
          lib.mkIf config.nx.linux.services.signal-bot.chatEnable {
            nx.linux.server.ldap.groups = [ config.nx.linux.services.signal-bot.chatAllowedGroup ];
          };
      };

      ifEnabled.linux.server.healthchecks = {
        enabled =
          config:
          let
            rpcPingScript = pkgs.writers.writePython3Bin "signal-bot-rpc-ping" { } ''
              import json
              import socket
              import sys
              import time

              SOCKET_PATH = "${socketPath}"
              REQUEST_ID = "nx-healthcheck"
              DEADLINE = time.monotonic() + 10

              try:
                  sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                  sock.settimeout(5)
                  sock.connect(SOCKET_PATH)
                  request = {
                      "jsonrpc": "2.0",
                      "method": "version",
                      "id": REQUEST_ID,
                  }
                  sock.sendall(json.dumps(request).encode() + b"\n")
                  stream = sock.makefile("rb")
                  while time.monotonic() < DEADLINE:
                      line = stream.readline()
                      if not line:
                          break
                      try:
                          message = json.loads(line)
                      except json.JSONDecodeError:
                          continue
                      if message.get("id") == REQUEST_ID:
                          if "result" in message:
                              sys.exit(0)
                          print("version request returned an error")
                          sys.exit(1)
              except OSError as e:
                  print(f"cannot reach the daemon socket: {e}")
                  sys.exit(1)
              print("no version response within 10s")
              sys.exit(1)
            '';
          in
          lib.mkIf config.nx.linux.services.signal-bot.configured {
            nx.linux.server.healthchecks.requireServicesUp = [
              "nx-signal-cli-daemon.service"
              "nx-signal-bot.service"
            ];
            nx.linux.server.healthchecks.regularHealthChecks."R+55 - Signal bot RPC" = ''
              if ! _signal_rpc=$(${rpcPingScript}/bin/signal-bot-rpc-ping 2>&1); then
                printf 'signal-cli RPC: %s\n' "$_signal_rpc" >&3
                exit 1
              fi
            '';
          };
      };
    };
}
