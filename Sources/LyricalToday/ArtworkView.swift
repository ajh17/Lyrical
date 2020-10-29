//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  ArtworkView.swift
//  Lyrical
//
//  Created by Akshay Hegde on 10/18/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Cocoa

final class ArtworkView: NSImageView {
  override func mouseDown(with event: NSEvent) {
    let workspace = NSWorkspace.shared
    guard
      let appURL = workspace.urlForApplication(withBundleIdentifier: MusicPlayer.bundleIdentifier)
    else {
      return
    }

    // The default configuration, activate and bring to the foreground
    let configuration = NSWorkspace.OpenConfiguration()
    workspace.openApplication(at: appURL, configuration: configuration)
  }
}
