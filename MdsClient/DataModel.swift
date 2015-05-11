import Foundation

class DataModel: NSObject {

    enum ErrorMessage: String {
        case UnableParseCatalogJson = "Произошла ошибка при загрузке каталога."
        case UnableGetCatalogJsonFromServer = "Сервер недоступен."
    }

    enum ErrorCode: Int {
        case CantConvertUnarchivedData = 1
        case CantReadFileContents = 2
        case NSSearchPathFailed = 3
        case PlistWasntSaved = 4
    }

    static let errorDomain = "DataModelClass"

    static var allRecords = [Record]()
    static var filteredRecords = [Record]()
    static var playlist = [Record]()
    static var playingRecord: Record?

    static var playingRecordIndex: Int? {
        if let playingRecord = self.playingRecord {

            return find(filteredRecords, playingRecord)
        }

        return nil
    }

    /**
        Will filter records with search string and put them into filteredRecords array.

        Usage:

            filterRecordsWhichContainText(query)

        :param: searchString: String
    */
    static func filterRecordsWhichContainText(searchString: String) {
        let searchStringLowercase = searchString.lowercaseString

        filteredRecords = [Record]()
        for record in allRecords {
            if record.title.lowercaseString.rangeOfString(searchStringLowercase) != nil ||
                record.author.lowercaseString.rangeOfString(searchStringLowercase) != nil {
                    filteredRecords.append(record)
            }
        }
    }

    // #MARK: - json

    /**
        Downloads all records json data from server.
        When done, fills dataModel.records with data.

        **Warning:** Works asynchronously.

        Usage:

            downloadAllRecordsJson() { errorMessage in
                // report error
            }

        :param: reportError: String->Void
    */
    static func downloadAllRecordsJson(reportError: String->Void) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let urlString = "http://core.mds-club.ru/api/v1.0/mds/records/?access-token=" + Access.generateToken()

