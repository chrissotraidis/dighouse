import CoreLocation
import SwiftUI

/// Where a project's ground is, read from its private folder. It is shown on this Mac and written nowhere else.
struct Whereabouts: Equatable, Sendable {
    /// The boxes of ground the project holds, as west, south, east, north.
    var boxes: [[Double]] = []
    /// The nearest town, once the person asked Apple Maps for it. Kept with the other locations, in the private folder.
    var near: String?

    var isEmpty: Bool { boxes.isEmpty }
    var lon: Double { ((boxes.map { $0[0] }.min() ?? 0) + (boxes.map { $0[2] }.max() ?? 0)) / 2 }
    var lat: Double { ((boxes.map { $0[1] }.min() ?? 0) + (boxes.map { $0[3] }.max() ?? 0)) / 2 }
    /// The country or region the open data names here, such as Norway. Nil outside them.
    var region: String? { isEmpty ? nil : Reach.place(lon: lon, lat: lat) }
    var km2: Double {
        boxes.reduce(0) { $0 + ($1[2] - $1[0]) * 111.32 * cos(($1[1] + $1[3]) / 2 * .pi / 180) * ($1[3] - $1[1]) * 110.54 }
    }

    /// "Norway · 3 areas · 14.2 square km", or as much of it as is known.
    var words: String {
        guard !isEmpty else { return "No area set yet" }
        return [region, boxes.count > 1 ? "\(boxes.count) areas" : nil,
                "\(km2.formatted(.number.precision(.fractionLength(km2 < 10 ? 1 : 0)))) square km"].compactMap { $0 }.joined(separator: " · ")
    }

    /// Each fetched area's own box where the project kept it, or else the project's one box.
    nonisolated static func read(_ root: String) -> Whereabouts {
        func real(_ b: [Double]) -> Bool { b.count == 4 && b[2] > b[0] && b[3] > b[1] && (abs(b[0] + b[2]) > 0.02 || abs(b[1] + b[3]) > 0.02) }
        func json(_ file: String) -> JSON? {
            FileManager.default.contents(atPath: root + "/private/state/" + file).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? JSON
        }
        let near = json("near.json")?["near"] as? String
        let areas = (json("terrains.json") ?? [:]).values.compactMap { ($0 as? JSON)?["lonlat"] as? [Double] }.filter(real)
        if !areas.isEmpty { return Whereabouts(boxes: areas, near: near) }
        if let box = json("project.json")?["bbox"] as? [Double], real(box) { return Whereabouts(boxes: [box], near: near) }
        return Whereabouts()
    }

    /// The state a USGS survey was flown in, from the survey's own name: "usgs:AZ_Yavapai_2_2021" is Arizona. Read on
    /// this Mac, so it tells nobody. Nil for ground whose name carries no state.
    nonisolated static func usState(_ datasets: [String]) -> String? {
        let names = Set(datasets.compactMap { dataset -> String? in
            guard dataset.hasPrefix("usgs:") else { return nil }
            let code = dataset.dropFirst(5).prefix(2)
            return dataset.dropFirst(7).hasPrefix("_") ? states[String(code)] : nil
        })
        return names.count == 1 ? names.first : nil
    }

    private static let states: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California", "CO": "Colorado", "CT": "Connecticut",
        "DE": "Delaware", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa",
        "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan",
        "MN": "Minnesota", "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada", "NH": "New Hampshire",
        "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York", "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
        "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota", "TN": "Tennessee",
        "TX": "Texas", "UT": "Utah", "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming",
    ]

    /// Ask Apple Maps for the town nearest the middle of the ground, and keep the answer in the project's private
    /// folder. The person asks for it: Apple then sees where this ground is.
    @MainActor
    static func nameNearest(_ place: Whereabouts, in root: String) async -> String? {
        guard !place.isEmpty,
              let mark = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: place.lat, longitude: place.lon)).first else { return nil }
        let town = mark.locality ?? mark.subAdministrativeArea ?? mark.inlandWater ?? mark.ocean
        let near = [town, mark.administrativeArea].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        guard !near.isEmpty else { return nil }
        if let data = try? JSONSerialization.data(withJSONObject: ["near": near]) {
            try? data.write(to: URL(fileURLWithPath: root + "/private/state/near.json"))
        }
        return near
    }

    /// Open Apple Maps at the middle of the ground. The person asks for it: Apple then sees where they look.
    func openInMaps() {
        guard !isEmpty, let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)&z=12&t=k") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// A small map of the land around a place, drawn from the app's own outlines: nothing is asked of a map service, so
