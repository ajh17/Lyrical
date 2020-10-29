//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  Song.swift
//  Lyrical
//
//  Created by Akshay Hegde on 10/11/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

/// Song contains several attributes that are in a music file.
struct Song {

  // MARK: Instance variables.
  /// The song title
  let name: String

  /// The song artist */
  let artist: String

  /// The song album
  let album: String?

  /// The stop time (in seconds) of the song.
  let finish: Double

  /// The timestamp (in seconds) of the song.
  let timestamp: Int?

  /// Initialize a Song object
  /// - Parameter name: The title (name) of the Song
  /// - Parameter artist: The name of the Song's artist
  /// - Parameter album: The name of the album which this Song is from
  /// - Parameter duration: The Song's stop time (in seconds), default = 0
  /// - Parameter timestamp: The timestamp (in seconds) of the Song, default = nil
  init(name: String, artist: String, album: String, finish: Double = 0.0, timestamp: Int? = nil) {
    self.name = name
    self.artist = artist
    self.album = album
    self.finish = finish
    self.timestamp = timestamp
  }
}
