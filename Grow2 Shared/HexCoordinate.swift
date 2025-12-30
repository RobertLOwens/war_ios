import Foundation

struct HexCoordinate: Hashable {
    let q: Int  // column
    let r: Int  // row
    
    func distance(to other: HexCoordinate) -> Int {
        // Cube coordinate distance formula for offset coordinates
        return (abs(q - other.q) + abs(q + r - other.q - other.r) + abs(r - other.r)) / 2
    }
    
    // Get neighboring coordinates
    func neighbors() -> [HexCoordinate] {
        let directions = [
            HexCoordinate(q: 1, r: 0), HexCoordinate(q: 1, r: -1),
            HexCoordinate(q: 0, r: -1), HexCoordinate(q: -1, r: 0),
            HexCoordinate(q: -1, r: 1), HexCoordinate(q: 0, r: 1)
        ]
        return directions.map { HexCoordinate(q: q + $0.q, r: r + $0.r) }
    }
}
