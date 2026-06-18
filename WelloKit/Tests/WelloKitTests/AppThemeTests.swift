import Testing
@testable import WelloKit

@Suite("AppTheme")
struct AppThemeTests {

    @Test("4 thèmes, raw values stables (persistance)")
    func casEtRawValues() {
        #expect(AppTheme.allCases.count == 4)
        #expect(AppTheme.allCases.map(\.rawValue) == ["glacier", "aurore", "menthe", "crepuscule"])
    }

    @Test("Seul glacier est gratuit")
    func gratuité() {
        #expect(AppTheme.glacier.estGratuit)
        for theme in AppTheme.allCases where theme != .glacier {
            #expect(!theme.estGratuit, "\(theme.rawValue) ne devrait pas être gratuit")
        }
    }

    @Test("alternateIconName nil uniquement pour glacier")
    func iconeAlternative() {
        #expect(AppTheme.glacier.alternateIconName == nil)
        for theme in AppTheme.allCases where theme != .glacier {
            #expect(theme.alternateIconName != nil, "\(theme.rawValue) doit avoir une icône alternative")
        }
    }

    @Test("Palettes toutes distinctes")
    func palettesDistinctes() {
        let palettes = AppTheme.allCases.map(\.palette)
        for i in palettes.indices {
            for j in palettes.indices where j > i {
                #expect(palettes[i] != palettes[j], "palettes identiques aux index \(i) et \(j)")
            }
        }
    }

    @Test("glacier conserve la palette historique (non-régression)")
    func glacierInchangé() {
        #expect(AppTheme.glacier.palette == ThemePalette(accent: 0x4FB0E5, accentDeep: 0x2E8BC9,
                                                         waterTop: 0x86D7F5, waterBottom: 0x3FA3E0))
    }
}
