//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  DurationTextField.swift
//  Lyrical
//
//  Created by Akshay Hegde on 2/14/15.
//  Copyright (c) 2015 Akshay Hegde. All rights reserved.
//

import Cocoa

final class DurationTextField: NSTextField {

  private let songController = SongController()
  var todayDelegate: TodayViewController?
  private var showRemaining = UserDefaults.standard.bool(forKey: WidgetOptions.showRemaining)

  override func mouseDown(with event: NSEvent) {
    guard !songController.isStopped else {
      return
    }

    // Update showRemaining flags for self and delegate.
    // The delegate will update timeRemaining every second
    // if showRemaining is true
    showRemaining = !showRemaining
    todayDelegate?.showRemaining = showRemaining
    stringValue = showRemaining ? songController.timeRemaining : songController.durationTimeStamp
  }
}
