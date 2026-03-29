import Foundation

public struct TextMarkerRangeProof: Equatable, Sendable {
    public var startMarker: Data
    public var endMarker: Data

    public init(startMarker: Data, endMarker: Data) {
        self.startMarker = startMarker
        self.endMarker = endMarker
    }
}

public struct HostAdapterProofToken: Equatable, Sendable {
    public var adapterIdentifier: String
    public var token: Data

    public init(adapterIdentifier: String, token: Data) {
        self.adapterIdentifier = adapterIdentifier
        self.token = token
    }
}

public enum SelectionProof: Equatable, Sendable {
    case exactRange(SelectionRange)
    case textMarker(TextMarkerRangeProof)
    case hostAdapterProof(HostAdapterProofToken)
    case unproven

    public var isProven: Bool {
        switch self {
            case .unproven:
                false
            case .exactRange, .textMarker, .hostAdapterProof:
                true
        }
    }

    public func defaultWritebackCapability(isWritable: Bool) -> WritebackCapability {
        switch self {
            case .exactRange:
                isWritable ? .directAX : .pasteCurrentSelection
            case .textMarker, .hostAdapterProof:
                .pasteCurrentSelection
            case .unproven:
                .manualOnly
        }
    }
}

public enum WritebackCapability: String, Sendable {
    case directAX
    case pasteCurrentSelection
    case manualOnly
}

public enum WritebackOutcome: String, Sendable {
    case appliedDirect
    case appliedPaste
    case needsManualApply
    case failed
}
