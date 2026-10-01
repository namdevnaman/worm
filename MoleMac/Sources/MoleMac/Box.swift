import Foundation
import SwiftUI

/// Per-view mutable storage for SwiftUI views.
///
/// `@State` is a compiler macro in this SDK and its macro plugin ships with
/// Xcode rather than the Command Line Tools, so `@State` cannot be compiled
/// with the toolchain available here. `Box` is an ordinary `ObservableObject`
/// holding one value, which `@StateObject` *can* compile, and it serves the same
/// purpose: storage that survives view updates and re-renders the view when it
/// changes.
final class Box<Value>: ObservableObject {
    @Published var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

/// `@unchecked Sendable` because `Box` is only ever mutated from the main
/// actor, and its `Binding` closures are invoked by SwiftUI on the main actor.
/// The compiler cannot see that through `Binding`, which is not `Sendable`.
extension Box: @unchecked Sendable {}

extension Box {
    /// A `Binding` onto this box, for driving a SwiftUI control.
    var binding: Binding<Value> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}

extension Box where Value == Bool {
    func toggle() {
        value.toggle()
    }
}