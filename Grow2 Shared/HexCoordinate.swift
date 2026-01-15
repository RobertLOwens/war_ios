import Foundation

struct HexCoordinate: Hashable, Codable {
    let q: Int  // column
    let r: Int  // row
    
    func distance(to other: HexCoordinate) -> Int {
        // ✅ FIXED: Convert odd-r offset to cube coordinates for accurate distance
        // Convert self to cube
        let x1 = q - (r - (r & 1)) / 2
        let z1 = r
        let y1 = -x1 - z1
        
        // Convert other to cube
        let x2 = other.q - (other.r - (other.r & 1)) / 2
        let z2 = other.r
        let y2 = -x2 - z2
        
        // Cube distance
        return (abs(x1 - x2) + abs(y1 - y2) + abs(z1 - z2)) / 2
    }
    
    func neighbors() -> [HexCoordinate] {
        // ✅ FIXED: Proper odd-r offset coordinate neighbors
        // Neighbor offsets depend on whether row is even or odd
        let directions: [(Int, Int)]
        
        if r % 2 == 0 {
            // Even rows
            directions = [
                (1, 0),   // East
                (0, 1),   // Southeast
                (-1, 1),  // Southwest
                (-1, 0),  // West
                (-1, -1), // Northwest
                (0, -1)   // Northeast
            ]
        } else {
            // Odd rows (shifted right)
            directions = [
                (1, 0),   // East
                (1, 1),   // Southeast
                (0, 1),   // Southwest
                (-1, 0),  // West
                (0, -1),  // Northwest
                (1, -1)   // Northeast
            ]
        }
        
        return directions.map { HexCoordinate(q: q + $0.0, r: r + $0.1) }
    }

}
