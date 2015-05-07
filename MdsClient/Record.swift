import Foundation

protocol RecordDownload {
    func startDownloading()
    func cancelDownloading()
    func downloadTrack(track: Track)
    func reportDownloadingProgress(bytesDownloaded: Int64, bytesTotal: Int64)
}

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

    // var isPlaying: Bool

    // #FIXME: how to store those vars?
    var downloadingProgress: Float?
    var downloadTask: NSURLSessionDownloadTask?
    var isDownloading = false

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
        // self.isPlaying = false
    }

    convenience init(id: Int, author: String, title: String, readDate dateString: String, station: String) {
        var readDate: NSDate?
        var year = ""
        let tracks = [Track]()
        let hasNoTracks = false
        // let isPlaying = false
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
        // isPlaying = aDecoder.decodeBoolForKey("IsPlaying")

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
        // aCoder.encodeBool(isPlaying, forKey: "IsPlaying")
    }

    // #MARK: - work with tracks

    // if the record has tracks, returns first track with http protocol
    // otherwise initializes tracks json downloading/parsing
    func getFirstPlayableTrack(completionHandler: (Track?) -> Void) {
        println("call Playlist.getFirstPlayableTrack() ")
        if hasNoTracks {
            println("has no track")
            completionHandler(nil)
        }
        else if tracks.count > 0 {
            println("tracks exist, no need to download")
            completionHandler(getAnyTrackWithHttpProtocol())
        }
        else {
            downloadAndParseTracksJson() {
                if self.tracks.count > 0 {
                    println("tracks has been downloaded: \(self.tracks)")
                    completionHandler(self.getAnyTrackWithHttpProtocol())
                }
                else {
                    completionHandler(nil)
                }
            }
        }
    }

    func getAnyTrackWithHttpProtocol() -> Track? {
        for track in tracks {
            let scheme = track.url.scheme

            if scheme == "http" || scheme == "https" {
                return track
            }
        }

        println("call reportBroken 1")
        reportBroken()

        return nil
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
            println("call reportBroken 2")
            reportBroken()
        }
    }

    // ASYNC
    // downloads record tracks json data
    // when done,
    func downloadAndParseTracksJson(completionHandler: Void -> Void) {
        println("call downloadAndParseTracksJson")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let urlString = "http://core.mds-club.ru/api/v1.0/mds/records/\(self.id)/files/?access-token=" + Access.generateToken()

            println("dispatch async")

            Ajax.getJsonByUrlString(urlString,
                                    success: { data in
                                        println("clojure with data: \(data)")
                                        if let json = Ajax.parseJsonArray(data) {
                                            println("will call fillTracksWithJson")
                                            self.fillTracksWithJson(json)
                                        }
                                        else {
                                            println("call reportBroken 3")
                                            self.reportBroken()
                                        }

                                        completionHandler()
                                    },
                                    fail: {
                                        println("++++++++++retry")
                                        self.downloadAndParseTracksJson(completionHandler)
                                    })
        }
    }

    /**
        Will connect ios.bumagi.net to report broken record

        Usage:

            reportBroken()
    */
    func reportBroken() {
        hasNoTracks = true

        if let escapedTitle = title.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) {
            let urlString = "http://ios.bumagi.net/api/mds-broken-track.php?rid=\(id)&title=\(escapedTitle)"

            if let url = NSURL(string: urlString) {
                Ajax.get(url: url,
                        success: { data in
                            println("broken record reported with url: \(url)")
                        },
                        fail: nil)
            }
            else {
                println("cant create URL with \(urlString)")
            }
        }
    }
}

extension Record: RecordDownload {
    /**
        Mark record as downloading, gets first track and initiates track downloading.
        Marks record as hasNotTracks if no tracks found.

        **Warning:** Works asynchronously.

        Usage:

            startDownloading()
    */
    func startDownloading() {
        println("call Playlist.startDownloading() for record: \(title)")
        isDownloading = true
        getFirstPlayableTrack() { track in
            if let track = track {
                println("track found for record: \(self.title)")
                // make sure the record is still in playlist
                if self.isDownloading {
                    println("record in still in playlist, start download track: \(track.url)")
                    self.downloadTrack(track)
                }
                else {
                    println("it looks like the record is not in playlist any more")
                }
            }
            else {
                println("---has no tracks for record: \(self.title)---")
                self.hasNoTracks = true
                self.isDownloading = false
                // #FIXME: display this record with ! sign in playlist tab
                // // no tracks found
                // throwErrorMessage("Файл mp3 не найден на сервере.", inViewController: self) {
                //     self.redrawRecordsAtIndexPaths([indexPath])
                // }
            }
        }
    }

    /**
        Initiates track downloading process. Creates localURL to store file locally.

        Usage:

            record.downloadTrack(track)

        :param: track: Track
    */
    func downloadTrack(track: Track) {
        println("call downloadTrack, url: \(track.url)")
        let fileManager = NSFileManager.defaultManager()
        let documentDirs = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)

        if documentDirs.count == 0 {
            // #FIXME: handle the error
            println("Error: NSFileManager didn't find document directory")
            return
        }

        let documentDir = documentDirs[0] as! NSURL

        if track.url.pathExtension == "" {
            // #FIXME:handle error
            println("Error: file path [\(track.url)] doesn't have file name")
            return
        }

        if let fileName = track.url.lastPathComponent {
            let localURL = documentDir.URLByAppendingPathComponent(fileName)

            downloadTask = Ajax.downloadFileFromUrl(track.url, saveTo: localURL, reportingProgress: reportDownloadingProgress) {
                println("file dowloaded and may be saved")

                // #FIXME: check if file has been saved to localURL
                self.downloadTask = nil
            }

            println("downloadTask created: \(downloadTask)")


        }
        else {
            // #FIXME: handle the error
            println("Error: lastPathComponent is empty or nil")
        }
    }

    /**
        Called while track downloading with written/total bytes.

        **Warning:** Method is called from Ajax instance. Do not call directly!
    */
    func reportDownloadingProgress(bytesDownloaded: Int64, bytesTotal: Int64) {
        // println("call reportDownloadingProgress")

        downloadingProgress = Float(bytesDownloaded) / Float(bytesTotal)
        // println(String(format: "%f", downloadingProgress!))
    }

    /**
        Will cancel track downloading,
        set downloading progress to nil,
        set doanloading status to false.

        Usage:

            record.cancelDownloading()
    */
    func cancelDownloading() {
        isDownloading = false
        println("set downloadingProgress nil!!!!!!!!!!!!!! record title: \(title)")
        downloadingProgress = nil

        if let downloadTask = downloadTask {
            downloadTask.cancel()
            self.downloadTask = nil
        }
    }
}