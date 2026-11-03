import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A private drag payload so unrelated text and files can't reorder shortcuts.
nonisolated struct ShortcutDrag: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .summonShortcut)
    }
}

extension UTType {
    nonisolated static let summonShortcut = UTType(exportedAs: "si.timrekelj.summon.shortcut", conformingTo: .data)
}
