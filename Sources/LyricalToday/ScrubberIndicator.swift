//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  ScrubberIndicator.swift
//  Lyrical
//
//  Created by Akshay Hegde on 11/26/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Cocoa

final class ScrubberIndicator: NSProgressIndicator {

  private let songController = SongController()
  var todayDelegate: TodayViewController?

  /// The maximum value based on the length of the scrubber in Notification Center
  private let maxScrubberValue = CGFloat(142)

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    style = .bar
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  /// Convert a given point to ScrubberIndicator's min and max values.
  /// - Parameter point: the x co-ordinate point to convert
  /// - Returns: the point converted to current song's min and max values
  private func convertToScrubbing(forPoint point: CGFloat) -> Int {
    let duration = songController.duration
    guard !duration.isEmpty else { return 0 }

    let newRange = CGFloat((duration as NSString).floatValue)
    let newVal = ((point * newRange) / maxScrubberValue)
    return Int(newVal)
  }

  private func songPosition(forMouseEvent event: NSEvent) {
    guard songController.isRunning || !songController.isStopped else {
      return
    }

    let point = convert(event.locationInWindow, from: nil)
    let convertedPoint = convertToScrubbing(forPoint: point.x)

    songController.playback(.setPlayerPosition(convertedPoint))
    doubleValue = Double(convertedPoint)
    let playerPosition = songController.playerPositionTimeStamp
    todayDelegate?.songPositionLabel?.stringValue = playerPosition
  }

  override func mouseDragged(with event: NSEvent) {
    songPosition(forMouseEvent: event)
  }

  override func mouseUp(with event: NSEvent) {
    songPosition(forMouseEvent: event)
  }
}
