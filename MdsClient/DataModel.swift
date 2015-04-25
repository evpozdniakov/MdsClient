import Foundation

class DataModel: NSObject {

    var allRecords = [Record]()
    var filteredRecords: [Record]?
    var playingRecord: Record?
    // #FIXME: replace by get { find index by record}
    var playingRecordIndex: Int? {
        if let records = self.filteredRecords,
            playingRecord = self.playingRecord {

            return find(records, playingRecord)
        }

        return nil
    }

    // will filter records with search string and put them into filteredRecords array
    func filterRecordsWhichContainText(searchString: String) {
        let searchStringLowercase = searchString.lowercaseString

        filteredRecords = [Record]()
        for record in allRecords {
            if record.title.lowercaseString.rangeOfString(searchStringLowercase) != nil ||
                record.author.lowercaseString.rangeOfString(searchStringLowercase) != nil {
                    filteredRecords!.append(record)
            }
        }
    }

    // #MARK: - json

    // ASYNC
    // downloads all records json data
    // when done, fills dataModel.records with data
    func downloadAllRecordsJson() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let urlString = "http://core.mds-club.ru/api/v1.0/mds/records/?access-token=" + Access.generateToken()

            Ajax.getJsonByUrlString(urlString) { data in
                if let json = Ajax.parseJsonArray(data) {
                    self.fillRecordsWithJson(json)
                }
                else {
                    // #FIXME: no json returned
                }
            }
        }
    }

    // will parse json data and fill allRecords
    func fillRecordsWithJson(json: [AnyObject]) {
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

        // #FIXME: send success notification
        storeRecords()
    }

    // #MARK: - work with DataModel.plist

    // will store records in local file DataModel.plist under key "AllRecords"
    func storeRecords() {
        assert(allRecords.count > 0)

        if let filePath = getDataFilePath() {
            let data = NSMutableData()
            let archiver = NSKeyedArchiver(forWritingWithMutableData: data)
            archiver.encodeObject(allRecords, forKey: "AllRecords")
            archiver.finishEncoding()
            let dataWrittenSuccessfully = data.writeToFile(filePath, atomically: true)
            if !dataWrittenSuccessfully {
                // #FIXME: file wasn't saved for some reason
            }
        }
        else {
            // #FIXME: getDataFilePath() didn't return path to file
        }
    }

    // will load records either from local file DataModel.plist or will initialize
    func loadRecords() {
        if let filePath = getDataFilePath() {
            if NSFileManager.defaultManager().fileExistsAtPath(filePath) {
                if let data = NSData(contentsOfFile: filePath) {
                    let unarchiver = NSKeyedUnarchiver(forReadingWithData: data)
                    if let allRecords = unarchiver.decodeObjectForKey("AllRecords") as? [Record] {
                        self.allRecords = allRecords
                    }
                    else {
                        // #FIXME: impossible to convert unarchived data to [Record]
                    }
                    unarchiver.finishDecoding()
                    // #FIXME: send success notification
                }
                else {
                    // #FIXME:
                }
            }
            else {
                downloadAllRecordsJson()
            }
        }
        else {
            // #FIXME: getDataFilePath() didn't return path to file
        }
    }
    // #MARK: - helpers

    // returns path to local file DataModel.plist
    func getDataFilePath() -> String? {
        if let documentsDir = documementsDirectory() {
            let filePath = documentsDir.stringByAppendingPathComponent("DataModel.plist")
            println("filePath:\(filePath)")

            return filePath
        }
        else {
            // #FIXME: documementsDirectory() didn't return path to directory
        }

        return nil
    }

    // returns path to documents directory as String
    func documementsDirectory() -> String? {
        if let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as? [String] {
            return paths[0]
        }
        else {
            // #FIXME: NSSearchPathForDirectoriesInDomains() didn't return paths arrray
        }

        return nil
    }

}