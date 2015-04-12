//
//  ViewController.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-03-15.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import UIKit
import AVFoundation

class SearchCatalog: UIViewController {
    
    struct CellId {
        static let searchInProgressCell = "SearchInProgressCell"
        static let recordCell = "RecordCell"
        static let nothingFound = "NothingFoundCell"
    }
    
    // #MARK: - IB outlets

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!

    // #MARK: - IB Actions

    @IBAction func playButtonClicked(sender: UIButton) {
        if let cellContent = sender.superview {
            if let cell = cellContent.superview as? UITableViewCell {
                println("cell found")
                if let indexPath = tableView.indexPathForCell(cell) {
                    /* let record = searchResults[indexPath.row]
                    println("record: \(record)")

                    if record.sources == nil || record.sources!.isEmpty {
                        throwErrorMessage("Отсутствуют ссылки на загрузку файла.", withHandler: nil, inViewController: self)
                        return
                    }

                    let url = record.sources![1].url
                    println("lets play \(url)")

                    var error: NSError?
                    var audioPlayer:AVAudioPlayer?
                    audioPlayer = AVAudioPlayer(contentsOfURL: url,
                        fileTypeHint: AVFileTypeMPEGLayer3,
                        error: &error)

                    if let error = error {
                        println("error: \(error)")
                        return
                    }

                    sender.enabled = false
                    audioPlayer!.prepareToPlay()
                    audioPlayer!.play() */
                }
            }
        }
    }
    
    // #MARK: - ivars
    
    var dataModel: DataModel?
    var isLoading = false
    var dataTask: NSURLSessionDataTask?
    var lastSearchQuery = ""
    var searchQueryHasNoResults: Bool {
        if isLoading {
            return false
        }

        if lastSearchQuery.isEmpty {
            return false
        }

        if !searchResults.isEmpty {
            return false
        }

        return true
    }
    var searchResults = [Record]()
    
    
    // #MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        assert(dataModel != nil)

        tableView.contentInset = UIEdgeInsets(top: 44, left: 0, bottom: 0, right: 0)
        searchBar.becomeFirstResponder()

        // ask dataModel to load records
        dataModel!.loadRecords()
    }

    /*override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }*/

    // #MARK: - helpers

    func getCatalogSearchUrlWithText(text: String) -> NSURL? {
        let escapedText = text.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let urlString = String(format: "http://bumagi.net/api/mds-catalog.php?q=%@", escapedText)        
        let url = NSURL(string: urlString)

        return url
    }

    /* func getCatalogSearchDataTaskWithUrl(url: NSURL) -> NSURLSessionDataTask {
        let session = NSURLSession.sharedSession()
        let dataTask = session.dataTaskWithURL(url, completionHandler: {data, response, error in
            func reloadTableInMainThread() {
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
            }

            self.isLoading = false

            if let error = error {
                if error.code == -999 { return } // task cancelled

                // The operation couldn’t be completed. (kCFErrorDomainCFNetwork error -1003.)
                // It happens when URL is unreachable
                println("error-1001: \(error)")
                throwErrorMessage("Сервер не найден. Возможно это связано с конфигурацией вашей сети. Попробуйте повторить запрос позже.",
                    withHandler: reloadTableInMainThread,
                    inViewController: self)
                return
            }

            let httpResponse = response as? NSHTTPURLResponse

            if httpResponse == nil || httpResponse!.statusCode == 500 {
                // Server didn't return any response
                println("error-1002")
                throwErrorMessage("Сервер не отвечает. Возможно он перегружен. Попробуйте повторить запрос позже.",
                    withHandler: reloadTableInMainThread,
                    inViewController: self)
            }
            else if httpResponse!.statusCode != 200 {
                // erver response code != 200
                println("error-1003")
                throwErrorMessage("Сервер вернул код \(httpResponse!.statusCode). Попробуйте повторить запрос позже.",
                    withHandler: reloadTableInMainThread,
                    inViewController: self)
            }
            else if let json = self.parseJsonData(data) {
                self.applyDataFromJson(json)
            }

            reloadTableInMainThread()            
        })

        return dataTask
    } */
}

// #MARK: - UITableViewDataSource

extension SearchCatalog: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading {
            return 1
        }

        if searchQueryHasNoResults {
            return 1
        }

        return searchResults.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if isLoading {
            return getSearchInProgressCellForTableView(tableView)
        }

        if searchQueryHasNoResults {
            return getNothingFoundCellForTableView(tableView)
        }

        return getRecordCellForTableView(tableView, atIndexPath: indexPath)
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let height: CGFloat = searchQueryHasNoResults ? 44 : 88

        return height
    }

    func getSearchInProgressCellForTableView(tableView: UITableView) -> UITableViewCell {
        let cellId = CellId.searchInProgressCell
        let cell = tableView.dequeueReusableCellWithIdentifier(cellId) as! UITableViewCell
        
        if let textLbl = cell.viewWithTag(100) as? UILabel {
            textLbl.text = "Ищем «\(lastSearchQuery)»"
        }

        if let spinner = cell.viewWithTag(200) as? UIActivityIndicatorView {
            spinner.startAnimating()
        }
        
        return cell
    }

    func getNothingFoundCellForTableView(tableView: UITableView) -> UITableViewCell {
        let cellId = CellId.nothingFound
        var cell = tableView.dequeueReusableCellWithIdentifier(cellId) as? UITableViewCell
        
        if cell == nil {
            cell = UITableViewCell(style: .Default, reuseIdentifier: cellId)
        }
        
        cell!.textLabel!.text = "Ничего не найдено..."
        
        return cell!
    }

    func getRecordCellForTableView(tableView: UITableView, atIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellId = CellId.recordCell
        let cell = tableView.dequeueReusableCellWithIdentifier(cellId) as! UITableViewCell
        let record = searchResults[indexPath.row]

        if let authorLbl = cell.viewWithTag(100) as? UILabel {
            authorLbl.text = record.author
        }

        if let titleLbl = cell.viewWithTag(200) as? UILabel {
            titleLbl.text = record.title
        }

        return cell

    }
}

// #MARK: - UITableViewDelegate

extension SearchCatalog: UITableViewDelegate {
    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        return searchQueryHasNoResults ? nil : indexPath
    }
    
    /*func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let height: CGFloat = (searchQueryHasNoResults && indexPath.row == 0) ? 88 : 44

        return height
    }*/
}


// #MARK: - UISearchBarDelegate

extension SearchCatalog: UISearchBarDelegate {
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        println("search button clicked, search string: '\(searchBar.text)'")
        
        if searchBar.text.isEmpty {
            return
        }

        searchBar.resignFirstResponder()
        
        let url = getCatalogSearchUrlWithText(searchBar.text)

        if url == nil {
            println("getCatalogSearchUrlWithText hasn't return proper URL")
            return
        }

        dataTask?.cancel()

        lastSearchQuery = searchBar.text
        isLoading = true
        tableView.reloadData()

        // dataTask = getCatalogSearchDataTaskWithUrl(url!)
        dataTask?.resume()
    }
}

