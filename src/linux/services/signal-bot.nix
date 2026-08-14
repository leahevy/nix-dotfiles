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
      default = 3000;
      description = "Number of characters of an incoming message that count as one unit of the daily sender budget.";
    };

    budgetOutputChars = lib.mkOption {
      type = lib.types.ints.positive;
      default = 750;
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
            type = lib.types.str;
            default = "[Earlier messages, judge only the message after this block:\n{transcript}]\n{prompt}";
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
            default = 5;
            description = "Maximum maybe messages answered within maybeBudgetSeconds per group, zero blocks all maybe answers.";
          };

          maybeBudgetSeconds = lib.mkOption {
            type = lib.types.ints.positive;
            default = 900;
            description = "Length in seconds of the sliding window over which maybeBudget answers are counted.";
          };
        };
      };
      default = { };
      description = "How the bot decides whether a group message is meant for it.";
    };

    conversationFollowUpSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 7200;
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
            type = lib.types.str;
            default = "The user did not write a message, they only reacted to your last message with an emoji. If the reaction answers a question you asked, carry out the matching action with your normal tools first. Then reply with one very short sentence or with emoji alone. Never write tool calls, function names or code into your reply.";
            description = "Instruction prepended to the meaning of a reaction so the answer stays short, wrapped by instructionTemplate.";
          };

          promptTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{instruction} {emoji} {meaning}";
            description = "Format of the prompt built from a reaction, with the placeholders {instruction}, {emoji} and {meaning} substituted.";
          };

          fallback = lib.mkOption {
            type = lib.types.str;
            default = "I reacted to your last message like this, I am just being silly and making fun of it.";
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
            type = lib.types.attrsOf lib.types.str;
            default = {
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
            description = "Sentence each reaction is turned into, keyed by the same names as emoji, written in the first person as if the user had sent it, with the placeholder {emoji} substituted.";
          };
        };
      };
      default = { };
      description = "How the bot answers reactions placed on its most recent message.";
    };

    maxHookSendsPerDay = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Maximum number of autonomous hook messages sent per calendar day across all hooks.";
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
      type = lib.types.str;
      default = "This is an automatic system trigger, not a message from a user. You are the assistant speaking on your own initiative into the group chat. What follows is a transcript of today's group conversation, the first messages of the day first and the most recent messages last, and when older messages in the middle were left out a marker line separates the two blocks. Use it to ground your message in what happened. Lines are labelled with who wrote them, and your own earlier messages are labelled as the bot. The conversation may be short or empty, in that case proceed sensibly without inventing details. After the transcript comes the task describing what to post. Write only the message to send to the group, in the language the group uses, with no preamble about being triggered.";
      description = "System baseline prepended to every hook prompt to frame the trigger and transcript.";
    };

    hooksPromptTemplate = lib.mkOption {
      type = lib.types.str;
      default = "{systemInstruction}\n\n{transcript}\n\n{instruction}";
      description = "Prompt format for every hook, with {systemInstruction}, {transcript} and {instruction} substituted.";
    };

    hooksTranscriptSeparator = lib.mkOption {
      type = lib.types.str;
      default = "older messages skipped, the most recent messages follow";
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

            startTime = lib.mkOption {
              type = lib.types.strMatching "([01][0-9]|2[0-3]):[0-5][0-9]";
              description = "Local start of the fire window as HH:MM.";
            };

            endTime = lib.mkOption {
              type = lib.types.strMatching "([01][0-9]|2[0-3]):[0-5][0-9]";
              description = "Local end of the fire window as HH:MM, an end not after the start wraps past midnight.";
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

            sendErrorsIntoChat = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Post Home Assistant error replies into the group instead of only logging and skipping.";
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
            type = lib.types.str;
            default = "Sorry, I could not understand that voice message!";
            description = "Reply sent when an audio attachment could not be transcribed.";
          };

          instruction = lib.mkOption {
            type = lib.types.str;
            default = "The user did not type this message, it was transcribed from a voice message and can hold recognition errors. Read a word that makes no sense in context as the word it most likely was, and ask a short question back when the intent stays unclear. Never mention the transcription itself in your reply.";
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
            type = lib.types.str;
            default = "Sorry, I could not reach Home Assistant right now.";
            description = "Reply sent when the Home Assistant conversation request fails.";
          };

          haUnexpectedResponse = lib.mkOption {
            type = lib.types.str;
            default = "Sorry, I did not understand the response from Home Assistant.";
            description = "Reply sent when Home Assistant answers with an unexpected payload.";
          };

          haAgentFailed = lib.mkOption {
            type = lib.types.str;
            default = "Home Assistant is awake, but I am having trouble thinking right now. Please ask me again in a moment.";
            description = "Reply sent when Home Assistant answers but its conversation agent keeps failing after all retries.";
          };

          haToolCallArtifact = lib.mkOption {
            type = lib.types.str;
            default = "Something went wrong in Home Assistant and the action was not carried out. Please ask me for it again.";
            description = "Reply sent when the conversation agent writes a tool call into its answer instead of running it.";
          };

          statusTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{name} status\n\nsignal-cli account data: {account}\nHome Assistant: {homeAssistant}\n\nDaily budget:\n{budget}\n\nMaybe answers: {maybeBudget}\n\nHooks:\n{hooks}";
            description = "Body of the status reply, with the placeholders {name}, {account}, {homeAssistant}, {budget}, {maybeBudget} and {hooks} substituted.";
          };

          statusBudgetEntryTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{contact}: {used} of {limit}";
            description = "Format of a single budget line in the status reply, with the placeholders {contact}, {used} and {limit} substituted.";
          };

          statusMaybeBudgetTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{remaining} of {limit} left";
            description = "Format of the maybe budget line in the status reply, with the placeholders {remaining} and {limit} substituted.";
          };

          statusMaybeBudgetDisabled = lib.mkOption {
            type = lib.types.str;
            default = "group filter off";
            description = "Maybe budget text in the status reply when the group filter is disabled.";
          };

          statusHooksDisabled = lib.mkOption {
            type = lib.types.str;
            default = "no hooks configured";
            description = "Hooks text in the status reply when no hooks are configured.";
          };

          statusHooksTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{used} of {limit} today\n{entries}";
            description = "Format of the hooks section in the status reply, with the placeholders {used}, {limit} and {entries} substituted.";
          };

          statusHookEntryTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{hook}: {state}";
            description = "Format of a single hook line in the status reply, with the placeholders {hook} and {state} substituted.";
          };

          statusHookFired = lib.mkOption {
            type = lib.types.str;
            default = "already fired, window {window}";
            description = "Hook state wording when the hook already fired this window, with {window} substituted.";
          };

          statusHookScheduled = lib.mkOption {
            type = lib.types.str;
            default = "scheduled {time}, window {window}";
            description = "Hook state wording when a fire time is rolled, with {time} and {window} substituted.";
          };

          statusHookIdle = lib.mkOption {
            type = lib.types.str;
            default = "idle, window {window}";
            description = "Hook state wording when the hook has no fire time this window, with {window} substituted.";
          };

          statusAccountOk = lib.mkOption {
            type = lib.types.str;
            default = "ok";
            description = "Status wording used when the signal-cli account data is complete.";
          };

          statusAccountMissing = lib.mkOption {
            type = lib.types.str;
            default = "MISSING";
            description = "Status wording used when signal-cli account data is missing.";
          };

          statusHaReachable = lib.mkOption {
            type = lib.types.str;
            default = "reachable";
            description = "Status wording used when Home Assistant answers.";
          };

          statusHaUnreachable = lib.mkOption {
            type = lib.types.str;
            default = "UNREACHABLE";
            description = "Status wording used when Home Assistant does not answer.";
          };

          helpEntryTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{command} - {description}";
            description = "Format of a single help line, with the placeholders {command} and {description} substituted.";
          };

          helpStatusDescription = lib.mkOption {
            type = lib.types.str;
            default = "Show whether signal-cli account data is present and Home Assistant is reachable.";
            description = "Help text describing the status command.";
          };

          helpHelpDescription = lib.mkOption {
            type = lib.types.str;
            default = "List all available commands.";
            description = "Help text describing the help command.";
          };

          helpShortcutTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{command} or {shortcut}";
            description = "Format of the command part of a help line for a command that has a shortcut, with the placeholders {command} and {shortcut} substituted.";
          };

          quoteContextTemplate = lib.mkOption {
            type = lib.types.str;
            default = "[Context - {author} wrote: {message}]\n{text}";
            description = "Prompt sent to Home Assistant when a reply refers to a message outside the current conversation, with the placeholders {author}, {message} and {text} substituted.";
          };

          quoteContextBot = lib.mkOption {
            type = lib.types.str;
            default = "the bot";
            description = "Wording used for {author} when the referenced message came from the bot itself.";
          };

          quoteContextUser = lib.mkOption {
            type = lib.types.str;
            default = "a user";
            description = "Wording used for {author} when the referenced message came from an unknown sender.";
          };

          groupSpeakerTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{author} wrote: {text}";
            description = "Prompt sent to Home Assistant for a group message, with the placeholders {author} and {text} substituted.";
          };

          contextRecapTemplate = lib.mkOption {
            type = lib.types.str;
            default = "[Earlier in this conversation:\n{transcript}]\n{text}";
            description = "Prompt sent to Home Assistant when the earlier conversation has to be restated, with the placeholders {transcript} and {text} substituted.";
          };

          contextRecapEntryTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{author} wrote: {message}";
            description = "Format of a single line of the restated conversation, with the placeholders {author} and {message} substituted.";
          };

          scriptRecapTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{text} ({description})";
            description = "Format of a script command in the restated conversation, with the placeholders {text} and {description} substituted.";
          };

          budgetExhausted = lib.mkOption {
            type = lib.types.str;
            default = "You have reached your daily request limit. Please try again later.";
            description = "Reply sent once when a sender exhausts the daily request budget.";
          };

          scriptCompleted = lib.mkOption {
            type = lib.types.str;
            default = "Done: {command}";
            description = "Reply sent when a script command finished and returned no response of its own, with the placeholders {command} and {argument} substituted.";
          };

          scriptFailed = lib.mkOption {
            type = lib.types.str;
            default = "The command {command} could not be run. Please check Home Assistant.";
            description = "Reply sent when a script command could not be run, with the placeholders {command} and {argument} substituted.";
          };

          scriptArgumentRequired = lib.mkOption {
            type = lib.types.str;
            default = "The command {command} needs a value after the command name.";
            description = "Reply sent when a script command that requires a value was sent without one, with the placeholder {command} substituted.";
          };

          scriptArgumentNotAllowed = lib.mkOption {
            type = lib.types.str;
            default = "The command {command} does not take a value.";
            description = "Reply sent when a value was sent to a script command that takes none, with the placeholder {command} substituted.";
          };

          scriptArgumentTooLong = lib.mkOption {
            type = lib.types.str;
            default = "The value for {command} is too long.";
            description = "Reply sent when the value of a script command exceeds its length limit, with the placeholder {command} substituted.";
          };

          scriptShortcutInvalid = lib.mkOption {
            type = lib.types.str;
            default = "The shortcut {shortcut} must be followed directly by a letter or a digit. Use {command} instead.";
            description = "Reply sent when a message starts with a command shortcut that is not followed by a letter or a digit, with the placeholders {command} and {shortcut} substituted.";
          };

          scriptArgumentInvalid = lib.mkOption {
            type = lib.types.str;
            default = "The value for {command} contains characters that are not allowed.";
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
          maxHookSendsPerDay,
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

          secretPath = name: config.sops.secrets.${name}.path;

          whisperCfg = config.nx.linux.services.whisper;
          attachmentsDir = "${signalCliDataDir}/attachments";
          transcriptionActive =
            if transcription.enable == null then configured && whisperCfg.enable else transcription.enable;
          transcribeCommand =
            if whisperCfg.transcribeList == null then [ ] else whisperCfg.transcribeList audioPlaceholder;

          bridgeScript = self.file "bridge.py";
          pythonEnv = pkgs.python3.withPackages (ps: [
            ps.flask
            ps.pyyaml
            ps.waitress
          ]);

          effectiveProfileGivenName =
            if profileGivenName != null then profileGivenName else self.host.hostname;

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
              main_group_name = mainGroupName;
              profile_given_name = effectiveProfileGivenName;
              profile_about = profileAbout;
              profile_avatar = if enableAvatar then self.profile.filesPath profileAvatar else null;
              group_avatar = if enableGroupAvatar then self.profile.filesPath groupAvatar else null;
              ha_url = haUrl;
              ha_language = haLanguage;
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
                context_template = groupFilter.contextTemplate;
                silent_answers = groupFilter.silentAnswers;
                maybe_answers = groupFilter.maybeAnswers;
                maybe_probability = groupFilter.maybeProbability;
                maybe_budget = groupFilter.maybeBudget;
                maybe_budget_seconds = groupFilter.maybeBudgetSeconds;
              };
              conversation_follow_up_seconds = conversationFollowUpSeconds;
              night_follow_up_seconds = nightFollowUpSeconds;
              night_start_hour = nightStartHour;
              night_end_hour = nightEndHour;
              ha_session_seconds = haSessionSeconds;
              context_max_messages = contextMaxMessages;
              context_max_chars = contextMaxChars;
              max_hook_sends_per_day = maxHookSendsPerDay;
              min_seconds_between_hooks = minSecondsBetweenHooks;
              min_seconds_since_bot_message = minSecondsSinceBotMessage;
              min_seconds_since_user_message = minSecondsSinceUserMessage;
              hooks_instruction = hooksInstruction;
              hooks_prompt_template = hooksPromptTemplate;
              hooks_transcript_separator = hooksTranscriptSeparator;
              hooks_transcript_separator_template = hooksTranscriptSeparatorTemplate;
              hooks_context_max_chars = hooksContextMaxChars;
              hooks_block_min_chars = hooksBlockMinChars;
              daily_transcript_limit = dailyTranscriptLimit;
              hooks = lib.mapAttrs (_: hook: {
                enable = hook.enable;
                start_time = hook.startTime;
                end_time = hook.endTime;
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
                send_errors_into_chat = hook.sendErrorsIntoChat;
                run_only_if_fired_today = hook.runOnlyIfFiredToday;
                skip_if_fired_today = hook.skipIfFiredToday;
              }) enabledHooks;
              reactions = {
                enable = reactions.enable;
                target_max_age_seconds = reactions.targetMaxAgeSeconds;
                target_max_messages = reactions.targetMaxMessages;
                instruction = reactions.instruction;
                prompt_template = reactions.promptTemplate;
                fallback = reactions.fallback;
                emoji = lib.mapAttrs (name: emoji: {
                  inherit emoji;
                  meaning = reactions.meanings.${name} or "";
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
                failure_message = transcription.failureMessage;
                instruction = transcription.instruction;
                prompt_template = transcription.promptTemplate;
              };
              messages = {
                ha_unreachable = messages.haUnreachable;
                ha_unexpected_response = messages.haUnexpectedResponse;
                ha_agent_failed = messages.haAgentFailed;
                ha_tool_call_artifact = messages.haToolCallArtifact;
                status_template = messages.statusTemplate;
                status_budget_entry_template = messages.statusBudgetEntryTemplate;
                status_maybe_budget_template = messages.statusMaybeBudgetTemplate;
                status_maybe_budget_disabled = messages.statusMaybeBudgetDisabled;
                status_hooks_disabled = messages.statusHooksDisabled;
                status_hooks_template = messages.statusHooksTemplate;
                status_hook_entry_template = messages.statusHookEntryTemplate;
                status_hook_fired = messages.statusHookFired;
                status_hook_scheduled = messages.statusHookScheduled;
                status_hook_idle = messages.statusHookIdle;
                status_account_ok = messages.statusAccountOk;
                status_account_missing = messages.statusAccountMissing;
                status_ha_reachable = messages.statusHaReachable;
                status_ha_unreachable = messages.statusHaUnreachable;
                help_entry_template = messages.helpEntryTemplate;
                help_status_description = messages.helpStatusDescription;
                help_help_description = messages.helpHelpDescription;
                help_shortcut_template = messages.helpShortcutTemplate;
                quote_context_template = messages.quoteContextTemplate;
                quote_context_bot = messages.quoteContextBot;
                quote_context_user = messages.quoteContextUser;
                group_speaker_template = messages.groupSpeakerTemplate;
                context_recap_template = messages.contextRecapTemplate;
                context_recap_entry_template = messages.contextRecapEntryTemplate;
                script_recap_template = messages.scriptRecapTemplate;
                budget_exhausted = messages.budgetExhausted;
                script_completed = messages.scriptCompleted;
                script_failed = messages.scriptFailed;
                script_argument_required = messages.scriptArgumentRequired;
                script_argument_not_allowed = messages.scriptArgumentNotAllowed;
                script_argument_too_long = messages.scriptArgumentTooLong;
                script_argument_invalid = messages.scriptArgumentInvalid;
                script_shortcut_invalid = messages.scriptShortcutInvalid;
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

          haAgentIdResolved = if haAgentId == null then null else "conversation.${haAgentId}";
          effectiveHooksAgentId =
            if hooksAgentId != null then "conversation.${hooksAgentId}" else haAgentIdResolved;

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
              assertion = lib.attrNames reactions.emoji == lib.attrNames reactions.meanings;
              message = "linux.services.signal-bot requires reactions emoji and reactions meanings to use exactly the same names!";
            }
            {
              assertion = lib.all (entry: entry != [ ]) (lib.attrValues reactions.emoji);
              message = "linux.services.signal-bot requires every reactions emoji entry to hold at least one emoji!";
            }
            {
              assertion = lib.all (meaning: meaning != "") (lib.attrValues reactions.meanings);
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
          in
          lib.mkIf (configured && domain != null) {
            services.nginx.virtualHosts."${subdomain}.${domain}" = {
              useACMEHost = domain;
              forceSSL = true;
              locations."/v1/send" = {
                proxyPass = "http://127.0.0.1:${toString apiPort}/v1/send";
                recommendedProxySettings = false;
                extraConfig = internalGuard + proxyHeaders;
              };
              locations."/".return = "404";
            };
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
