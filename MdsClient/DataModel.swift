import Foundation

class DataModel: NSObject {

    enum ErrorCode: Int {
        case CantConvertUnarchivedData = 1
        case CantReadFileContents = 2
        case NSSearchPathFailed = 3
        case PlistWasntSaved = 4
        case UnableToParseJsonEntryAsDictionary = 5
        case UnableToMakeRefordFromJson = 6
        case DocumentDirsIsEmpty = 7
    }

    static let errorDomain = "DataModelClass"

    /// all catalog records
    static var allRecords = [Record]()

    /// records filtered by user
    static var filteredRecords = [Record]()

    /// records selected by user
    static var playlist = [Record]()

    /// playlist record ids
    static var playlistRecordIds = [Int]()

    /// currently playing record
    static var playingRecord: Record?

    /// instance of RemoteMp3Player
    static var player: RemoteMp3Player?

    /**
        Will filter records with search string and put them into filteredRecords array.

        Usage:

            DataModel.filterRecordsWhichContainText(query)

        :param: searchString: String
    */
    internal static func filterRecordsWhichContainText(searchString: String) {
        let searchStringLowercase = searchString.lowercaseString

        filteredRecords = [Record]()
        for record in allRecords {
            if searchString == "" ||
                record.title.lowercaseString.rangeOfString(searchStringLowercase) != nil ||
                record.author.lowercaseString.rangeOfString(searchStringLowercase) != nil {

                filteredRecords.append(record)
            }
        }
    }

    // #MARK: - json

