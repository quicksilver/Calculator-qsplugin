//
//  CalculatorPrefPane.h
//  CalculatorPlugin
//
//  Created by Kevin Ballard on 7/27/04.
//  Copyright 2004 TildeSoft. All rights reserved.
//

#import <QSInterface/QSPreferencePane.h>

// Strings used in com.quicksilver.plist prefs for storing the calculator settings
#define kCalculatorDisplayPref @"CalculatorDisplayPref"
#define kCalculatorCopyResultToClipboard @"CalculatorCopyResultToClipboard"

#define CalculatorDisplayNormal 0
#define CalculatorDisplayLargeType 1
#define CalculatorDisplayNotification 2

#define kQSCalculatorMode @"CalculatorMode"

enum QSCalculatorMode {
    kQSCalculatorModeCalculate = 0,
    kQSCalculatorModeBC,
    kQSCalculatorModeDC,
};
typedef NSUInteger QSCalculatorMode;


@interface CalculatorPrefPane : QSPreferencePane {}
@end
