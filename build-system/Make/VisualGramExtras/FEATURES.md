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
  button returns from a VisualGram submenu to its main menu.

## Limits

- Local Premium does not buy a subscription or unlock server-checked limits.
  Tapping another user's status shows a local-mode explanation instead of a
  purchase screen.
- Telegram's server rejects forwarding protected messages. This revision does
  not offer protected forwarding. Secret chats still retain screenshot blocking.
- Message history can retain only content this installation received before a
  remote edit or deletion. It stores text, not deleted media files. The local
  journal is bounded to 500 events and 2,000 observed message snapshots.
- Ghost mode suppresses this client's read RPC paths while enabled. Other
  Telegram sessions may still mark messages or stories as read.
- iOS can select only icons bundled into the IPA. A new personal image must be
  added to the build assets before installing a new IPA.

## Verification

The patch chain has been applied successfully to a separate clean worktree on
Windows. `PostboxImportCheck.py` and Python syntax checks passed. Swift parsing,
type-checking, simulator screenshots and device behavior still require macOS.
No IPA was produced by these source edits.
