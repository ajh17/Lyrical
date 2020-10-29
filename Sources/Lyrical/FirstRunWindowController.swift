//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  FirstRunWindowController.swift
//  Lyrical
//
//  Created by Akshay Hegde on 10/23/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Cocoa

/// Shows the user how to enable Lyrical's widget.
final class FirstRunWindowController: NSWindowController {

  convenience init() {
    self.init(windowNibName: NSNib.Name("FirstRunWindow"))
  }

  // MARK: Window life cycle
  override func windowDidLoad() {
    // Set FirstRunFinished so the user only sees this FirstRunWindowController once.
    let defaults = UserDefaults.standard
    defaults.set(true, forKey: LyricalOptions.firstRunFinished)
    super.windowDidLoad()
  }
}