            Ajax.getJsonByUrlString(urlString,
                success: { data in
                    var error: NSError?

                    if let json = Ajax.parseJsonArray(data, error: &error) {
                        self.fillRecordsWithJson(json)
                        // #TODO: send global notification to enable UI
                        return
                    }

                    assert(error != nil)

                    if let error = error {
                        reportError(ErrorMessage.UnableParseCatalogJson.rawValue)
                    }
                },
                fail: { error in
                    reportError(ErrorMessage.UnableParseCatalogJson.rawValue)
                })
        }
    }

    /**
        Will parse json data, fill allRecords, then call storeRecords().

        Usage:

            fillRecordsWithJson(json)

        :param: json: [AnyObject]
    */
    static func fillRecordsWithJson(json: [AnyObject]) {
        allRecords = [Record]()

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
                    allRecords.append(record)
                }
            }
        }

        storeRecords()
    }

    // #MARK: - work with DataModel.plist

    /**
        Will store records in local file DataModel.plist under key "AllRecords".

        Usage:

            storeRecords()
    */
    static func storeRecords() {
        assert(allRecords.count > 0)

        if let filePath = getDataFilePath() {
            let data = NSMutableData()
            let archiver = NSKeyedArchiver(forWritingWithMutableData: data)
            archiver.encodeObject(allRecords, forKey: "AllRecords")
            archiver.finishEncoding()
            let dataWrittenSuccessfully = data.writeToFile(filePath, atomically: true)
            if !dataWrittenSuccessfully {
                throwError(.PlistWasntSaved, withMessage: "DataModel.plist was not saved. Probably there is no enough space.", callFailureHandler: nil)
            }
        }
    }

    /**
        Will load records either from local file DataModel.plist or download/parse/apply records json.

        **Warning:** Need to be ran asynchronously.

        Usage:

            loadRecords() { errorMessage in
                // report error
            }

        :param: reportError: String->Void
    */
    static func loadRecords(reportError: String->Void) {
        if let filePath = getDataFilePath() {
            if NSFileManager.defaultManager().fileExistsAtPath(filePath) {
                if let data = NSData(contentsOfFile: filePath) {
                    let unarchiver = NSKeyedUnarchiver(forReadingWithData: data)

                    if let allRecords = unarchiver.decodeObjectForKey("AllRecords") as? [Record] {
                        self.allRecords = allRecords
                    }
                    else {
                        throwError(.CantConvertUnarchivedData, withMessage: "Cant convert unarchived data to [Record].", callFailureHandler: nil)
                    }

                    unarchiver.finishDecoding()
                }
                else {
                    // cant read file contents
                    throwError(.CantReadFileContents, withMessage: "Cant read file contents.", callFailureHandler: nil)
                }
            }
        }

        if allRecords.count > 0 {
            // #TODO: send global notification to enable UI
        }
        else {
            downloadAllRecordsJson(reportError)
        }
    }

    // #MARK: - playlist

    /**
        Returns true if record sent as parameter is in playlist. False otherwise.

        Usage:

            playlistContainsRecord(record)

        :param: Record

        :returns: Bool
    */
    static func playlistContainsRecord(record: Record) -> Bool {
        if let index = find(playlist, record) {
            return true
        }

        return false
    }

    /**
        Removes passed record from playlist array, asks record to cancel downloading.
        Also removes local file if exists.

        Usage:

            playlistRemoveRecord(record)

        :param: Record
    */
    static func playlistRemoveRecord(record: Record) {
        if let index = find(playlist, record) {
            playlist.removeAtIndex(index)
            record.cancelDownloading()
            record.deleteLocalCopy()
        }
        /* else {
            // it should never happen, but what if it does?
        } */
    }

    /**
        Adds passed record to playlist array then asks record to start downloading.

        Usage:

            playlistAddRecord(record)

        :param: Record
    */
    static func playlistAddRecord(record: Record) {
        playlist.append(record)
        record.startDownloading()
    }

    // #MARK: - helpers

    /**
        Rreturns path to local file DataModel.plist.

        Usage:

            getDataFilePath()

        :returns: String?
    */
    static func getDataFilePath() -> String? {
        if let documentsDir = documementsDirectory() {
            let filePath = documentsDir.stringByAppendingPathComponent("DataModel.plist")
            // println("filePath:\(filePath)")
            return filePath
        }

        return nil
    }

    /**
        Rreturns path to documents directory.

        Usage:

            documementsDirectory()

        :returns: String?
    */
    static func documementsDirectory() -> String? {
        if let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as? [String] {
            return paths[0]
        }
        else {
            throwError(.NSSearchPathFailed, withMessage: "NSSearchPathForDirectoriesInDomains failed.", callFailureHandler: nil)
        }

        return nil
    }

    /**
        Will create error:NSError and call generic function logError()

        **Warning:** Static method.

        Usage:

            throwError(.NoResponseFromServer, withMessage: "Server didn't return any response.", callFailureHandler: fail)

        :param: code: ErrorCode Error code.
        :param: message: String Error description.
        :param: failureHandler: ( NSError->Void )? Failutre handler.
    */
    static func throwError(code: ErrorCode,
                            withMessage message: String,
                            callFailureHandler failureHandler: ( NSError->Void )? ) {

        let error = NSError(domain: errorDomain, code: code.rawValue, userInfo: nil)

        throwError(error, withMessage: message, callFailureHandler: failureHandler)
    }

    /**
        Will create error:NSError and call generic function logError()

        **Warning:** Static method.

        Usage:

            throwError(error, withMessage: "Server didn't return any response.") { error in
                // failure code
            }

        :param: error: NSError The error.
        :param: message: String Error description.
        :param: failureHandler: ( NSError->Void )? Failure handler.
    */
    static func throwError(error: NSError,
                            withMessage message: String,
                            callFailureHandler failureHandler: ( NSError->Void )? ) {

        appLogError(error, withMessage: message)

        if let failureHandler = failureHandler {
            failureHandler(error)
        }
    }
}