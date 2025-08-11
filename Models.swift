//
//  Models.swift
//  IntellectaAssistant
//
//  Created by emre on 11.08.2025.
//
import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var text: String
    enum Role { case user, assistant }
}

func isEnglishQuestion(_ text: String, lang: String = "en") -> Bool {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard lang == "en", !t.isEmpty else { return false }
    let starts = ["what","why","how","when","where","who","which",
                  "can","could","should","would","do","does","did",
                  "is","are","am","will","may","might"]
    return t.hasSuffix("?") || starts.contains { t.hasPrefix($0 + " ") }
}
