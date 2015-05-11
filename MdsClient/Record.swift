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

    static let errorDomain = "RecordClass"

    enum ErrorCode: Int {
        case CantCreateUrlFromString = 1
        case UnableToMakeTrackFromJson = 2
        case UnableToParseJsonEntryAsDictionary = 3
        case TrackUrlHasNoFileName = 4
        case CantRemoveLocallyStoredFile = 5
        case LocalUrlIsNil = 6
        case DocumentDirsIsEmpty = 7
        case TrackUrlHasNoExtension = 8
    }

    var id: Int
    var author: String
    var title: String
    var readDate: NSDate?
    var year: String
    var station: String
    var tracks: [Track]
    var hasNoTracks: Bool
    var localURL: NSURL?

    // #TODO: think how to store those vars?
    var downloadingProgress: Float?
    var downloadTask: NSURLSessionDownloadTask?

    var isDownloading: Bool {
        return self.downloadingProgress != nil
    }
    var isStoredLocally: Bool {
        if let localURL = self.localURL,
            path = localURL.path {
                return NSFileManager.defaultManager().fileExistsAtPath(path)
            }

        return false
    }

    var downloadTrackRetryCounter = 0

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

    /**
        We call this initializer from DataModel.fillRecordsWithJson().
        Method calls main initializer with two more properties: tracks & hasNoTracks.
    */
    convenience init(id: Int, author: String, title: String, readDate dateString: String, station: String) {
        var readDate: NSDate?
        var year = ""
        let tracks = [Track]()
        let hasNoTracks = false
        var localURL: NSURL?
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
        localURL = aDecoder.decodeObjectForKey("LocalURL") as! NSURL?

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
        aCoder.encodeObject(localURL, forKey: "LocalURL")
    }

    // #MARK: - work with tracks

    // if the record has tracks, returns first track with http protocol
    // otherwise initializes tracks json downloading/parsing

    /**
        The goal is to return first playable record track. (Playable means one with http or https protocol.)
        If record doesn't have tracks information yet, will download then parse tracks json.

        **Warning:** Might work asynchronously.

        Usage:

            var error: NSError?
            getFirstPlayableTrack(&error) { track in
                if let error = error {
                    // fail code
                }
                else {
                    // success code
                }
            }

        :param: completionHandler: (Track?, NSError?)->Void Completion handler.
    */
    internal func getFirstPlayableTrack(completionHandler: (Track?, NSError?)->Void) {
        println("call Playlist.getFirstPlayableTrack() ")
        if hasNoTracks {
            // println("has no track")
            completionHandler(nil, nil)
        }
        else if tracks.count > 0 {
            // println("tracks exist, no need to download")
            completionHandler(getAnyTrackWithHttpProtocol(), nil)
        }
        else {
            downloadAndParseTracksJson() { tracks, error in
                if let tracks = tracks {
                    if tracks.count == 0 {
                        self.hasNoTracks = true
                    }

                    getFirstPlayableTrack(completionHandler)
                }
                else if let error = error {
                    // println("call completionHandler with error: \(error)")
                    completionHandler(nil, error)
                    // I stopped here last time
                }
            }
        }
    }

    /**
        Loops through record tracks looking for the url type http or https.
        Returns first track found with needed scheme.
        Otherwise returns nil and calls reportBroken().

        **Warning:** Record tracks must be non empty array.

        Usage:

            let track = getAnyTrackWithHttpProtocol()

        :returns: Track?
    */
    private func getAnyTrackWithHttpProtocol() -> Track? {
        assert(tracks.count > 0)

        for track in tracks {
            let scheme = track.url.scheme

            if scheme == "http" || scheme == "https" {
                return track
            }
        }

        // println("call reportBroken 1")
        reportBroken()

        return nil
    }

    // will parse json and fill tracks
    /**
        Given by JSON [AnyObject], function goes through entries and creates record.tracks array.
        If function was unable to create single track, it reports broken record.

        Usage:

            fillTracksWithJson(json)

        :param: json: [AnyObject] JSON with record tracks.
    */
    private func fillTracksWithJson(json: [AnyObject]) {
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
                    bitrate = entry["bitrate"] as? String,
                    channels = entry["channels"] as? String,
                    mode = entry["mode"] as? String,
                    size = entry["size"] as? Int,
                    urlString = entry["url"] as? String {
                        if let url = NSURL(string:urlString) {
                            let track = Track(id: id, bitrate: bitrate, channels: channels, mode: mode, size: size, url: url)
                            tracks.append(track)
                        }
                        else {
                            Record.logError(.CantCreateUrlFromString, withMessage: "Cant create track URL from string [\(urlString)]", callFailureHandler: nil)
                        }
                }
                else {
                    Record.logError(.UnableToMakeTrackFromJson, withMessage: "Unable to make Track from json [\(entry)]", callFailureHandler: nil)
                }
            }
            else {
                Record.logError(.UnableToParseJsonEntryAsDictionary, withMessage: "Unable to parse JSON entry as dictionary [\(entry)]", callFailureHandler: nil)
            }
        }

        if tracks.count > 0 {
            self.tracks = tracks
        }
        else {
            reportBroken()
        }
    }

    /**
        Will call mds-club API for record tracks json.
        If server response succeeded, will parse the json and pass it to fillTracksWithJson().
        If server response failed, will retry to call itself (up to 3 times).

        If not succeeded after three retries, reports error.

        **Warning:** Works asynchronously.

        Usage:

            var error: NSError?
            downloadAndParseTracksJson(&error) { tracks in
                if let error = error {
                    // failure
                }
                else {
                    // success
                }
            }

        :param: completionHandler: ([Track]?, NSError?)->Void
    */
    private func downloadAndParseTracksJson(completionHandler: ([Track]?, NSError?)->Void) {
        // println("call downloadAndParseTracksJson")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            // println("dispatch async")
            let urlString = "http://core.mds-club.ru/api/v1.0/mds/records/\(self.id)/files/?access-token=" + Access.generateToken()

            Ajax.getJsonByUrlString(urlString,
                success: { data in
                    // println("clojure with data: \(data)")
                    var error: NSError?

                    if let json = Ajax.parseJsonArray(data, error: &error) {
                        // println("will call fillTracksWithJson")
                        self.fillTracksWithJson(json)
                    }
                    else if let error = error {
                        // println("call reportBroken 3")
                        self.reportBroken()
                    }

                    completionHandler(self.tracks, error)
                },
                fail: { error in
                    completionHandler(nil, error)
                })
        }
    }

    func deleteLocalCopy() {
        if let localURL = localURL,
            path = localURL.path {

            var error: NSError?

            NSFileManager.defaultManager().removeItemAtPath(path, error: &error)

            if let error = error {
                Record.logError(.CantRemoveLocallyStoredFile, withMessage: "Can't remove file storred locally: [\(localURL)]", callFailureHandler: nil)
            }
        }
        else {
            Record.logError(.LocalUrlIsNil, withMessage: "Local url is nil for some reason, record title: [\(title)]", callFailureHandler: nil)
        }
    }

    /**
        Will connect ios.bumagi.net to report broken record.

        Usage:

            reportBroken()
    */
    private func reportBroken() {
        hasNoTracks = true

        if let escapedTitle = title.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) {
            let urlString = "http://ios.bumagi.net/api/mds-broken-track.php?rid=\(id)&title=\(escapedTitle)"

            if let url = NSURL(string: urlString) {
                Ajax.get(url: url,
                    success: { data in
                        // println("broken record reported with url: \(url)")
                    },
                    fail: { error in
                        // error has been reported in Ajax.swift
                    })
            }
            else {
                Record.logError(.CantCreateUrlFromString, withMessage: "Cant create NSURL from string [\(urlString)]", callFailureHandler: nil)
            }
        }
    }

    // #MARK: helpers

    /**
        Will create error:NSError and call generic function logError()

        **Warning:** Static method.

        Usage:

            logError(.NoResponseFromServer, withMessage: "Server didn't return any response.", callFailureHandler: fail)

        :param: code: ErrorCode Error code.
        :param: message: String Error description.
        :param: failureHandler: ( NSError->Void )? Failutre handler.
    */
    private static func logError(code: ErrorCode,
                                withMessage message: String,
                                callFailureHandler fail: (NSError->Void)? ) {

        let error = NSError(domain: errorDomain, code: code.rawValue, userInfo: nil)
        appLogError(error, withMessage: message, callFailureHandler: fail)
    }
}