/// showing where a project is tells nobody.
struct Locator: View {
    let lon: Double, lat: Double
    /// How many degrees of longitude the map shows.
    var span: Double = 50

    var body: some View {
        // Where the open data names a country here, the map shows that whole country, so the ring reads as a place in
        // it: the south-west of the United States, the east of Norway. Elsewhere it is centred on the ring.
        let whole = Reach.frame(lon: lon, lat: lat)
        Canvas { context, size in
            let middle = whole.map { ($0.lon, $0.lat) } ?? (lon, lat)
            // A degree of latitude is drawn longer than one of longitude, as it is on the ground this far from the equator.
            let stretch = CGFloat(max(cos(middle.1 * .pi / 180), 0.2))
            let wide = whole.map { max($0.width, $0.height * Double(size.width / size.height) / Double(stretch)) * 1.2 } ?? span
            let perLon = size.width / CGFloat(max(wide, 6)), perLat = perLon / stretch
            let west = middle.0 - Double(size.width / perLon) / 2, north = middle.1 + Double(size.height / perLat) / 2
            func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: CGFloat(x - west) * perLon, y: CGFloat(north - y) * perLat) }
            func path(_ ring: [Double]) -> Path {
                var p = Path()
                var i = 0
                while i + 1 < ring.count {
                    i == 0 ? p.move(to: point(ring[i], ring[i + 1])) : p.addLine(to: point(ring[i], ring[i + 1]))
                    i += 2
                }
                p.closeSubpath()
                return p
            }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.side))
            for ring in CoverageMap.land { context.fill(path(ring), with: .color(Theme.ink.opacity(0.17))) }
            // Where open lidar reaches, faintly, as on the other maps.
            context.fill(path(Reach.unitedStates), with: .color(Theme.tan.opacity(0.3)))
            for country in Reach.national { context.fill(path(country.ring), with: .color(Theme.green.opacity(0.22))) }
            let here = point(lon, lat)
            context.fill(Path(ellipseIn: CGRect(x: here.x - 13, y: here.y - 13, width: 26, height: 26)), with: .color(Theme.accent.opacity(0.18)))
            context.stroke(Path(ellipseIn: CGRect(x: here.x - 7, y: here.y - 7, width: 14, height: 14)), with: .color(Theme.accent), lineWidth: 2)
            context.fill(Path(ellipseIn: CGRect(x: here.x - 2.5, y: here.y - 2.5, width: 5, height: 5)), with: .color(.white))
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
        .accessibilityElement().accessibilityLabel("A small map with a ring where this ground is")
    }
}

/// Where a find's tile sits among the tiles of its area, and the find inside it.
struct TileGrid: View {
    /// Every tile cut from the same ground.
    let tiles: [Tile]
    let current: String
    /// The find's place in its tile, as fractions from the top left.
    let x: Double, y: Double

    var body: some View {
        Canvas { context, size in
            guard let left = tiles.map(\.col).min(), let top = tiles.map(\.row).min(),
                  let right = tiles.map({ $0.col + $0.cols }).max(), let bottom = tiles.map({ $0.row + $0.rows }).max(),
                  right > left, bottom > top else { return }
            let scale = min(size.width / CGFloat(right - left), size.height / CGFloat(bottom - top))
            let dx = (size.width - CGFloat(right - left) * scale) / 2, dy = (size.height - CGFloat(bottom - top) * scale) / 2
            func rect(_ t: Tile) -> CGRect {
                CGRect(x: dx + CGFloat(t.col - left) * scale, y: dy + CGFloat(t.row - top) * scale, width: CGFloat(t.cols) * scale, height: CGFloat(t.rows) * scale)
            }
            // Tiles overlap, so each is an outline over a faint fill: the grid shows, and unlooked-at tiles stay darker.
            for tile in tiles where tile.id != current {
                context.fill(Path(rect(tile)), with: .color(Theme.ink.opacity(tile.status == "unscreened" ? 0.02 : 0.05)))
                context.stroke(Path(rect(tile)), with: .color(Theme.ink.opacity(0.2)), lineWidth: 0.5)
            }
            if let tile = tiles.first(where: { $0.id == current }) {
                let r = rect(tile)
                context.fill(Path(r), with: .color(Theme.tan.opacity(0.85)))
                let p = CGPoint(x: r.minX + r.width * CGFloat(x), y: r.minY + r.height * CGFloat(y))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(.black.opacity(0.7)))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(Theme.accent))
            }
        }
        .accessibilityElement().accessibilityLabel("The tiles of this area, with the find's tile marked")
    }
}

