//
//  BorderTemplate.swift
//  SocialMarketer
//
//  Border template styles for quote graphics
//

import Foundation

/// Border template styles for quote graphics
enum BorderTemplate: String, CaseIterable, Identifiable {
    case artDeco = "art_deco"
    case classicScroll = "classic_scroll"
    case sacredGeometry = "sacred_geometry"
    case celticKnot = "celtic_knot"
    case fleurDeLis = "fleur_de_lis"
    case baroque = "baroque"
    case victorian = "victorian"
    case goldenVine = "golden_vine"
    case stainedGlass = "stained_glass"
    case modernGlow = "modern_glow"
    
    var id: String { rawValue }
    
    /// Display name
    var displayName: String {
        switch self {
        case .artDeco: return "Art Deco"
        case .classicScroll: return "Classic Scroll"
        case .sacredGeometry: return "Sacred Geometry"
        case .celticKnot: return "Celtic Knot"
        case .fleurDeLis: return "Fleur-de-lis"
        case .baroque: return "Baroque"
        case .victorian: return "Victorian"
        case .goldenVine: return "Golden Vine"
        case .stainedGlass: return "Stained Glass"
        case .modernGlow: return "Modern Glow"
        }
    }
    
    /// Actual filename in Resources/Borders
    var filename: String {
        switch self {
        case .artDeco: return "template_01_art_deco_1770307365733"
        case .classicScroll: return "template_02_greek_laurel_1770307380099"
        case .sacredGeometry: return "template_03_sacred_geometry_1770307394997"
        case .celticKnot: return "template_04_celtic_knot_1770307423874"
        case .fleurDeLis: return "template_05_minimalist_1770307439021"
        case .baroque: return "template_06_baroque_1770307454492"
        case .victorian: return "template_07_victorian_1770307484325"
        case .goldenVine: return "template_08_islamic_1770307499223"
        case .stainedGlass: return "template_09_stained_glass_1770307514480"
        case .modernGlow: return "template_10_modern_glow_1770307534790"
        }
    }
    
    /// Get a random template
    static var random: BorderTemplate {
        allCases.randomElement()!
    }
}
