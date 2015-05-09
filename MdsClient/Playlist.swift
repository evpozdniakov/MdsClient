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

    @IBOutlet weak var playlistTable: UITableView!

    // #MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        println("playlist will appear")

        // #TODO: do not reload if data hasn't changed
        playlistTable.reloadData()

        runCellReloadTimer()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        println("playlist did disappear")
        stopCellReloadTimer()
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

        var i = NSTimeInterval(0.25)
        cellReloadTimer = NSTimer.scheduledTimerWithTimeInterval(i, target: self, selector: Selector("reloadDownloadingRecordCells"), userInfo: nil, repeats: true)
        println("schedule timer")
    }

    /**
        Stops timer which runs table cell reloading.

        Usage:

            stopCellReloadTimer()
    */
    func stopCellReloadTimer() {
        assert(cellReloadTimer != nil)

        if let cellReloadTimer = cellReloadTimer {
            cellReloadTimer.invalidate()
            self.cellReloadTimer = nil
            println("invalidate timer")
        }
    }

    // #MARK: - redraw

    func reloadDownloadingRecordCells() {

        var indexPaths = [NSIndexPath]()
        let playlist = DataModel.playlist

        for var index = 0; index < playlist.count; ++index {
            if playlist[index].isDownloading {
                indexPaths.append(NSIndexPath(forRow: index, inSection: 0))
            }
        }

        redrawRecordsAtIndexPaths(indexPaths)
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

            if record.hasNoTracks {
                // println("A")
                progressLbl.text = "!"
                progressLbl.hidden = false
                if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
            }
            else if !record.isDownloading {
                // println("B")
                playBtn.hidden = false
                progressLbl.hidden = true
                if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
            }
            else if let downloadingProgress = record.downloadingProgress {
                // println("C")
                let progressPercent = lroundf(downloadingProgress * 100)

                progressLbl.text = "\(progressPercent)%"

                progressLbl.hidden = false
                if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
            }
            else {
                // println("D")
                if !activityIndicator.isAnimating() { activityIndicator.startAnimating() }
                progressLbl.hidden = true
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