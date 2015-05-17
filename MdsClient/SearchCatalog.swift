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
        static let recordCell = "RecordCell"
    }

    // #MARK: - ivars

    var lastSearchQuery = ""
    var searchResults = [Record]()

    // #MARK: - IB outlets

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!

    // #MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()


        // setTableViewMargings()
        searchBar.becomeFirstResponder()
        loadMdsRecordsOnce()
        toggleDisablePlaylistTab()
    }

    // #MARK: - redraw

    /**
        Set table view margins to avoid top space taken by search and bottom place taken by tabs.

        Usage:

            setTableViewMargings()
    */
    func setTableViewMargings() {
        assert(appIsMainThread())

        tableView.contentInset = UIEdgeInsets(top: 66, left: 0, bottom: 49, right: 0)
    }

    /**
        Asks table view to redraw some cells.

        **Warning:** Switches to main thread, which might be required.

        Usage:

            redrawRecordsAtIndexPaths(indexPaths)

        :param: indexPaths: [NSIndexPath]
    */
    func redrawRecordsAtIndexPaths(indexPaths: [NSIndexPath]) {
        appMainThread() {
            self.tableView.beginUpdates()
            self.tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
            self.tableView.endUpdates()
        }
    }

    /**
        Will enable playlist tab if it has records, disable otherwise.
    */
    func toggleDisablePlaylistTab() {

        if let tabBarCtlr = parentViewController as? UITabBarController,
            items = tabBarCtlr.tabBar.items as? [UITabBarItem] {

            items[1].enabled = DataModel.playlist.count > 0
        }
    }

    // #MARK: miscellaneous

    /**
        Downloads MDS catalog (records). Blocks UI before start, unblocks when done.
        In case of error displays the error message. Asks user if app should retry.

        **Warning:** Suppose to be run only once.

        Usage:

            loadMdsRecordsOnce()
    */
    private func loadMdsRecordsOnce() {
        if DataModel.allRecords.count == 0 {
            // #TODO: block UI
            DataModel.downloadCatalog(
                success: {
                    // #TODO: (do not forget switch to main thread!) unblock UI
                },
                fail: { error in
                    appMainThread() {
                        let msg = "Unable to download MDS catalog. The error is \(error.domain)-\(error.code). Application will retry to download catalog. Make sure you have access to the Internet."

                        appDisplayError(msg, inViewController: self, withHandler: self.loadMdsRecordsOnce)
                    }
                })
        }
    }
}

// #MARK: - UITableViewDataSource

extension SearchCatalog: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return DataModel.filteredRecords.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        assert(appIsMainThread())

        let cellId = CellId.recordCell
        let cell = tableView.dequeueReusableCellWithIdentifier(cellId) as! UITableViewCell
        let recordIndex = indexPath.row

        assert(recordIndex < DataModel.filteredRecords.count)

        let record = DataModel.filteredRecords[indexPath.row]

        if let index = find(DataModel.playlist, record) {
            // #TODO: create struct with colors
            cell.backgroundColor = UIColor(red: 250/255.0, green: 239/255.0, blue: 219/255.0, alpha: 1)
        }
        else {
            cell.backgroundColor = UIColor.whiteColor()
        }

        if let authorLbl = cell.viewWithTag(100) as? UILabel {
            authorLbl.text = record.author
        }

        if let titleLbl = cell.viewWithTag(200) as? UILabel {
            titleLbl.text = record.title
        }

        return cell
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let height: CGFloat = 88

        return height
    }
}

// #MARK: - UITableViewDelegate

extension SearchCatalog: UITableViewDelegate {
    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {

        if searchBar.isFirstResponder() {
            // #TODO: make keyboard disappear even if we touch screen
            searchBar.resignFirstResponder()
            return nil
        }

        let recordIndex = indexPath.row

        assert(recordIndex < DataModel.filteredRecords.count)

        let record = DataModel.filteredRecords[recordIndex]

        if DataModel.playlistContainsRecord(record) {
            DataModel.playlistRemoveRecord(record)
        }
        else {
            DataModel.playlistAddRecord(record)
        }

        redrawRecordsAtIndexPaths([indexPath])
        toggleDisablePlaylistTab()

        return nil
    }

    /*func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let height: CGFloat = (searchQueryHasNoResults && indexPath.row == 0) ? 88 : 44

        return height
    }*/
}

// #MARK: - UISearchBarDelegate

extension SearchCatalog: UISearchBarDelegate {
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        // println("search button clicked, search string: '\(searchBar.text)'")
        searchBar.resignFirstResponder()
        DataModel.filterRecordsWhichContainText(searchBar.text)
        tableView.reloadData()
    }

    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .TopAttached
    }
}
