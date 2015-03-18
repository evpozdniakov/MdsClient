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

        searchBar.resignFirstResponder()

        lastSearchQuery = searchBar.text
        let searchString: NSString = lastSearchQuery
        let firstCharacter = searchString.substringToIndex(1)
        let number = firstCharacter.toInt()

        searchResults = [Record]()
        if number > 0 {
            for var i = 0; i < number; i++ {
                let record = Record(author: "Кир Булычев", title: "Название произведения несколько слов \(i)")
                searchResults.append(record)
            }
        }
        
        tableView.reloadData()
        
        println("search results are: \(searchResults)")
    }
}

