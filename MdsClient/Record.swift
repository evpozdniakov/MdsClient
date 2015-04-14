import Foundation

var getRecordAudioDataTask: NSURLSessionDataTask?

class Record: NSObject, NSCoding {
    /*
        "id": 1332,
        "createAt": "2012-04-08T18:28:27+04:00",
        "editAt": "2012-04-08T18:28:27+04:00",
        "author": "Сергей Цветков",
        "name": "Посредник",
        "readedAt": "2012-04-05T00:00:00+04:00",
        "radioStation": "Пионер FM",
        "following": 2 
    */

    var id: Int
    var author: String
    var title: String
    var readDate: NSDate?
    var year: String
    var station: String
    var tracks: [Track]
    var hasNoTracks: Bool

    // #MARK: - initializers
    
    init(id: Int, author: String, title: String, readDate: NSDate?, year: String, station: String, tracks: [Track], hasNoTracks: Bool) {
        self.id = id
        self.author = author
        self.title = title
        self.readDate = readDate
        self.year = year
        self.station = station
        self.tracks = tracks
        self.hasNoTracks = hasNoTracks
    }

    convenience init(id: Int, author: String, title: String, readDate dateString: String, station: String) {
        var readDate: NSDate?
        var year = ""
        let tracks = [Track]()
        let hasNoTracks = false
        let dateFormatter = NSDateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxx" /*find out and place date format from http://userguide.icu-project.org/formatparse/datetime*/
        if let date = dateFormatter.dateFromString(dateString) {
            let calendar = NSCalendar.currentCalendar()
            let components = calendar.components(.CalendarUnitYear, fromDate: date)
            readDate = date
            year = String(components.year)
        }

        self.init(id: id, author: author, title: title, readDate: readDate, year: year, station: station, tracks: tracks, hasNoTracks: hasNoTracks)
    }
    
    required init(coder aDecoder: NSCoder) {
        id = aDecoder.decodeIntegerForKey("Id")
        author = aDecoder.decodeObjectForKey("Author") as! String
        title = aDecoder.decodeObjectForKey("Title") as! String
        readDate = aDecoder.decodeObjectForKey("ReadDate") as! NSDate?
        year = aDecoder.decodeObjectForKey("Year") as! String
        station = aDecoder.decodeObjectForKey("Station") as! String
        tracks = aDecoder.decodeObjectForKey("Tracks") as! [Track]
        hasNoTracks = aDecoder.decodeBoolForKey("HasNoTracks")

        super.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeInteger(id, forKey: "Id")
        aCoder.encodeObject(author, forKey: "Author")
        aCoder.encodeObject(title, forKey: "Title")
        aCoder.encodeObject(readDate, forKey: "ReadDate")
        aCoder.encodeObject(year, forKey: "Year")
        aCoder.encodeObject(station, forKey: "Station")
        aCoder.encodeObject(tracks, forKey: "Tracks")
        aCoder.encodeBool(hasNoTracks, forKey: "HasNoTracks")
    }

    // #MARK: - work with tracks

    // if the record has tracks, returns first playable record
    // otherwise initializes tracks json downloading/parsing
    func getFirstPlayableTrack(completionHandler: (Track?) -> Void) {
        if hasNoTracks {
            completionHandler(nil)
        }
        else if tracks.count > 0 {
            completionHandler(tracks[0])
        }
        else {
            downloadAndParseTracksJson() {
                if self.tracks.count > 0 {
                    completionHandler(self.tracks[0])
                }
                else {
                    completionHandler(nil)
                }
            }
        }
    }

    // will parse json and fill tracks
    func fillTracksWithJson(json: [AnyObject]) {
        var tracks = [Track]()

        for entry in json {
            if let entry = entry as? [String: AnyObject] {

                // id = 12772;
                // bitrate = 168kbps;
                // channels = Stereo;
                // mode = VBR;
                // size = 11141120;
                // url = "http://mds.mds-club.ru/Kir_Bulychev_-_Oni_uzhe_zdes'!.mp3";

                if let id = entry["id"] as? Int,
                    let bitrate = entry["bitrate"] as? String,
                    let channels = entry["channels"] as? String,
                    let mode = entry["mode"] as? String,
                    let size = entry["size"] as? Int,
                    let urlString = entry["url"] as? String {
                        if let url = NSURL(string:urlString) {
                            let track = Track(id: id, bitrate: bitrate, channels: channels, mode: mode, size: size, url: url)
                            tracks.append(track)
                        }
                        else {
                            // #FIXME: problem with creaing url
                        }
                }
                else {
                    // #FIXME: unable to parse json entry
                }
            }
            else {
                // #FIXME: unable to parse json
            }
        }

        if tracks.count > 0 {
            self.tracks = tracks
        }
        else {
            hasNoTracks = true
        }
    }

    // ASYNC
    // downloads record tracks json data
    // when done, 
    func downloadAndParseTracksJson(completionHandler: Void -> Void) {
        let urlString = "http://core.mds-club.ru/api/v1.0/mds/records/\(id)/files/?access-token=" + Access.generateToken()

        getRecordAudioDataTask?.cancel()
        getRecordAudioDataTask = Ajax.getJsonByUrlString(urlString) { data in
            if let json = Ajax.parseJsonArray(data) {
                self.fillTracksWithJson(json)
            }
            else {
                self.hasNoTracks = true
            }

            completionHandler()
        }
    }

}