import Foundation

/* struct RecordSource {
    var domain: String
    var url: NSURL
    
    init(domain: String, url: NSURL) {
        self.domain = domain
        self.url = url
    }
} */

class Record: NSObject, NSCoding {
    var id: Int
    var author: String
    var title: String
    var readDate: NSDate?
    var year: String
    var station: String

    // "id": 1332,
    // "createAt": "2012-04-08T18:28:27+04:00",
    // "editAt": "2012-04-08T18:28:27+04:00",
    // "author": "Сергей Цветков",
    // "name": "Посредник",
    // "readedAt": "2012-04-05T00:00:00+04:00",
    // "radioStation": "Пионер FM",
    // "following": 2
    
    init(id: Int, author: String, title: String, readDate dateString: String, station: String) {
        self.id = id
        self.author = author
        self.title = title

        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxx" /*find out and place date format from http://userguide.icu-project.org/formatparse/datetime*/
        if let readDate = dateFormatter.dateFromString(dateString) {
            let calendar = NSCalendar.currentCalendar()
            let components = calendar.components(.CalendarUnitYear, fromDate: readDate)
            self.readDate = readDate
            self.year = String(components.year)
        }
        else {
            self.year = ""
        }

        self.station = station

        /* for source in sources {
	        if let source = source as? [String: AnyObject] {
                if let domain = source["domain"] as? String {
                    if let urlString = source["url"] as? String {
                        if let url = NSURL(string: urlString) {
                            self.sources?.append(RecordSource(domain: domain, url: url))
                        }
                    }
                }
	        }
        } */
    }
    
    required init(coder aDecoder: NSCoder) {
        id = aDecoder.decodeIntegerForKey("Id")
        author = aDecoder.decodeObjectForKey("Author") as! String
        title = aDecoder.decodeObjectForKey("Title") as! String
        readDate = aDecoder.decodeObjectForKey("ReadDate") as! NSDate?
        year = aDecoder.decodeObjectForKey("Year") as! String
        station = aDecoder.decodeObjectForKey("Station") as! String

        super.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeInteger(id, forKey: "Id")
        aCoder.encodeObject(author, forKey: "Author")
        aCoder.encodeObject(title, forKey: "Title")
        aCoder.encodeObject(readDate, forKey: "ReadDate")
        aCoder.encodeObject(year, forKey: "Year")
        aCoder.encodeObject(station, forKey: "Station")
    }
}