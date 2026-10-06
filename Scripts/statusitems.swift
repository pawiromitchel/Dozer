// Debug helper: lists on-screen menu bar items (owner, x, width), left to right. Needs no permissions.
//   swift Scripts/statusitems.swift
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let items = windows.compactMap { info -> (String, CGRect)? in
    guard (info[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.statusWindow)),
          let dict = info[kCGWindowBounds as String] as? NSDictionary,
          let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary) else { return nil }
    return (info[kCGWindowOwnerName as String] as? String ?? "?", bounds)
}
for (owner, bounds) in items.sorted(by: { $0.1.minX < $1.1.minX }) {
    print(owner.padding(toLength: 26, withPad: " ", startingAt: 0), "x:", Int(bounds.minX), "w:", Int(bounds.width), "h:", Int(bounds.height))
}
