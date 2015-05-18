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
        // case DocumentDirsIsEmpty = 7
        case TrackUrlHasNoExtension = 8
        case NoTracksFoundInJson = 9
        case PlayableTrackNotFound = 10
    }

    var id: Int
    var author: String
    var title: String
    var readDate: NSDate?
    var year: String
    var station: String
    var tracks: [Track]?
    var hasNoPlayableTrack: Bool
    var localFileName: String?

    // #TODO: think how to store those vars?
    var downloadingProgress: Float?
    var downloadTask: NSURLSessionDownloadTask?

    var isDownloading: Bool {
        return self.downloadingProgress != nil
    }
    var localURL: NSURL? {
        if let fileName = self.localFileName,
            documentDir = DataModel.documementsDirectory() {

            let localURL = documentDir.URLByAppendingPathComponent(fileName)

            // println("localFileName: \(localFileName)")
            // println("documentDir: \(documentDir)")
            // println("localURL: \(localURL)")

            return localURL
        }

        return nil
    }
    var isStoredLocally: Bool {
        if let localURL = self.localURL,
            path = localURL.path {
                return NSFileManager.defaultManager().fileExistsAtPath(path)
            }

        return false
    }

    var downloadTracksJsonRetryCounter = 0
    var downloadTracksJsonRetrySuccess: ([Track]->Void)?
    var downloadTracksJsonRetryFail: (NSError->Void)?

    var filteredRecordsIndex: Int? {
        return find(DataModel.filteredRecords, self)
    }

    var playlistIndex: Int? {
        return find(DataModel.playlist, self)
    }

    // #MARK: - initializers

    init(id: Int, author: String, title: String, readDate: NSDate?, year: String, station: String, tracks: [Track]?, hasNoPlayableTrack: Bool) {
        self.id = id
        self.author = author
        self.title = title
        self.readDate = readDate
        self.year = year
        self.station = station
        self.tracks = tracks
        self.hasNoPlayableTrack = hasNoPlayableTrack
    }

    /**
        We call this initializer from DataModel.fillRecordsWithJson().
        Method calls main initializer with two more properties: tracks & hasNoPlayableTrack.
    */
    convenience init(id: Int, author: String, title: String, readDate dateString: String, station: String) {
        var readDate: NSDate?
        var year = ""
        var tracks: [Track]?
        let hasNoPlayableTrack = false
        var localFileName: String?
        var localURL: NSURL?
        let dateFormatter = NSDateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxx" /*find out and place date format from http://userguide.icu-project.org/formatparse/datetime*/
        if let date = dateFormatter.dateFromString(dateString) {
            let calendar = NSCalendar.currentCalendar()
            let components = calendar.components(.CalendarUnitYear, fromDate: date)
            readDate = date
            year = String(components.year)
        }

        self.init(id: id, author: author, title: title, readDate: readDate, year: year, station: station, tracks: tracks, hasNoPlayableTrack: hasNoPlayableTrack)
    }

    required init(coder aDecoder: NSCoder) {
        id = aDecoder.decodeIntegerForKey("Id")
        author = aDecoder.decodeObjectForKey("Author") as! String
        title = aDecoder.decodeObjectForKey("Title") as! String
        readDate = aDecoder.decodeObjectForKey("ReadDate") as? NSDate
        year = aDecoder.decodeObjectForKey("Year") as! String
        station = aDecoder.decodeObjectForKey("Station") as! String
        tracks = aDecoder.decodeObjectForKey("Tracks") as? [Track]
        hasNoPlayableTrack = aDecoder.decodeBoolForKey("HasNoPlayableTrack")
        localFileName = aDecoder.decodeObjectForKey("LocalFileName") as? String

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
        aCoder.encodeBool(hasNoPlayableTrack, forKey: "HasNoPlayableTrack")
        aCoder.encodeObject(localFileName, forKey: "LocalFileName")
    }

    // #MARK: - work with tracks

    /**
        The goal is to return first playable record track. (Playable means one with http or https protocol.)
        If record doesn't have tracks information yet, will download then parse tracks json.
        Method either calls success with track, or fail with error.

        **Warning:** Might work asynchronously.

        Usage:

            getFirstPlayableTrack(
                success: { track in
                    //
                },
                fail: { error in
                    //
                })

        :param: success: Track->Void Completion handler.
        :param: fail: NSError->Void Failure handler.
    */
    internal func getFirstPlayableTrack(success successHandler: Track->Void,
                                        fail failureHandler: NSError->Void) {


        // println("call Playlist.getFirstPlayableTrack() ")
        if let tracks = tracks {
            // tracks has been downloaded earlier
            var error: NSError?

            if let track = getAnyTrackWithHttpProtocol(tracks, error: &error) {
                successHandler(track)
            }
            else if let error = error {
                failureHandler(error)
            }
            else {
                // must never happen
                assert(false)
            }
        }
        else {
            // will download record tracks first
            downloadAndParseTracksJson(
                success: { tracks in
                    self.tracks = tracks
                    self.getFirstPlayableTrack(success: successHandler, fail: failureHandler)
                },
                fail: { error in
                    self.hasNoPlayableTrack = true
                    failureHandler(error)
                })
        }
    }

    /**
        Loops through tracks array looking for the url type http or https.
        Returns first track found with needed scheme.
        Otherwise returns nil.

        **Warning:** Record tracks must be non empty array.

        Usage:

            let track = getAnyTrackWithHttpProtocol(tracks)

        :param: tracks [Track] Array of tracks to go through.
        :param: error NSErrorPointer

        :returns: Track?
    */
    private func getAnyTrackWithHttpProtocol(tracks: [Track],
                                            error errorPointer: NSErrorPointer) -> Track? {

        for track in tracks {
            let scheme = track.url.scheme

            if scheme == "http" || scheme == "https" {
                return track
            }
        }

        let error = NSError(domain: Record.errorDomain, code: ErrorCode.PlayableTrackNotFound.rawValue, userInfo: nil)
        appLogError(error, withMessage: "Playable track not found in tracks: [\(tracks)].")

        if errorPointer != nil {
            errorPointer.memory = error
        }
        else {
            // must never happen
            assert(false)
        }

        return nil
    }

    /**
        Given by JSON [AnyObject], function goes through entries, creates and returns tracks array.
        If there was no errors during parsing, will return the array even if it has no tracks.
        Otherwise return nil and assign last error happened to passed error pointer.

        **Warning:** Might return empty array.

        Usage:

            var error: NSError?
            if let tracks = Record.getTracksFromJson(json, error: &error) {
                // success
            }
            else if let error = error {
                // fail
            }
            else {
                // must never happen
            }

        :param: json: [AnyObject] JSON with record tracks.
        :param: error: NSErrorPointer Pointer to an error in case.

        :returns: [Track]?
    */
    private static func getTracksFromJson(json: [AnyObject], error errorPointer: NSErrorPointer) -> [Track]? {
        var tracks = [Track]()
        var error: NSError?

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
                        error = NSError(domain: Record.errorDomain, code: ErrorCode.CantCreateUrlFromString.rawValue, userInfo: nil)
                        appLogError(error!, withMessage: "Cant create track URL from string [\(urlString)]")
                    }
                }
                else {
                    error = NSError(domain: Record.errorDomain, code: ErrorCode.UnableToMakeTrackFromJson.rawValue, userInfo: nil)
                    appLogError(error!, withMessage: "Unable to make Track from json [\(entry)]")
                }
            }
            else {
                error = NSError(domain: Record.errorDomain, code: ErrorCode.UnableToParseJsonEntryAsDictionary.rawValue, userInfo: nil)
                appLogError(error!, withMessage: "Unable to parse JSON entry as dictionary [\(entry)]")
            }
        }

        if tracks.count == 0 {
            if let error = error {
                if errorPointer != nil {
                    errorPointer.memory = error
                    return nil
                }
                else {
                    // must never happen
                    assert(false)
                }
            }
        }

        return tracks
    }

    /**
        Will call mds-club API for record tracks json.
        If server response succeeded, will parse the json and pass it to getTracksFromJson().
        If tracks parsed without error, calls success handler, even if array is empty.
        Otherwise calls failure handler.

        If server didn't response or json parse failed, will call completion handler with error.

        **Warning:** Works in separate thread. Works asynchronously. Might return empty array.

        Usage:

            downloadAndParseTracksJson(
                success: { tracks in
                    // success
                },
                fail: { error in
                    // failure
                })

        :param: success: [Track]->Void Completion handler.
        :param: fail: NSError->Void Failure handler.
    */
    private func downloadAndParseTracksJson(success successHandler: [Track]->Void,
                                            fail failureHandler: NSError->Void) {

        // println("call downloadAndParseTracksJson")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            // println("dispatch async")
            let urlString = "http://core.mds-club.ru/api/v1.0/mds/records/\(self.id)/files/?access-token=" + Access.generateToken()

            Ajax.getJsonByUrlString(urlString,
                success: { data in
                    // println("clojure with data: \(data)")
                    var error: NSError?

                    if let json = Ajax.parseJsonArray(data, error: &error),
                        tracks = Record.getTracksFromJson(json, error: &error) {

                        if tracks.count == 0 {
                            Record.logError(.NoTracksFoundInJson, withMessage: "No tracks found in JSON: [\(json)].", callFailureHandler: nil)
                        }

                        successHandler(tracks)
                    }
                    else if let error = error {
                        if self.downloadTracksJsonRetryCounter < 3 {
                            self.downloadTracksJsonRetryCounter++

                            if self.downloadTracksJsonRetryCounter == 1 {
                                self.downloadTracksJsonRetrySuccess = successHandler
                                self.downloadTracksJsonRetryFail = failureHandler
                            }

                            appMainThread() {
                                // 1 second delay between requests
                                let i = NSTimeInterval(1.0)
                                // TODO: invalidate timer if app terminates
                                NSTimer.scheduledTimerWithTimeInterval(i, target: self, selector: Selector("downloadAndParseTracksJsonRetry"), userInfo: nil, repeats: false)
                            }
                        }
                        else {
                            self.downloadTracksJsonRetrySuccess = nil
                            self.downloadTracksJsonRetryFail = nil
                            failureHandler(error)
                        }
                    }
                    else {
                        // must never happen
                        assert(false)
                    }
                },
                fail: { error in
                    failureHandler(error)
                })
        }
    }

    /**
        Helper which calls downloadAndParseTracksJson().

        Usage:

            downloadAndParseTracksJsonRetry()
    */
    func downloadAndParseTracksJsonRetry() {
        if let successHandler = downloadTracksJsonRetrySuccess,
            failureHandler = downloadTracksJsonRetryFail {

            downloadAndParseTracksJson(success: successHandler, fail: failureHandler)
        }
    }

    /**
        Delete local copy, if exists.

        Usage:

            record.deleteLocalCopy()
    */
    func deleteLocalCopy() {
        if !isStoredLocally {
            return
        }

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
                                callFailureHandler failureHandler: (NSError->Void)? ) {

        let error = NSError(domain: errorDomain, code: code.rawValue, userInfo: nil)
        appLogError(error, withMessage: message, callFailureHandler: failureHandler)
    }
}

