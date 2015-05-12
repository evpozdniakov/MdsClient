//
//  RemoteMp3Player.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-04-17.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import Foundation
import AVFoundation

@objc enum MyAVPlayerStatus : Int {
    case Unknown
    case Starting
    case Playing
    case Paused
    case TimeChanging
    case Seeking
}

@objc protocol RemoteMp3PlayerDelegate {
    func remoteMp3Player(player: RemoteMp3Player, statusChanged playbackStatus: MyAVPlayerStatus)

    optional func remoteMp3Player(player: RemoteMp3Player, trackDurationDetected trackDurationMls: Int)

    optional func remoteMp3Player(player: RemoteMp3Player, currentTimeChanged currentTimeMls: Int)

    optional func remoteMp3Player(player: RemoteMp3Player, raisedError error: NSError, withMessage message: String)
}

/**
Able to play remote mp3 in foreground and background.
For playing while in the background class will register audio session,
but you have to configure application capabilities:
https://developer.apple.com/library/ios/qa/qa1668/_index.html
(Playing media while in the background using AV Foundation on iOS)

Usage:

    // create player
    player = RemoteMp3Player()

    // open remote mp3 and start KVO
    player.startPlayback(#url: NSURL)
    player.pause()
    player.resume()
    player.setVolume(value: Float)

    // close connection with mp3 and stop KVO
    player.stop()

    // set delegate and use RemoteMp3PlayerDelegate methods
    player.delegate = self
    func remoteMp3Player(player: RemoteMp3Player, statusChanged playbackStatus: MyAVPlayerStatus)

*/
class RemoteMp3Player: NSObject {
    enum PlaybackAction : Int {
        case None
        case Play
        case Pause
        case Resume
    }

    let errorDomain = "RemoteMp3Player"

    enum ErrorCode: Int {
        case UnexpectedStatusOnStart = 1
        case UnexpectedStatusOnPause = 2
        case PausedAtIsNil = 3
        case PlaybackNotPaused = 4
        case UnexpectedStatusOnResume = 5
        case UnexpectedVolume = 6
        case TimerIsNilWhilePlaying = 7
        case TimerNotNilWhilePaused = 8
        case TimerNotNilWhileTimeChanging = 9
        case TimerNotNilWhileSeeking = 10
        case TrackDurationIsNil = 11
        case UnexpectedStatusOnCompleteSeeking = 12
        case PlayerItemIsNil = 13
        case RegisterAudioSessionUnknownError = 14
    }

    var playbackStatus: MyAVPlayerStatus = .Unknown
    var player = AVPlayer()
    var playerItem: AVPlayerItem?
    let playerItemKeysToObserve = ["status"]
    var trackDuration: CMTime?
    var trackDurationMls: Int?
    var pausedAt: CMTime?
    var reportCurrentTimeTimer: NSTimer?
    // #TODO: configure from view
    let redrawTimeSliderInterval = 1.0 // seconds
    var lastPlaybackAction: PlaybackAction = .None
    var delegate: RemoteMp3PlayerDelegate?

    override init() {
        super.init()

        registerAudioSession()
    }

    deinit {
        if playbackStatus == .Playing {
            player.pause()
        }

        stopKeyPathsObserving()
    }

    // #MARK: - playback

