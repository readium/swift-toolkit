import Foundation

struct OPDSCatalog: Identifiable, Equatable {
    let id: String
    var title: String
    var url: URL
    
    var toDictionary: [String: String] {
        [
            "id": id,
            "title": title,
            "url": url.absoluteString
        ]
    }
}

extension OPDSCatalog {
    init?(dictionary: [String: String]) {
        guard
            let title = dictionary["title"],
            let url = URL(string: dictionary["url"] ?? "")
        else { return nil }
        
        self.id = dictionary["id"] ?? UUID().uuidString
        self.title = title
        self.url = url
    }
}
