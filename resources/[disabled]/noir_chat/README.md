# noir_chat

`noir_chat` is a standalone replacement for the stock CFX `chat` resource. It
keeps the standard NUI and public `chat:*` events/exports used by Qbox while
leaving `L` unassigned.

## Controls

- `T`: open chat input.
- `Enter`: submit.
- `Escape`: close input.
- `L`: no chat action.

## Installation

Start only the replacement:

```cfg
# ensure chat
ensure noir_chat
```

The manifest declares `provide 'chat'` so resources using `exports.chat` or a
`chat` dependency continue resolving to this resource.

## Configuration

`Config.ToggleChatKey` defaults to `false`, so no visibility key mapping is
registered. Set it explicitly to a mapper key such as `'F10'` if desired.

`Config.MaxMessageLength` limits player-submitted chat messages to 500
characters by default.

## Compatibility

The replacement preserves the stock events and exports, including
`chat:addMessage`, `chat:addSuggestion`, `chat:addSuggestions`,
`chat:removeSuggestion`, `chat:addTemplate`, `chat:addMode`,
`chat:removeMode`, `chat:clear`, `chatMessage`, console prints, message hooks and
chat modes.

## Existing keybinds

FiveM may retain a key mapping created by the old `chat` resource in a player's
local profile. Because the old resource is stopped and this replacement has a
different resource name, that legacy resource binding should not control
`noir_chat`. If investigating a client, inspect bindings in FiveM settings or
the F8 console. Do not blindly run `unbind keyboard L`, since that can remove an
intentional vehicle-lock binding.

## Test checklist

1. Restart the server or run `stop chat` followed by `ensure noir_chat`.
2. Confirm `T`, `Enter`, and `Escape` operate the input normally.
3. Press `L` and confirm chat visibility/focus does not change.
4. Confirm the vehicle lock still receives `L`.
5. Test `chat:addMessage`, command suggestions, Qbox MOTD/join messages, and
   `restart noir_chat`.