    func startPlayback(#url: NSURL) {
        if playbackStatus != .Unknown {
            logError(.UnexpectedStatusOnStart, withMessage: "Unexpected status on start: [\(playbackStatus.rawValue)].", callFailureHandler: nil)
            return
        }

        lastPlaybackAction = .Play

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.playerItem = AVPlayerItem(URL: url)
            self.player = AVPlayer(playerItem:self.playerItem)
            self.player.play()
            self.startKeyPathsObserving()
            self.playbackStatus = .Starting
            self.delegate?.remoteMp3Player(self, statusChanged: self.playbackStatus)
        }
    }

    func stop() {
        if playbackStatus == .Playing {
            player.pause()
        }

        stopKeyPathsObserving()

        playerItem = nil
        trackDuration = nil
        trackDurationMls = nil
        pausedAt = nil

        lastPlaybackAction = .None
        playbackStatus = .Unknown

        delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
    }

    func pausePlayback() {
        if playbackStatus == .Paused {
            logError(.UnexpectedStatusOnPause, withMessage: "Unexpected status Pause on pause", callFailureHandler: nil)
            return
        }

        lastPlaybackAction = .Pause

        pausedAt = player.currentTime()
        player.pause()
        reportCurrentTimeTimer?.invalidate()
        reportCurrentTimeTimer = nil
        playbackStatus = .Paused
        delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
    }

    func resumePlayback() {
        if playbackStatus != .Paused && playbackStatus != .TimeChanging {
            logError(.UnexpectedStatusOnResume, withMessage: "Unexpected status on resume: [\(playbackStatus.rawValue)].", callFailureHandler: nil)
            return
        }

        if player.rate > 0 {
            logError(.PlaybackNotPaused, withMessage: "Playback not paused.", callFailureHandler: nil)
            return
        }

        if pausedAt == nil {
            logError(.PausedAtIsNil, withMessage: "PausedAt is nil.", callFailureHandler: nil)
            return
        }

        lastPlaybackAction = .Resume
        player.play()

        if let pausedAt = pausedAt {
            playbackStatus = .Playing
            delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
            playbackStatus = .Seeking
            delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
            player.seekToTime(pausedAt, completionHandler: seekToTimeCallback)
        }
    }

    func setVolumeTo(value: Float) {
        if value < 0 || value > 1 {
            logError(.UnexpectedVolume, withMessage: "Unexpected volume.", callFailureHandler: nil)
            return
        }

        player.volume = value
    }

    func startSeeking() {
        switch (playbackStatus) {
            case .Playing:
                if reportCurrentTimeTimer == nil {
                    logError(.TimerIsNilWhilePlaying, withMessage: "Timer is nil while playing.", callFailureHandler: nil)
                    return
                }
            case .Paused:
                if reportCurrentTimeTimer != nil {
                    logError(.TimerNotNilWhilePaused, withMessage: "Timer is nil while paused.", callFailureHandler: nil)
                    return
                }
            case .TimeChanging:
                if reportCurrentTimeTimer != nil {
                    logError(.TimerNotNilWhileTimeChanging, withMessage: "Timer is nil while time changing.", callFailureHandler: nil)
                    return
                }
            case .Seeking:
                if reportCurrentTimeTimer != nil {
                    logError(.TimerNotNilWhileSeeking, withMessage: "Timer not nil while seeking.", callFailureHandler: nil)
                    return
                }
            default: break
        }

        reportCurrentTimeTimer?.invalidate()
        reportCurrentTimeTimer = nil
        playbackStatus = .TimeChanging
    }

    func completeSeeking(position: Float) {
        if playbackStatus != .TimeChanging {
            logError(.UnexpectedStatusOnCompleteSeeking, withMessage: "Unexpected status on completeSeeking: [\(playbackStatus.rawValue)].", callFailureHandler: nil)
            return
        }

        if trackDuration == nil {
            logError(.TrackDurationIsNil, withMessage: "Track duration is nil.", callFailureHandler: nil)
            return
        }

        if let trackDuration = trackDuration {
            let value = Float(trackDuration.value) * position
            let seekTo = CMTimeMake(Int64(value), trackDuration.timescale)

            if lastPlaybackAction == .Pause {
                pausedAt = seekTo
            }
            else {
                playbackStatus = .Seeking
                delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
                player.seekToTime(seekTo, completionHandler: seekToTimeCallback)
            }

        }
    }

    func seekToTimeCallback(success: Bool) {
        if success && playbackStatus == .Seeking {
            if player.rate == 0 {
                player.play()
            }
            configureReportCurrentTimeTimer()
            playbackStatus = .Playing
            delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
        }
    }

    func configureReportCurrentTimeTimer() {
        if reportCurrentTimeTimer == nil {
            reportCurrentTimeTimer = NSTimer.scheduledTimerWithTimeInterval(redrawTimeSliderInterval, target: self, selector: Selector("reportCurrentTime"), userInfo: nil, repeats: true)
        }
    }

    // #MARK: - KVO

    func startKeyPathsObserving() {
        for keyPath in playerItemKeysToObserve {
            playerItem?.addObserver(self, forKeyPath: keyPath, options: .New, context: nil)
        }
    }

    func stopKeyPathsObserving() {
        for keyPath in playerItemKeysToObserve {
            playerItem?.removeObserver(self, forKeyPath: keyPath)
        }
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if playerItem == nil {
            logError(.PlayerItemIsNil, withMessage: "PlayerItemIsNil", callFailureHandler: nil)
            return
        }

        if let playerItem = object as? AVPlayerItem {
            if keyPath == "status" && playerItem.status == .ReadyToPlay {
                trackDuration = playerItem.duration
                trackDurationMls = mlsFromCMTime(trackDuration)

                if let trackDurationMls = trackDurationMls {
                    delegate?.remoteMp3Player?(self, trackDurationDetected: trackDurationMls)
                }

                playbackStatus = .Playing
                configureReportCurrentTimeTimer()
                delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
            }
        }
    }

    // #MARK: - miscellaneous

    func mlsFromCMTime(time: CMTime?) -> Int? {
        if let time = time {
            return lroundf(Float(CMTimeGetSeconds(time)) * 1000)
        }

        return nil
    }

    func reportCurrentTime() {
        if let playerItem = playerItem, trackDurationMls = trackDurationMls {
            let currentTime = playerItem.currentTime()

            if let currentTimeMls = mlsFromCMTime(currentTime) {
                delegate?.remoteMp3Player?(self, currentTimeChanged: currentTimeMls)
            }
        }
    }

    func registerAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        var error: NSError?

        if audioSession.setCategory(AVAudioSessionCategoryPlayback, error: &error) && audioSession.setActive(true, error: &error) {
            // all fine
        }
        else if let error = error {
            delegate?.remoteMp3Player?(self, raisedError: error, withMessage: "Cant register audio session because of the error: [\(error)].")
        }
        else {
            let error = NSError(domain: errorDomain, code: ErrorCode.RegisterAudioSessionUnknownError.rawValue, userInfo: nil)
            delegate?.remoteMp3Player?(self, raisedError: error, withMessage: "Cant register audio session because of unknown error.")
        }
    }

    // #MARK: helpers

    /**
        Will create error:NSError and call generic function logError()

        **Warning:** Static method.

        Usage:

            logError(.NoResponseFromServer, withMessage: "Server didn't return any response.", callFailureHandler: fail)

        :param: code: ErrorCode Error code.
        :param: message: String Error description.
        :param: failureHandler: ( NSError->Void )? Failutre handler.
    */
    func logError(code: ErrorCode,
                                withMessage message: String,
                                callFailureHandler fail: (NSError->Void)? ) {

        let error = NSError(domain: errorDomain, code: code.rawValue, userInfo: nil)

        delegate?.remoteMp3Player?(self, raisedError: error, withMessage: message)
    }
}