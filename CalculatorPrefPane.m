//
//  CalculatorPrefPane.m
//  CalculatorPlugin
//
//  Created by Kevin Ballard on 7/27/04.
//  Copyright 2004 TildeSoft. All rights reserved.
//

#import "CalculatorPrefPane.h"
#import "CalculatorAction.h"

@implementation CalculatorPrefPane

- (id) init {
	if ((self = [super init])) {
		[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:CalculatorDisplayNormal], kCalculatorDisplayPref, nil]];
	}
	return self;
}


@end
