# VisualGram local extras

These files extend the pinned VisualGram patches on top of Telegram iOS. The
manual workflow applies them with `ApplyVisualGramExtras.py` before compiling.

## Added in this revision

- A local editor for incoming and outgoing messages with bold, italic,
  underline, strikethrough, monospace, spoiler, quote and text links. A selected
  image can replace the message media locally. The context menu can restore
  the original message. Server text and edit timestamps are untouched.
- Replaced text drops the original link/phone entities and link preview.
  Local edits increment the display version so an open chat refreshes.
- Device-wide controls in the triple-Chats VisualGram menu: ghost mode,
  sponsored-message hiding, local Premium appearance, edited/deleted text
  history, word filtering, send confirmation for stickers/GIFs/voice, and
  screenshot rendering in protected non-secret chats. The settings apply to
  every account in this app install.
- Built-in Telegram alternate icon chooser. The three bundled Premium icon
  variants are available when local Premium appearance is on.
- Local Premium appearance also enables the local emoji-status picker for the
  current account. Status changes remain in the local profile overlay.
- Telegram's star/GRAM images appear in their balance entry fields. The back
  button returns from a VisualGram submenu to its main menu. VisualGram sections
  now use Telegram's native push/pop navigation, with its standard transition.
  Menu switches and sections use the existing Telegram settings artwork.
- The message editor sizes its hint and formatting toolbar for Dynamic Type and
  compact heights; the formatting actions remain available in a scrolling row.
- When message history is enabled, a known server edit keeps the current message
  in the chat and appends a pencil with the last captured version. A known
  deletion inserts a local trash-marked text row at its original timestamp.
  These rows are local presentation only and never restore server messages.

## Limits

- Local Premium does not buy a subscription or unlock server-checked limits.
  Tapping another user's status shows a local-mode explanation instead of a
  purchase screen.
- Telegram's server rejects forwarding protected messages. This revision does
  not offer protected forwarding. Secret chats still retain screenshot blocking.
- Message history can retain only content this installation received before a
  remote edit or deletion. For ordinary deleted photos, videos and voice
  messages, it archives a file only if that file is fully present in this
  device's Telegram cache when deletion arrives. It does not fetch deleted
  files or restore media that was never downloaded. The archive is private to
  this installation, capped at 512 MB per file and 1 GB total, and removed
  when the journal is cleared or old events are evicted. With "Keep timed
  media" enabled, the app also archives an already downloaded timed photo,
  video or voice file before Telegram expires it. The local chat row then
  shows the saved file without its timer; the sender's timer and Telegram's
  server state continue normally. Long-pressing a saved timed item offers
  "Send saved copy", which uploads it as a new message without the original
  sender attribution. A timed file that never fully reached the cache cannot
  be retained. The journal is bounded to 500 events, 200 timed media entries,
  and 2,000 observed message snapshots. Older
  journal entries do not include their original timestamp, so they remain in
  the journal list rather than being inserted into a chat.
- Ghost mode suppresses this client's read RPC paths while enabled. Other
  Telegram sessions may still mark messages or stories as read.
- iOS can select only icons bundled into the IPA. A new personal image must be
  added to the build assets before installing a new IPA.

## Verification

The complete patch chain, including the inline journal, has been applied
successfully to a separate clean worktree on Windows. `PostboxImportCheck.py`,
Python syntax and `git diff --check` passed. Swift parsing, type-checking,
simulator screenshots and device behavior still require macOS. No IPA was
produced by these source edits.