    /**
        Given by JSON [AnyObject], function goes through entries, creates and returns records array.
        If there was no errors during parsing, will return the array even if it has no tracks.
        Otherwise return nil and assign last error happened to passed error pointer.

        **Warning:** Might return empty array.

        Usage:

            var error: NSError?
            if let records = DataModel.getRecordsFromJson(json, error: &error) {
                // success
            }
            else if let error = error {
                // fail
            }
            else {
                // must never happen
            }

        :param: json: [AnyObject] JSON with records.
        :param: error: NSErrorPointer Pointer to an error in case.

        :returns: [Record]?
    */
    private static func getRecordsFromJson(json: [AnyObject], error errorPointer: NSErrorPointer) -> [Record]? {
        var records = [Record]()
        var error: NSError?

        for entry in json {
            if let entry = entry as? [String: AnyObject] {

                // \"id\": 3,
                // \"createAt\": \"2005-08-02T22:33:15+04:00\",
                // \"editAt\": \"2006-09-09T16:36:59+04:00\",
                // \"author\": \"Борис Виан\",
                // \"name\": \"Пена дней (1-29/33-39 главы)\",
                // \"readedAt\": \"0001-01-01T00:00:00+02:30\",
                // \"radioStation\": \"\",
                // \"following\": 0

                if let id = entry["id"] as? Int,
                    let author = entry["author"] as? String,
                    let title = entry["name"] as? String,
                    let readDate = entry["readedAt"] as? String,
                    let station = entry["radioStation"] as? String {
                    let record = Record(id: id, author: author, title: title, readDate: readDate, station: station)
                    records.append(record)
                }
                else {
                    error = NSError(domain: Record.errorDomain, code: ErrorCode.UnableToMakeRefordFromJson.rawValue, userInfo: nil)
                    appLogError(error!, withMessage: "Unable to make Record from json [\(entry)]")
                }
            }
            else {
                error = NSError(domain: Record.errorDomain, code: ErrorCode.UnableToParseJsonEntryAsDictionary.rawValue, userInfo: nil)
                appLogError(error!, withMessage: "Unable to parse JSON entry as dictionary [\(entry)]")
            }
        }

        if records.count == 0 {
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

        return records
    }

    // #MARK: - work with DataModel.plist

    /**
        Will store DataModel state in local file DataModel.plist.
        - records under key "AllRecords"
        - playlistRecordIds under key "PlaylistRecordIds"

        Usage:

            DataModel.store()
    */
    internal static func store() {
        if allRecords.count > 0 {
            if let fileURL = DataModel.getDataFileURL() {
                appNewThread() {
                    let data = NSMutableData()
                    let archiver = NSKeyedArchiver(forWritingWithMutableData: data)
                    archiver.encodeObject(self.allRecords, forKey: "AllRecords")
                    archiver.encodeObject(self.playlistRecordIds, forKey: "PlaylistRecordIds")
                    archiver.finishEncoding()
                    let dataWrittenSuccessfully = data.writeToURL(fileURL, atomically: true)
                    if !dataWrittenSuccessfully {
                        DataModel.logError(.PlistWasntSaved, withMessage: "DataModel.plist was not saved. Probably there is no enough space.", callFailureHandler: nil)
                    }
                }
            }
        }
    }

    /**
        Downloads catalog records from server.
        If done without errors, fills dataModel.records with data and calls success handler.
        Calls failure handler otherwise.

        **Warning:** Run in (call handlers from) separate thread.

        Usage:

            DataModel.downloadCatalog(
                success: {
                    // success code
                },
                fail: { error in
                    // fail code
                })

        :param: success: Void->Void Success handler.
        :param: fail: NSError->Void Failure handler.
    */
    internal static func downloadCatalog(success successHandler: Void->Void,
                                        fail failureHandler: NSError->Void) {

        appNewThread() {
            let urlString = "http://core.mds-club.ru/api/v1.0/mds/records/?access-token=" + Access.generateToken()

            Ajax.getJsonByUrlString(urlString,
                success: { data in
                    var error: NSError?

                    if let json = Ajax.parseJsonArray(data, error: &error),
                        records = DataModel.getRecordsFromJson(json, error: &error) {
                        DataModel.allRecords = records
                        DataModel.store()
                        successHandler()
                    }
                    else if let error = error {
                        failureHandler(error)
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
        Loads data from DataModel.plist, if exists:
        - allRecords
        - playlistRecordIds
        Creates playlist using playlistRecordIds, starts downloading records in playlist if they are not stored locally.

        Usage:

            DataModel.restore()
    */
    internal static func restore() {
        if let fileURL = DataModel.getDataFileURL(),
            path = fileURL.path {

            if NSFileManager.defaultManager().fileExistsAtPath(path) {
                if let data = NSData(contentsOfURL: fileURL) {
                    let unarchiver = NSKeyedUnarchiver(forReadingWithData: data)

                    if let allRecords = unarchiver.decodeObjectForKey("AllRecords") as? [Record],
                        playlistRecordIds = unarchiver.decodeObjectForKey("PlaylistRecordIds") as? [Int] {

                        self.allRecords = allRecords
                        self.playlistRecordIds = playlistRecordIds
                        for record in self.allRecords {
                            if let index = find(self.playlistRecordIds, record.id) {
                                self.playlist.append(record)
                                if !record.isStoredLocally {
                                    record.startDownloading()
                                }
                            }
                        }
                    }
                    else {
                        DataModel.logError(.CantConvertUnarchivedData, withMessage: "Cant convert unarchived data to [Record].", callFailureHandler: nil)
                    }

                    unarchiver.finishDecoding()
                }
                else {
                    // cant read file contents
                    DataModel.logError(.CantReadFileContents, withMessage: "Cant read file contents.", callFailureHandler: nil)
                }
            }
        }
    }

    // #MARK: - playlist

    /**
        Returns true if record sent as parameter is in playlist. False otherwise.

        Usage:

            DataModel.playlistContainsRecord(record)

        :param: Record

        :returns: Bool
    */
    internal static func playlistContainsRecord(record: Record) -> Bool {
        if let index = find(playlist, record) {
            return true
        }

        return false
    }

    /**
        Removes passed record from playlist array, asks record to cancel downloading, removes local file if exists.
        Removes record.id from playlistRecordIds then stores data model.

        Usage:

            DataModel.playlistRemoveRecord(record)

        :param: Record
    */
    internal static func playlistRemoveRecord(record: Record) {
        if let recordIdIndex = find(playlistRecordIds, record.id),
            recordPlaylistIndex = record.playlistIndex {

            // if record is playing right now, stop it
            if playingRecord == record {
                player?.stop()
            }

            playlist.removeAtIndex(recordPlaylistIndex)
            playlistRecordIds.removeAtIndex(recordIdIndex)
            record.cancelDownloading()
            record.deleteLocalCopy()
            DataModel.store()
        }
        else {
            // must never happen
            assert(false)
        }
    }

    /**
        Adds passed record to playlist array then asks record to start downloading.
        Also adds record id in playlistRecordIds, then stores data model.

        **Warning:** If you want to change the function, you might want to change restore function, because it creates playlist from playlistRecordIds.

        Usage:

            DataModel.playlistAddRecord(record)

        :param: Record
    */
    internal static func playlistAddRecord(record: Record) {
        let recordId = record.id

        assert(find(playlistRecordIds, recordId) == nil)
        assert(find(playlist, record) == nil)

        playlist.append(record)
        playlistRecordIds.append(recordId)
        DataModel.store()

        if !record.isStoredLocally {
            record.startDownloading()
        }
    }

    // #MARK: - player

    /**
        Returns instance of RemoteMp3Player. If it is not determined yet.

        Usage:

            DataModel.getPlayer()

        :returns: RemoteMp3Player
    */
    internal static func getPlayer() -> RemoteMp3Player? {
        if player == nil {
            player = RemoteMp3Player()
        }

        return player
    }

    // #MARK: - helpers

    /**
        Rreturns URL to local file DataModel.plist.

        Usage:

            DataModel.getDataFileURL()

        :returns: String?
    */
    private static func getDataFileURL() -> NSURL? {
        if let documentsDir = DataModel.documementsDirectory() {
            let fileURL = documentsDir.URLByAppendingPathComponent("DataModel.plist")
            println("fileURL:\(fileURL)")
            return fileURL
        }

        return nil
    }

    /**
        Rreturns URL to documents directory.

        Usage:

            DataModel.documementsDirectory()

        :returns: String?
    */
    internal static func documementsDirectory() -> NSURL? {
        let fileManager = NSFileManager.defaultManager()
        let documentDirs = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)

        if documentDirs.count == 0 {
            DataModel.logError(.DocumentDirsIsEmpty, withMessage: "File manager returned empty document directory array.", callFailureHandler: nil)
            return nil
        }

        let documentDir = documentDirs[0] as! NSURL

        return documentDir
    }

    /**
        Will create error:NSError and call generic function logError()

        **Warning:** Static method.

        Usage:

            DataModel.logError(.NoResponseFromServer, withMessage: "Server didn't return any response.", callFailureHandler: fail)

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