import Meters

/// What the network meter shows, rounded to what lands on screen: whether each arrow is lit,
/// and each rate as the meter writes it, to two or three digits. Only the shown parts are
/// filled, so a change that isn't shown isn't a change. The view redraws only when this changes.
struct NetworkDrawState: Equatable {
    /// A rate as the meter writes it: `tenths` of a unit when under ten, else whole units,
    /// times ten.
    struct Rate: Equatable {
        var tenths = 0
        /// 0 bytes, 1 kilobytes, 2 megabytes, 3 gigabytes, 4 terabytes, all powers of 1,000.
        var unit = 0
    }

    var isSending = false
    var isReceiving = false
    var send = Rate()
    var receive = Rate()

    /// Below this a direction's arrow stays dark, so the trickle of background traffic an idle
    /// Mac always has doesn't keep it lit.
    static let activeBytesPerSecond = 1_000.0

    init() {}

    init(sendRate: Double, receiveRate: Double, config: NetworkConfig) {
        if config.showsArrows {
            isSending = sendRate >= Self.activeBytesPerSecond
            isReceiving = receiveRate >= Self.activeBytesPerSecond
        }
        if config.showsThroughput {
            send = Self.rate(sendRate)
            receive = Self.rate(receiveRate)
        }
    }

    static func rate(_ bytesPerSecond: Double) -> Rate {
        var value = max(bytesPerSecond, 0)
        var unit = 0
        while value >= 999.5 && unit < 4 {
            value /= 1_000
            unit += 1
        }
        let tenths =
            unit > 0 && value < 9.95 ? Int((value * 10).rounded()) : Int(value.rounded()) * 10
        return Rate(tenths: tenths, unit: unit)
    }

    /// `512B`, `1.2K`, `12K`, `120M`.
    static func text(_ rate: Rate) -> String {
        let letter = ["B", "K", "M", "G", "T"][rate.unit]
        let whole = rate.tenths / 10
        return rate.tenths < 100 && rate.unit > 0
            ? "\(whole).\(rate.tenths % 10)\(letter)" : "\(whole)\(letter)"
    }
}
