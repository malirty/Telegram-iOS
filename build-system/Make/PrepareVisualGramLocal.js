// Adapt the pinned public VisualGram patches for local-only use.
// This runs before apply_native_features.py; it never changes Telegram's server state.
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(process.argv[2] || 'visualgram-patches');

function edit(relative, transform) {
  const file = path.join(root, relative);
  let source = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
  source = transform(source);
  fs.writeFileSync(file, source, 'utf8');
}

function once(source, oldText, newText, name) {
  const first = source.indexOf(oldText);
  if (first < 0 || source.indexOf(oldText, first + oldText.length) >= 0) {
    throw new Error(`Expected one occurrence of ${name}`);
  }
  return source.slice(0, first) + newText + source.slice(first + oldText.length);
}

function exactCount(source, oldText, newText, expected, name) {
  const count = source.split(oldText).length - 1;
  if (count !== expected) throw new Error(`Expected ${expected} occurrences of ${name}; found ${count}`);
  return source.split(oldText).join(newText);
}

function removeBetween(source, startText, endText, name) {
  const start = source.indexOf(startText);
  const end = source.indexOf(endText, start + startText.length);
  if (start < 0 || end < 0 || source.indexOf(startText, start + startText.length) >= 0) {
    throw new Error(`Could not isolate ${name}`);
  }
  return source.slice(0, start) + source.slice(end);
}

edit('scripts/apply_native_features.py', source => {
  source = once(source,
    '    shutil.copyfile(project / "native/VisualGramLogo.svg", root / "Telegram/Telegram-iOS/Telegram.icon/Assets/Plane.svg")\n',
    '', 'VisualGram icon override');
  source = once(source,
    '    shutil.copyfile(project / "native/VisualGramActivation.swift", core / "VisualGramActivation.swift")\n',
    '', 'activation client copy');
  return once(source,
    '    from apply_native_activation import apply_activation\n    apply_activation(root)\n',
    '', 'activation patch application');
});

edit('native/VisualGramAppearanceController.swift', source => {
  source = removeBetween(source,
    '    func openActivation() {\n',
    '    func form(title: String, fields: [(String, String)], save: @escaping ([String]) -> Void) {\n',
    'activation dialog');
  source = once(source,
    '        if id == 1000 { self.openActivation(); return }\n        guard VisualGramActivation.shared.hasAccess else { self.openActivation(); return }\n',
    '', 'menu activation gate');
  source = once(source,
    '        guard VisualGramActivation.shared.hasAccess else { self.openActivation(); return }\n',
    '', 'profile activation gate');
  source = once(source,
    '    VisualGramActivation.shared.start(vendorIdentifier: UIDevice.current.identifierForVendor?.uuidString, isForeground: UIApplication.shared.applicationState != .background, activeNotification: UIApplication.didBecomeActiveNotification, backgroundNotification: UIApplication.didEnterBackgroundNotification)\n',
    '', 'activation startup');
  source = once(source,
    '        if !VisualGramActivation.shared.hasAccess {\n            add(1000, 0, "Активация VisualGram", .button("Введите код"))\n        } else {\n        if activeSection == -1 { add(1000, -2, "Доступ", .button("Проверить")) }\n',
    '', 'activation menu');
  return once(source,
    '        }\n        entries.sort()\n',
    '        entries.sort()\n', 'activation menu closing brace');
});

edit('native/VisualGramLocalAppearance.swift', source => {
  source = once(source, '    private var activationObserver: NSObjectProtocol?\n', '', 'activation observer property');
  source = once(source, '        guard VisualGramActivation.shared.hasAccess else { return [:] }\n', '', 'snapshot access gate');
  source = removeBetween(source,
    '        self.activationObserver = NotificationCenter.default.addObserver(forName: VisualGramActivation.changed, object: nil, queue: nil) { [weak self] _ in\n',
    '    }\n\n    static func migrateLegacyAppearances', 'activation observer');
  source = removeBetween(source,
    '    // Safety routing only: an expired local purchase must never fall through to a real charge.\n',
    '    public var pendingScheduledGifts:', 'expired activation purchase gate');
  source = exactCount(source, '        guard VisualGramActivation.shared.hasAccess else { return [] }\n', '', 2, 'scheduled gift access gates');
  source = once(source, '        guard VisualGramActivation.shared.hasAccess else { return VisualGramAppearance() }\n', '', 'appearance access gate');
  return once(source,
    '        guard VisualGramActivation.shared.hasAccess else { self.lock.unlock(); return }\n',
    '', 'local write access gate');
});

edit('native/VisualGramGiftDelivery.swift', source => once(source,
  '        VisualGramActivation.shared.start(vendorIdentifier: UIDevice.current.identifierForVendor?.uuidString, isForeground: UIApplication.shared.applicationState != .background, activeNotification: UIApplication.didBecomeActiveNotification, backgroundNotification: UIApplication.didEnterBackgroundNotification)\n',
  '', 'scheduled delivery activation startup'));

edit('native/VisualGramWallet.swift', source => once(source,
  '        guard VisualGramActivation.shared.hasAccess else { return server }\n',
  '', 'wallet activation gate'));

edit('scripts/test_native_operations.py', source => {
  source = once(source,
    '// Journal/undo survive JSON persistence, cosmetic edits and activation gating.\n',
    '// Journal/undo survive JSON persistence and cosmetic edits.\n',
    'operation test description');
  source = once(source,
    'VisualGramActivation.shared.hasAccess=false\n_ = cancel(restored,a,record);assert(restored.values["10"]?.gifts.count==1)\nVisualGramActivation.shared.hasAccess=true\n',
    '', 'operation activation test');
  return once(source,
    'persistence and activation guards',
    'persistence', 'operation test result');
});

edit('scripts/test_native_upgrade.py', source => once(source,
  'public final class VisualGramActivation { public static let shared = VisualGramActivation(); public var hasAccess = true }\n',
  '', 'upgrade test activation stub'));

for (const relative of [
  'native/VisualGramActivation.swift',
  'native/VisualGramLogo.svg',
  'scripts/apply_native_activation.py',
  'scripts/test_native_activation.py',
]) {
  fs.unlinkSync(path.join(root, relative));
}

for (const relative of [
  'scripts/apply_native_features.py',
  'native/VisualGramAppearanceController.swift',
  'native/VisualGramLocalAppearance.swift',
  'native/VisualGramGiftDelivery.swift',
  'native/VisualGramWallet.swift',
  'scripts/test_native_operations.py',
  'scripts/test_native_upgrade.py',
]) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  if (source.includes('VisualGramActivation') || source.includes('VisualGramLogo.svg')) {
    throw new Error(`Activation or custom icon reference remains in ${relative}`);
  }
}

console.log('VisualGram local-only source prepared with the official Telegram icon.');