extension Record: RecordDownload {
    /**
        Gets first track and initiates track downloading.

        **Warning:** Works asynchronously.

        Usage:

            startDownloading()
    */
    func startDownloading() {
        getFirstPlayableTrack(
            success: { track in
                // println("track found for record: \(self.title)")
                // make sure the record is still in playlist
                if DataModel.playlistContainsRecord(self) {
                    // println("record in still in playlist, start download track: \(track.url)")
                    self.downloadTrack(track)
                }
                /* else {
                    // println("it looks like the record is not in playlist any more")
                } */
            },
            fail: { error in
                appDisplayError("Audio hasn't been found on server. The problem has been reported.", withHandler: nil)
            })
    }

    /**
        Initiates track downloading process. Creates localURL to store file locally.

        Usage:

            record.downloadTrack(track)

        :param: track: Track
    */
    func downloadTrack(track: Track) {
        // println("call downloadTrack, url: \(track.url)")
        if track.url.pathExtension == "" {
            Record.logError(.TrackUrlHasNoExtension, withMessage: "Track url [\(track.url)] has no extension.", callFailureHandler: nil)
            return
        }

        if let fileName = track.url.lastPathComponent {
            localFileName = fileName
            DataModel.store()

            if let localURL = localURL {
                println("localURL before create task: \(localURL)")
                downloadTask = Ajax.downloadFileFromUrl(track.url, saveTo: localURL,
                    reportingProgress: reportDownloadingProgress,
                    reportingCompletion: {
                        self.downloadTask = nil
                        self.downloadingProgress = nil
                    },
                    reportingFailure: { error in
                        // #TODO: display error message to the user, ask him for download restart
                        self.downloadingProgress = nil
                     })

                // println("downloadTask created: \(downloadTask)")
            }
            else {
                Record.logError(.LocalUrlIsNil, withMessage: "Local url is nil for some reason, record title: [\(title)]", callFailureHandler: nil)
            }
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
        // println("+++++++++call reportDownloadingProgress")

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