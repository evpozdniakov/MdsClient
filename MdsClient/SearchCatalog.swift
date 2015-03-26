//
//  ViewController.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-03-15.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import UIKit

class SearchCatalog: UIViewController {
    
    struct CellId {
        static let searchResult = "SearchResult"
        static let nothingFound = "NothingFound"
    }
    
    // #MARK: - IB outlets

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    // #MARK: - ivars
    
    var searchResults = [Record]()
    var lastSearchQuery = ""
    var searchQueryHasNoResults: Bool {
        return !lastSearchQuery.isEmpty && searchResults.isEmpty
    }
    
    
    // #MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        tableView.contentInset = UIEdgeInsets(top: 44, left: 0, bottom: 0, right: 0)
        searchBar.becomeFirstResponder()
    }

    /*override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }*/

    // #MARK: - helpers

    func pareseJsonData(data: NSData) -> [AnyObject]? {
        var error: NSError?
        
        if let json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &error) as? [AnyObject] {
            return json
        }
        
        if let error = error {
            // #FIXME: error case
            println("error: \(error)")
            return nil
        }

        // #FIXME: error case
        println("some error: may be unexpected json structure")

        return nil
    }

    func getCatalogSearchUrlWithText(text: String) -> NSURL? {
        let escapedText = text.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let urlString = String(format: "http://bumagi.net/api/mds-catalog.php?q=%@", escapedText)        
        let url = NSURL(string: urlString)

        return url
    }

    func getCatalogSearchDataTaskWithUrl(url: NSURL) -> NSURLSessionDataTask {
        let session = NSURLSession.sharedSession()
        let dataTask = session.dataTaskWithURL(url, completionHandler: {data, response, error in
            if let error = error {
                // #FIXME: error case
                println("error in dataTask: \(error)")
                return
            }

            let httpResponse = response as NSHTTPURLResponse?

            if httpResponse == nil || httpResponse!.statusCode != 200 {
                // #FIXME: error case
                println("unexpected server response")
                return
            }

            // #FIXME: dont we need weak here?
            if let json = self.pareseJsonData(data) {
                self.applyDataFromJson(json)
            }

            dispatch_async(dispatch_get_main_queue()) {
                self.tableView.reloadData()
            }
        })

        return dataTask
    }

    func applyDataFromJson(json: [AnyObject]) {
        searchResults = [Record]()

        for entry in json {
            if let entry = entry as? [String: AnyObject] {
                println("entry is \(entry)")

                let title = entry["title"] as String?
                let author = entry["author"] as String?
                // let size = entry["size"] as String?

                if title != nil && author != nil {
                    searchResults.append(Record(author: author!, title: title!))
                }
            }
        }
    }
}

// #MARK: - UITableViewDataSource

extension SearchCatalog: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchQueryHasNoResults ? 1 : searchResults.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellId = searchQueryHasNoResults ? CellId.nothingFound : CellId.searchResult
        var cell = tableView.dequeueReusableCellWithIdentifier(cellId) as UITableViewCell!
        
        if cell == nil {
            cell = UITableViewCell(style: .Subtitle, reuseIdentifier: cellId)
        }
        
        if searchQueryHasNoResults {
            cell.textLabel!.text = "nothing found"
        }
        else {
            let record = searchResults[indexPath.row]

            cell.textLabel!.text = record.title
            cell.detailTextLabel!.text = record.author
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

        lastSearchQuery = searchBar.text

        let dataTask = getCatalogSearchDataTaskWithUrl(url!)

        dataTask.resume()
    }
}