extension Record: RecordDownload {
    /**
        Gets first track and initiates track downloading.
        Marks record as hasNotTracks if no tracks found.

        **Warning:** Works asynchronously.

        Usage:

            startDownloading()
    */
    func startDownloading() {
        println("call Playlist.startDownloading() for record: \(title)")
        var error: NSError?

        getFirstPlayableTrack(&error) { track in
            if let error = error {
                if self.downloadTrackRetryCounter < 3 {
                    let i = NSTimeInterval(1)
                    NSTimer.scheduledTimerWithTimeInterval(i, target: self, selector: Selector("startDownloading"), userInfo: nil, repeats: false)
                    self.downloadTrackRetryCounter++
                    println("------- schedule retry \(self.downloadTrackRetryCounter)")
                }
                else {
                    println("---------- no tracks after 3 retries.")
                    self.hasNoTracks = true
                }
            }
            else if let track = track {
                // println("track found for record: \(self.title)")
                // make sure the record is still in playlist
                if DataModel.playlistContainsRecord(self) {
                    // println("record in still in playlist, start download track: \(track.url)")
                    self.downloadTrack(track)
                }
                /* else {
                    // println("it looks like the record is not in playlist any more")
                } */
            }
            else {
                // println("---has no tracks for record: \(self.title)---")
                self.hasNoTracks = true
                // #TODO: the problem, Record.swift is not a controller, so it can't use appDisplayError, cause it requires inViewController.
                // #TODO: another problem - how to reload table cell?
                // appDisplayError("Аудио-файл не найден на сервере.", inViewController: self) {
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
        // println("call downloadTrack, url: \(track.url)")
        let fileManager = NSFileManager.defaultManager()
        let documentDirs = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)

        if documentDirs.count == 0 {
            Record.logError(.DocumentDirsIsEmpty, withMessage: "File manager returned empty document directory array.", callFailureHandler: nil)
            return
        }

        let documentDir = documentDirs[0] as! NSURL

        if track.url.pathExtension == "" {
            Record.logError(.TrackUrlHasNoExtension, withMessage: "Track url [\(track.url)] has no extension.", callFailureHandler: nil)
            return
        }

        if let fileName = track.url.lastPathComponent {
            localURL = documentDir.URLByAppendingPathComponent(fileName)

            downloadTask = Ajax.downloadFileFromUrl(track.url, saveTo: localURL!,
                reportingProgress: reportDownloadingProgress,
                reportingCompletion: {
                    // println("file dowloaded and may be saved")
                    // #FIXME: check if file has been saved to localURL
                    self.downloadTask = nil
                    self.downloadingProgress = nil
                },
                reportingFailure: { error in
                    // #FIXME: retry up to 3 times.
                    self.downloadingProgress = nil
                 })

            // println("downloadTask created: \(downloadTask)")
        }
        else {
            Record.logError(.TrackUrlHasNoFileName, withMessage: "Track url [\(track.url)] has no file name.", callFailureHandler: nil)
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
        // println("set downloadingProgress nil!!!!!!!!!!!!!! record title: \(title)")

        downloadTask?.cancel()
        downloadTask = nil
    }
}