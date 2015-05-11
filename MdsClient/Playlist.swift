//
//  Playlist.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-04-30.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import UIKit

class Playlist: UIViewController {
    // #MARK: - ivars

    var cellReloadTimer: NSTimer?
    var storedLocallyList: [Record]?
    var hasNoTracksList: [Record]?

    @IBOutlet weak var playlistTable: UITableView!

    // #MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        // println("playlist will appear")
        storedLocallyList = [Record]()
        hasNoTracksList = [Record]()
        for record in DataModel.playlist {
            if record.isStoredLocally {
                storedLocallyList!.append(record)
            }
            else if record.hasNoTracks {
                hasNoTracksList!.append(record)
            }
        }

        // #TODO: do not reload if data hasn't changed
        playlistTable.reloadData()


        runCellReloadTimer()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        // println("playlist did disappear")
        stopCellReloadTimer()
        storedLocallyList = nil
        hasNoTracksList = nil
    }

    // #MARK: - run/stop cell reloader

    /**
        Creates timer which runs table cell reloading.
        Timer stored in ivar cellReloadTimer.

        Usage:

            runCellReloadTimer()
    */
    func runCellReloadTimer() {
        assert(cellReloadTimer == nil)

        let i = NSTimeInterval(0.25)
        cellReloadTimer = NSTimer.scheduledTimerWithTimeInterval(i, target: self, selector: Selector("reloadDownloadingRecordCells"), userInfo: nil, repeats: true)
        // println("schedule timer")
    }

    /**
        Stops timer which runs table cell reloading.
        There are two places where it can be triggered from:
        - view controller did disappear
        - all the files downloaded & stored locally

        Usage:

            stopCellReloadTimer()
    */
    func stopCellReloadTimer() {
        if let cellReloadTimer = cellReloadTimer {
            cellReloadTimer.invalidate()
            self.cellReloadTimer = nil
            // println("invalidate timer")
        }
    }

    // #MARK: - redraw

    /**
        Creates [NSIndexPath] for playlist records not stored locally yet, then passes it to redrawRecordsAtIndexPaths().
        If array count is zero, will call stopCellReloadTimer().

        Usage:

            reloadDownloadingRecordCells(indexPaths)
    */
    func reloadDownloadingRecordCells() {
        assert(storedLocallyList != nil)
        assert(hasNoTracksList != nil)

        var indexPaths = [NSIndexPath]()

        for (i, record) in enumerate(DataModel.playlist) {
            if record.isDownloading {
                indexPaths.append(NSIndexPath(forRow: i, inSection: 0))
            }
            else if record.hasNoTracks && find(hasNoTracksList!, record) == nil {
                // reload one last time
                // println("-----------reload last one time row: \(i)")
                indexPaths.append(NSIndexPath(forRow: i, inSection: 0))
                hasNoTracksList!.append(record)
            }
            else if record.isStoredLocally && find(storedLocallyList!, record) == nil {
                // reload one last time
                // println("-----------reload last one time row: \(i)")
                indexPaths.append(NSIndexPath(forRow: i, inSection: 0))
                storedLocallyList!.append(record)
            }
        }

        redrawRecordsAtIndexPaths(indexPaths)

        if storedLocallyList!.count + hasNoTracksList!.count == DataModel.playlist.count {
            // println("-------------stopCellReloadTimer")
            stopCellReloadTimer()
        }
    }


    func redrawRecordsAtIndexPaths(indexPaths: [NSIndexPath]) {
        assert(isMainThread())

        /* if !isMainThread() {
            dispatch_async(dispatch_get_main_queue()) {
                self.redrawRecordsAtIndexPaths(indexPaths)
            }
            return
        } */

        playlistTable.beginUpdates()
        playlistTable.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
        playlistTable.endUpdates()
    }
    // #MARK: miscellaneous

    func isMainThread() -> Bool {
        return NSThread.currentThread().isMainThread
    }
}

// #MARK: - UITableViewDataSource

extension Playlist: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return DataModel.playlist.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCellWithIdentifier("RecordCell") as! UITableViewCell
        let recordIndex = indexPath.row

        assert(recordIndex < DataModel.playlist.count)

        let record = DataModel.playlist[indexPath.row]

        // println("row: \(indexPath.row)")

        if let authorLbl = cell.viewWithTag(100) as? UILabel,
            titleLbl = cell.viewWithTag(200) as? UILabel,
            playBtn = cell.viewWithTag(300) as? UIButton,
            pauseBtn = cell.viewWithTag(400) as? UIButton,
            activityIndicator = cell.viewWithTag(500) as? UIActivityIndicatorView,
            progressLbl = cell.viewWithTag(600) as? UILabel {

            authorLbl.text = record.author
            titleLbl.text = record.title

            playBtn.hidden = true
            pauseBtn.hidden = true
            progressLbl.hidden = true
            activityIndicator.stopAnimating()

            if record.hasNoTracks {
                progressLbl.text = "!"
                progressLbl.hidden = false
            }
            else if record.isDownloading {
                let progressPercent = lroundf(record.downloadingProgress! * 100)
                progressLbl.text = "\(progressPercent)%"
                progressLbl.hidden = false
            }
            else if record.isStoredLocally {
                playBtn.hidden = false
            }
            else {
                activityIndicator.startAnimating()
            }
        }

        return cell
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let height: CGFloat = 88

        return height
    }
}

// #MARK: - UITableViewDelegate

extension Playlist: UITableViewDelegate {

}