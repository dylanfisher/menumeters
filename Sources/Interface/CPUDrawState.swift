import Base
import Meters

/// What the CPU meter shows, rounded to what lands on screen: whole percents and graph bar
/// heights in device pixels. The view redraws only when this changes, so a tick whose load moves
/// less than a pixel costs no drawing.
///
/// The arrays are sized once at init. `update` overwrites them in place, so a tick allocates
/// nothing; compare and swap two instances instead of assigning one to the other, which would
/// share the arrays and copy on the next write.
struct CPUDrawState: Equatable {
    /// One bar of the graph, in device pixels from the bottom of its row.
    struct Column: Equatable {
        var systemPixels: Int16 = 0
        var totalPixels: Int16 = 0
    }

    let rowCount: Int
    let columnCount: Int
    /// Each row's newest load as a whole percent, 0...100.
    private(set) var percents: [Int]
    /// Row-major: row `r`'s bars are `columns[r * columnCount ..< (r + 1) * columnCount]`, oldest
    /// first. With less history than columns, the bars to the left are empty.
    private(set) var columns: [Column]
    /// Device pixels per point the bar heights were measured in.
    private(set) var scale: Double = 1

    init(rowCount: Int, columnCount: Int) {
        self.rowCount = rowCount
        self.columnCount = columnCount
        percents = Array(repeating: 0, count: rowCount)
        columns = Array(repeating: Column(), count: rowCount * columnCount)
    }

    /// Fills the state from one history per row, with bars up to `rowHeightPoints` tall.
    mutating func update(
        histories: [RingBuffer<CoreLoad>], rowHeightPoints: Double, scale: Double
    ) {
        precondition(
            histories.count == rowCount, "\(histories.count) histories for \(rowCount) rows")
        self.scale = scale
        let rowPixels = rowHeightPoints * scale
        for row in 0..<rowCount {
            let history = histories[row]
            percents[row] = history.count == 0 ? 0 : Self.percent(history[history.count - 1].total)
            let empty = columnCount - min(history.count, columnCount)
            let first = history.count - (columnCount - empty)
            for column in 0..<columnCount {
                var bar = Column()
                if column >= empty {
                    let load = history[first + column - empty]
                    bar.systemPixels = Self.pixels(load.system, of: rowPixels)
                    bar.totalPixels = Self.pixels(load.total, of: rowPixels)
                }
                columns[row * columnCount + column] = bar
            }
        }
    }

    func column(row: Int, column: Int) -> Column { columns[row * columnCount + column] }

    /// A share of time, 0...1, as a whole percent.
    static func percent(_ share: Double) -> Int {
        Int((min(max(share, 0), 1) * 100).rounded())
    }

    private static func pixels(_ share: Double, of rowPixels: Double) -> Int16 {
        Int16((min(max(share, 0), 1) * rowPixels).rounded())
    }
}