/// A cut through the ground at a find, drawn from the grid of heights kept for the 3D view: west to east or north to
/// south, through the find. Point at it to read how far along and how high.
struct SliceChart: View {
    let surface: Relief3D.Surface
    let northSouth: Bool
    @State private var at: CGFloat?

    /// How much ground the slice shows: the same 60 m as the close view beside it.
    private static let metres: Float = 60

    /// The heights along the cut, in metres above the lowest ground of the square, and how long the cut is: 60 m with
    /// the find in the middle, or less where the find is near the edge of the ground.
    private var profile: (values: [Float], length: Float) {
        let whole: [Float], along: Float, across: Float
        if northSouth {
            let i = Int((surface.find.0 * Float(surface.nx - 1)).rounded())
            (whole, along, across) = ((0..<surface.ny).map { surface.height(i, $0) }, surface.find.1, surface.depth)
        } else {
            let j = Int((surface.find.1 * Float(surface.ny - 1)).rounded())
            (whole, along, across) = ((0..<surface.nx).map { surface.height($0, j) }, surface.find.0, surface.width)
        }
        guard whole.count > 2, across > 0 else { return (whole, across) }
        let middle = Int((along * Float(whole.count - 1)).rounded()), half = Int(Self.metres / 2 / across * Float(whole.count - 1))
        let from = max(middle - half, 0), to = min(middle + half, whole.count - 1)
        return (Array(whole[from...to]), across * Float(to - from) / Float(whole.count - 1))
    }

    var body: some View {
        let values = profile.values
        let length = CGFloat(max(profile.length, 1))
        let low = CGFloat(values.min() ?? 0), high = CGFloat(values.max() ?? 1)
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in
                guard values.count > 1 else { return }
                let px = size.width / length
                // Heights are stretched by a whole number when a true scale would draw a low rise as a flat line.
                let stretch = max(1, min(10, ((size.height * 0.5) / (max(high - low, 0.3) * px)).rounded(.down)))
                let floor = size.height - 30
                func point(_ i: Int) -> CGPoint {
                    CGPoint(x: size.width * CGFloat(i) / CGFloat(values.count - 1), y: floor - (CGFloat(values[i]) - low) * px * stretch)
                }
                var line = Path()
                for i in values.indices { i == 0 ? line.move(to: point(i)) : line.addLine(to: point(i)) }
                var fill = line
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(Gradient(colors: [Theme.tan.opacity(0.3), Theme.tan.opacity(0.04)]),
                                                         startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
                context.stroke(line, with: .color(Theme.tan), lineWidth: 2)
                // A person 1.70 m tall, standing near the start of the slice, clear of the find in the middle.
                let here = point(values.count / 10)
                let tall = 1.7 * px * stretch
                context.stroke(Path { $0.move(to: here); $0.addLine(to: CGPoint(x: here.x, y: here.y - tall)) }, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                context.fill(Path(ellipseIn: CGRect(x: here.x - 2.5, y: here.y - tall - 5, width: 5, height: 5)), with: .color(.white.opacity(0.9)))
                // Ten metres along the ground, and which end is which.
                let bar = CGRect(x: 10, y: size.height - 12, width: 10 * px, height: 2)
                context.fill(Path(bar), with: .color(Theme.dim))
                context.draw(Text("10 m").font(.system(size: 10.5 * Theme.scale)).foregroundColor(Theme.dim), at: CGPoint(x: bar.maxX + 6, y: bar.midY), anchor: .leading)
                context.draw(Text(northSouth ? "N" : "W").font(.system(size: 10.5 * Theme.scale, weight: .semibold)).foregroundColor(Theme.faint),
                             at: CGPoint(x: 8, y: 10), anchor: .leading)
                context.draw(Text(northSouth ? "S" : "E").font(.system(size: 10.5 * Theme.scale, weight: .semibold)).foregroundColor(Theme.faint),
                             at: CGPoint(x: size.width - 8, y: 10), anchor: .trailing)
                if stretch > 1 {
                    context.draw(Text("Heights drawn ×\(Int(stretch))").font(.system(size: 10.5 * Theme.scale)).foregroundColor(Theme.faint),
                                 at: CGPoint(x: size.width - 10, y: size.height - 11), anchor: .trailing)
                }
                // Under the pointer: a line, a dot on the ground, and the two numbers.
                if let at, at >= 0, at <= size.width {
                    let i = min(max(Int((at / size.width * CGFloat(values.count - 1)).rounded()), 0), values.count - 1)
                    let p = point(i)
                    context.stroke(Path { $0.move(to: CGPoint(x: p.x, y: 20)); $0.addLine(to: CGPoint(x: p.x, y: size.height)) },
                                   with: .color(Theme.ink.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(Theme.accent))
                    let metres = Double(length) * Double(i) / Double(values.count - 1)
                    let words = "\(Int(metres.rounded())) m along · \((Double(values[i]) - Double(low)).formatted(.number.precision(.fractionLength(1)))) m up"
                    context.draw(Text(words).font(.system(size: 11.5 * Theme.scale, weight: .semibold)).foregroundColor(Theme.text),
                                 at: CGPoint(x: min(max(p.x, 70), size.width - 70), y: 10), anchor: .center)
                }
            }
            .frame(height: 204)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.side))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active(let p) = phase { at = p.x } else { at = nil }
            }
            Text("Point at the slice to read a height. The ground \(northSouth ? "north to south" : "west to east") through the find, the same \(Int((length / 10).rounded() * 10)) m as the close view. The white figure is a person 1.70 m tall.")
                .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement()
        .accessibilityLabel("A slice \(northSouth ? "north to south" : "west to east") through the find, \(Int(length)) metres long. The ground rises \(Double(high - low).formatted(.number.precision(.fractionLength(1)))) metres along it.")
    }
}

