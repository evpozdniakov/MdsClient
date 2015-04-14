//
//  Track.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-04-13.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import Foundation

class Track: NSObject, NSCoding {
	/* {
	    bitrate = 168kbps;
	    channels = Stereo;
	    id = 12772;
	    mode = VBR;
	    size = 11141120;
	    url = "http://mds.mds-club.ru/Kir_Bulychev_-_Oni_uzhe_zdes'!.mp3";
	} */

	var id: Int
	var bitrate: String
	var channels: String
	var mode: String
	var size: Int
	var url: NSURL

	init(id: Int, bitrate: String, channels: String, mode: String, size: Int, url: NSURL) {
		self.id = id
		self.bitrate = bitrate
		self.channels = channels
		self.mode = mode
		self.size = size
		self.url = url
	}

    required init(coder aDecoder: NSCoder) {
        id = aDecoder.decodeIntegerForKey("Id")
        bitrate = aDecoder.decodeObjectForKey("Bitrate") as! String
        channels = aDecoder.decodeObjectForKey("Channels") as! String
        mode = aDecoder.decodeObjectForKey("Mode") as! String
        size = aDecoder.decodeIntegerForKey("Size")
        url = aDecoder.decodeObjectForKey("Url") as! NSURL

        super.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeInteger(id, forKey: "Id")
        aCoder.encodeObject(bitrate, forKey: "Bitrate")
        aCoder.encodeObject(channels, forKey: "Channels")
        aCoder.encodeObject(mode, forKey: "Mode")
        aCoder.encodeInteger(size, forKey: "Size")
        aCoder.encodeObject(url, forKey: "Url")
    }
}

/* struct RecordSource {
    var domain: String
    var url: NSURL
    
    init(domain: String, url: NSURL) {
        self.domain = domain
        self.url = url
    }
} */