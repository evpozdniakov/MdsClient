import Foundation

class DataModel: NSObject {
    var records = [Record]()

    func fillRecordsWithJsonData(data: NSData) {
        if let json = parseJsonData(data) {
            records = [Record]()

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
                }
            }

            println("============= records created from json")
            // #FIXME: send success notification
            storeRecords()
        }
    }

    func parseJsonData(data: NSData) -> [AnyObject]? {
        var error: NSError?
        
        if let json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &error) as? [AnyObject] {
            return json
        }
        
        if let error = error {
            // Cocoa error 3840: JSON text did not start with array or object and option to allow fragments not set
            println("data-model-error-1001: \(error)")
        }
        else {
            // Error: JSON could be parsed, but it can be casted to [AnyObject] format
            // println("some error: may be unexpected json structure")
            println("data-model-error-1002")
        }

        return nil
    }

    // will store records in local file DataModel.plist under key "AllRecords"
    func storeRecords() {
        if let filePath = getDataFilePath() {
            assert(records.count > 0)
            let data = NSMutableData()
            let archiver = NSKeyedArchiver(forWritingWithMutableData: data)
            archiver.encodeObject(records, forKey: "AllRecords")
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
                    if let records = unarchiver.decodeObjectForKey("AllRecords") as? [Record] {
                        self.records = records
                    }
                    else {
                        // #FIXME: impossible to convert unarchived data to [Record]
                    }
                    unarchiver.finishDecoding()
                    println("---------- data read successfully")
                    // #FIXME: send success notification
                }
                else {
                    // #FIXME:
                }
            }
            else {
                getRecordsJson()
            }
        }
        else {
            // #FIXME: getDataFilePath() didn't return path to file
        }
    }

    // returns path to local file DataModel.plist
    func getDataFilePath() -> String? {
        if let documentsDir = documementsDirectory() {
            let filePath = documentsDir.stringByAppendingPathComponent("DataModel.plist")
            
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
            println("paths: \(paths)")
            println("paths[0]: \(paths[0])")
            return paths[0]
        }
        else {
            // #FIXME: NSSearchPathForDirectoriesInDomains() didn't return paths arrray
        }
        
        return nil
    }

    // initialize retreiving remote records json
    func getRecordsJson() {
        println("------------ data json will load")
        let token = Access.generateToken()
        let urlString = "http://core.mds-club.ru/api/v1.0/mds/records/?access-token=" + token
        let url = NSURL(string: urlString)

        if let url = url {
            Ajax.get(url: url) { data in
                self.fillRecordsWithJsonData(data)
            }
        }
    }
}