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

    /// Returns the neighbor in a specific direction (0-5)
    /// Direction order (clockwise from East): 0=East, 1=Southeast, 2=Southwest, 3=West, 4=Northwest, 5=Northeast
    func neighbor(inDirection direction: Int) -> HexCoordinate {
        let allNeighbors = neighbors()
        let normalizedDir = ((direction % 6) + 6) % 6
        return allNeighbors[normalizedDir]
    }

    /// Returns all coordinates at exactly the given distance (a ring around this coordinate)
    func coordinatesInRing(distance: Int) -> [HexCoordinate] {
        guard distance > 0 else { return [self] }

        var results: [HexCoordinate] = []

        // Start at the "west" position at the given distance
        var current = self
        for _ in 0..<distance {
            current = current.neighbor(inDirection: 3)  // West
        }

        // Walk around the ring in all 6 directions
        for direction in 0..<6 {
            for _ in 0..<distance {
                results.append(current)
                current = current.neighbor(inDirection: direction)
            }
        }

        return results
    }

    /// Returns all coordinates within the given distance (filled circle)
    func coordinatesWithinRange(range: Int) -> [HexCoordinate] {
        var results: [HexCoordinate] = [self]

        for distance in 1...range {
            results.append(contentsOf: coordinatesInRing(distance: distance))
        }

        return results
    }

}
