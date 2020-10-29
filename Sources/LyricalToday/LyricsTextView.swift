//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  LyricsTextView.swift
//  Lyrical
//
//  Created by Akshay Hegde on 8/8/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Cocoa

final class LyricsTextView: NSTextView {

  // This is needed to ensure that the lyrics have some amount of free space
  // between the lyrics text and the Hide Lyrics button.
  private let textHeightOffset: CGFloat = 40.0

  var textHeight: CGFloat? {
    guard let layoutManager = layoutManager, let container = textContainer else {
      return nil
    }
    layoutManager.ensureLayout(for: container)
    return layoutManager.usedRect(for: container).size.height + textHeightOffset
  }

  override func didChangeText() {
    super.didChangeText()
    invalidateIntrinsicContentSize()
  }
}
