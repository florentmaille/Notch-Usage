import Foundation

enum Fixture {
    static func data(_ name: String) -> Data {
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        guard let url = Bundle.module.url(forResource: parts[0], withExtension: parts.count > 1 ? parts[1] : nil, subdirectory: "Fixtures") else {
            fatalError("Fixture introuvable : \(name)")
        }
        return try! Data(contentsOf: url)
    }

    static func string(_ name: String) -> String {
        String(decoding: data(name), as: UTF8.self)
    }
}

extension Date {
    static func iso(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)!
    }
}