/// How much of the account's usage is left, as a small dial that empties: green, then amber when little is left.
struct UsageDial: View {
    let left: Int
    var size: CGFloat = 22
    /// The number in the middle, for the larger dial in Settings; the small one carries the trowel.
    var number = false

    private var color: Color { left < AppState.opinionFloor ? Theme.amber : Theme.green }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.ink.opacity(0.14), lineWidth: size * 0.13)
            Circle().trim(from: 0, to: max(0.04, CGFloat(min(max(left, 0), 100)) / 100))
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round)).rotationEffect(.degrees(-90))
            if number {
                Text("\(left)%").font(.system(size: size * 0.27, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.text)
            } else {
                Glyph(name: "dig.trowel", size: size * 0.4, weight: .medium).foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .animation(Motion.ease(0.3), value: left)
        .accessibilityElement().accessibilityLabel("\(left) percent of your plan's usage is left")
    }
}

/// Where the open project's ground is: a small map, the region, its areas and their size, read from its private folder.
struct WherePanel: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @State private var place = Whereabouts()
    @State private var naming = false
    @State private var unnamed = false

    var body: some View {
        // A stack rather than a Group: an empty Group is no view at all, so its task would never start.
        VStack(spacing: 0) {
            if !place.isEmpty {
                let areas = Set(store.terrains.compactMap(\.area)).sorted()
                HStack(alignment: .center, spacing: 14) {
                    Locator(lon: place.lon, lat: place.lat).frame(width: 190, height: 104)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Where").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                        // The state comes from the survey's own name, and the town only once the person asks for it.
                        let state = Whereabouts.usState(store.terrains.map(\.dataset))
                        let named = [state, place.region].compactMap { $0 }.joined(separator: ", ")
                        Text(named.isEmpty ? "Its own ground" : named)
                            .font(.system(size: 16 * Theme.scale, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        if let near = place.near {
                            Text("Near \(near)").font(.system(size: 13 * Theme.scale, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                        }
                        Text(([place.boxes.count > 1 ? "\(place.boxes.count) areas" : nil,
                               "\(place.km2.formatted(.number.precision(.fractionLength(place.km2 < 10 ? 1 : 0)))) square km"].compactMap { $0 }
                              + (areas.isEmpty ? [] : [areas.prefix(3).joined(separator: ", ") + (areas.count > 3 ? " and \(areas.count - 3) more" : "")]))
                            .joined(separator: " · "))
                            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        Label("Shown on this Mac only", systemImage: "lock").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 6) {
                        // Offered only while the map is out of sight: beside the map it would change nothing.
                        if app.layout == .chat || app.tab != .map {
                            Button { app.tab = .map; app.route = .chat; if app.layout == .chat { app.layout = .split } } label: {
                                Label("The project's map", systemImage: "map")
                            }
                            .buttonStyle(SecondaryButton()).help("The ground, the tiles and every find, on the project's own map.")
                        }
                        if place.near == nil {
                            Button {
                                guard let root = store.current?.path else { return }
                                naming = true
                                Task {
                                    if let near = await Whereabouts.nameNearest(place, in: root) { place.near = near } else { unnamed = true }
                                    naming = false
                                }
                            } label: { Label(naming ? "Asking…" : unnamed ? "No town found" : "Name the nearest town", systemImage: "mappin.and.ellipse") }
                                .buttonStyle(SecondaryButton()).disabled(naming || unnamed)
                                .help("Asks Apple Maps for the town nearest the middle of this ground, and keeps the answer in the project. Apple then sees where this ground is.")
                        }
                        Button { place.openInMaps() } label: { Label("Open in Maps", systemImage: "arrow.up.right") }
                            .buttonStyle(SecondaryButton()).help("Opens Apple Maps at the middle of this ground. Apple then sees where you look.")
                    }
                }
                .padding(12).panel()
            }
        }
        .task(id: "\(store.current?.path ?? "") \(store.terrains.count)") {
            guard let root = store.current?.path else { place = Whereabouts(); return }
            place = await Task.detached { Whereabouts.read(root) }.value
        }
    }
}

/// Where a find is, in two small pictures and a few words: its project and region, its area, and its tile among the
/// area's tiles. Then what the pictures under it are.
struct FindWhere: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    let candidate: Candidate
    @State private var place = Whereabouts()

    var body: some View {
        let c = candidate
        let tile = store.tiles.first { $0.id == c.tile }
        let ground = store.terrains.first { $0.id == tile?.terrain }
        let neighbours = store.tiles.filter { $0.terrain == tile?.terrain }
        // The area's own box where it was kept, or else the whole project's.
        let spot = (ground?.lonlat.count == 4 ? ground.map { Whereabouts(boxes: [$0.lonlat]) } : nil) ?? place
        let number = neighbours.firstIndex { $0.id == c.tile }.map { $0 + 1 }
        HStack(alignment: .center, spacing: 12) {
            if !spot.isEmpty {
                Locator(lon: spot.lon, lat: spot.lat).frame(width: 112, height: 60)
                    .help("Where this area is. Drawn by Dighouse, so no map service is asked.")
            }
            if neighbours.count > 1 {
                TileGrid(tiles: neighbours, current: c.tile, x: c.x, y: c.y).frame(width: 76, height: 60)
                    .help("The tiles of this area. The find's tile is tan, and the dot is the find.")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text([store.current?.name, place.near.map { "near \($0)" } ?? Whereabouts.usState(store.terrains.map(\.dataset)), spot.region]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13.5 * Theme.scale, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Text([ground?.area.map { "Area \($0)" }, number.map { "tile \($0) of \(neighbours.count)" }, ground?.source.isEmpty == false ? ground?.source : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                Text("A shape marked in the bare ground. Below: the same spot close up, its whole tile, and a cut through it. Its place shows on this Mac only.")
                    .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Button {
                    store.selectedCandidate = c.id
                    app.tab = .map
                    if app.layout == .chat { app.layout = .split }
                    app.reviewing = false
                } label: { Label("Show on the map", systemImage: "map") }
                    .buttonStyle(SecondaryButton()).help("Closes Decide and shows this find on the project's map.")
                if !spot.isEmpty {
                    Button { spot.openInMaps() } label: { Label("Open in Maps", systemImage: "arrow.up.right") }
                        .buttonStyle(SecondaryButton()).help("Opens Apple Maps at the middle of this area. Apple then sees where you look.")
                }
            }
        }
        .padding(8).panel(radius: 12)
        .task(id: store.current?.path) {
            guard let root = store.current?.path else { return }
            place = await Task.detached { Whereabouts.read(root) }.value
        }
    }
}
