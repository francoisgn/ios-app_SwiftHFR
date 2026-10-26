import HFRModels

/// One-shot clean-up of values written by the legacy app, run at launch before the first read.
///
/// It only rewrites what the legacy launch code rewrote (E-1): the `auto_theme` clamp, the deprecated theme keys and
/// the `size_text_topics` to `text_size_scale` migration. It does not force `display_images`, `shake_to_refresh` or the
/// seasonal theme keys: those had no purpose left.
public enum LegacySettingsNormalizer {
    /// Applies the rules; returns true when something in the store changed.
    @discardableResult
    public static func run(on store: some SettingsStore) -> Bool {
        var changed = false

        if let raw = store.rawValue(forKey: SettingKey.autoTheme.key),
           let number = SettingCoercion.int(raw),
           AutoThemeMode(rawValue: number) == nil {
            store.set(AutoThemeMode.system, for: SettingKey.autoTheme)
            changed = true
        }

        for key in SettingKey.deprecatedKeys where store.rawValue(forKey: key) != nil {
            store.removeValue(forKey: key)
            changed = true
        }

        if store.rawValue(forKey: SettingKey.textSizeScale.key) == nil,
           let raw = store.rawValue(forKey: SettingKey.legacyTopicTextSizeKey),
           let legacySize = SettingCoercion.int(raw) {
            store.set(closestScale(to: legacySize), for: SettingKey.textSizeScale)
            changed = true
        }

        return changed
    }

    /// The supported scale nearest to a legacy size; ties go to the smaller one (`min` keeps the first of equals).
    static func closestScale(to legacySize: Int) -> TextSizeScale {
        TextSizeScale.allCases.min { abs($0.rawValue - legacySize) < abs($1.rawValue - legacySize) } ?? .percent100
    }
}
