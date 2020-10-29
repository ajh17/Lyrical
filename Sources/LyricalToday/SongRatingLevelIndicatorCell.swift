//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  SongRatingLevelIndicator.swift
//  Lyrical
//
//  Created by Akshay Hegde on 8/3/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Cocoa

final class SongRatingLevelIndicatorCell: NSLevelIndicatorCell {

  override var isHighlighted: Bool {
    didSet {
      super.isHighlighted = true
    }
  }

  override init(levelIndicatorStyle: NSLevelIndicator.Style) {
    super.init(levelIndicatorStyle: .rating)
    isHighlighted = true
    isEditable = true
    isContinuous = true
    focusRingType = .none
  }

  required init(coder: NSCoder) {
    super.init(coder: coder)
  }
}
