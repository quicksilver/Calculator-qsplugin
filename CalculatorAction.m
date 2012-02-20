//
//  CalculatorAction.m
//  Quicksilver
//
// Created by Kevin Ballard, modified by Patrick Robertson
// Copyright QSApp.com 2011

#import <QSCore/QSLibrarian.h>
#import <QSCore/QSNotifyMediator.h>
#import "CalculatorAction.h"
#import "CalculatorPrefPane.h"

/* CalculatePrivate.h is from a private framework, reverse engineered by Nicholas Jitkoff.
 There are no guarantees that this will work indefinitely. It may break in a future version of OS X */
#import "CalculatePrivate.h"

@implementation CalculatorActionProvider
- (id) init {
	if ((self = [super init])) {
		[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [NSNumber numberWithInteger:CalculatorDisplayNormal], kCalculatorDisplayPref,
                                                                 [NSNumber numberWithInteger:kQSCalculatorModeCalculate], kQSCalculatorMode,
                                                                 nil]];
	}
	return self;
}


- (QSObject *)calculate:(QSObject *)dObject {
	
	QSObject *result = [self performCalculation:dObject];
	NSString *outString = [result objectForType:QSTextType];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Copy the result to the clipboard
	if ([defaults objectForKey:kCalculatorCopyResultToClipboard] && [[defaults objectForKey:kCalculatorCopyResultToClipboard] boolValue]) {
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
		[pb setString:outString forType:NSStringPboardType];
	}
	
	
	switch ([[defaults objectForKey:kCalculatorDisplayPref] integerValue]) {
		case CalculatorDisplayNormal:
			// Do nothing - we're popping the result back up
			break;
		case CalculatorDisplayLargeType: {
			// Display result as large type
			QSShowLargeType(outString);
			[[QSReg preferredCommandInterface] selectObject:result];
			result = nil;
			break;
		} case CalculatorDisplayNotification: {
			// Display result as notification
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [QSResourceManager imageNamed:@"com.apple.calculator"], QSNotifierIcon,
										@"Calculation Result", QSNotifierTitle,
										outString, QSNotifierText,
										@"QSCalculatorResultNotification", QSNotifierType, nil];
			QSShowNotifierWithAttributes(attributes);
			[[QSReg preferredCommandInterface] selectObject:result];
			result = nil;
		}
	}
	
	return result;
}

- (QSObject *)performCalculation:(QSObject *)dObject {
	
	NSString *value;
    
	if ([[dObject primaryType] isEqualToString:QSFormulaType]) {
		value = [dObject objectForType:QSFormulaType];
	} else {
		value = [dObject objectForType:QSTextType];
	}

    // Remove leading '=' sign
    if ([value length] && [value characterAtIndex:0] == [@"=" characterAtIndex:0]) {
        value = [value stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
    }

    // Convert float separators
    NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
    NSString *decimalSeparator = [locale objectForKey:NSLocaleDecimalSeparator];
    NSString *groupingSeparator = [locale objectForKey:NSLocaleGroupingSeparator];

    value = [value stringByReplacingOccurrencesOfString:groupingSeparator
                                             withString:@""
                                                options:0
                                                  range:NSMakeRange(0, [value length])];
    value = [value stringByReplacingOccurrencesOfString:decimalSeparator
                                             withString:@"."
                                                options:0
                                                  range:NSMakeRange(0, [value length])];

    NSString *outString = nil;
    QSCalculatorMode mode = kQSCalculatorModeCalculate;
    NSNumber *modeNumber = [[NSUserDefaults standardUserDefaults] objectForKey:kQSCalculatorMode];
    if (modeNumber)
        mode = [[NSUserDefaults standardUserDefaults] integerForKey:kQSCalculatorMode];
    switch (mode) {
        case kQSCalculatorModeCalculate: {
            // Source taken from QSB (BELOW) See COPYING in the Resource folder for full copyright details

            // Fix up separators and decimals (for current user's locale). The Calculator framework wants
            // '.' for decimals, and no grouping separators.

            char answer[1024];
            answer[0] = '\0';
            int success	= CalculatePerformExpression((char *)[value UTF8String], 4, 1, answer);
            if (!success) {
                // calculation failed
                return dObject;
            }

            outString = [NSString stringWithUTF8String:answer];
            // Source taken from QSB Source Code (ABOVE)
            break;
        }
        case kQSCalculatorModeBC: {
            NSString *bcScript = [[NSArray arrayWithObjects:value, @"quit", @"", nil] componentsJoinedByString:@"\n"];
            NSData *inputData = [bcScript dataUsingEncoding:NSUTF8StringEncoding];

            NSTask *calculationTask = [NSTask taskWithLaunchPath:@"/usr/bin/bc" arguments:[NSArray arrayWithObjects:@"-q", @"-l", nil] input:inputData];
            NSData *output = [calculationTask launchAndReturnOutput];

            outString = [[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding] autorelease];
            outString = [outString trimWhitespace];
            break;
        }
        case kQSCalculatorModeDC: {
            NSString *dcScript = [[NSArray arrayWithObjects:value, @"p", @"", nil] componentsJoinedByString:@"\n"];

            NSTask *calculationTask = [NSTask taskWithLaunchPath:@"/usr/bin/dc" arguments:[NSArray arrayWithObjects:@"-e", dcScript, nil]];
            NSData *output = [calculationTask launchAndReturnOutput];

            outString = [[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding] autorelease];
            outString = [outString trimWhitespace];
            break;
        }
    }
	
	
	QSObject *result = [QSObject objectWithName:outString];
	[result setObject:outString forType:QSTextType];
	
	return result;
}

- (BOOL)loadIconForObject:(QSObject *)object {
	
	QSObject *result = [self performCalculation:object];
	
	// Still a formula object (i.e. there was a problem with the syntax) Use a clip icon
	if ([[result primaryType] isEqualToString:QSFormulaType]) {
		[object setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:@"'clpt'"]];
		return YES;
	}
	// Use the result (a number) as the icon
	else {
		// Max icon size for the current command interface
		NSSize maxIconSize = [[QSReg preferredCommandInterface] maxIconSize];
		NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																			pixelsWide:maxIconSize.width
																			pixelsHigh:maxIconSize.height
																		 bitsPerSample:8
																	   samplesPerPixel:4
																			  hasAlpha:YES
																			  isPlanar:NO
																		colorSpaceName:NSCalibratedRGBColorSpace
																		  bitmapFormat:0
																		   bytesPerRow:0
																		  bitsPerPixel:0]
									autorelease];
		if(bitmap) {
			NSGraphicsContext *graphicsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
			if(graphicsContext){

				NSString *resultString = [result objectForType:QSTextType];

				// Set the object's details to show the result
				[object setDetails:resultString];
				
				// Sort The text format
				NSData *data = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.QSAppearance1T"];
				NSColor *textColor = [NSUnarchiver unarchiveObjectWithData:data];
	
				// Text font size
				int size;
				NSSize textSize;
				NSFont *textFont;
				for (size = 12; size<300; size = size+2) {
					textFont = [NSFont boldSystemFontOfSize:size+1];
					textSize = [resultString sizeWithAttributes:[NSDictionary dictionaryWithObject:textFont forKey:NSFontAttributeName]];
					if (textSize.width> maxIconSize.width - 20 || textSize.height > maxIconSize.height - 20) {
						break;					
					}
				}
				 
				 // Text shadow
				 NSShadow *textShadow = [[NSShadow alloc] init];
				 [textShadow setShadowOffset:NSMakeSize(5, -5)];
				 [textShadow setShadowBlurRadius:10];
				 [textShadow setShadowColor:[NSColor colorWithDeviceWhite:0 alpha:0.64]];
				 
				NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:size-2],NSFontAttributeName,
											textColor, NSForegroundColorAttributeName,
											textShadow, NSShadowAttributeName, nil];
				
				
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
				NSRect boundingRect = [[result stringValue] boundingRectWithSize:maxIconSize options:0 attributes:nil];
				[resultString drawInRect:NSMakeRect(boundingRect.origin.x+(maxIconSize.width-textSize.width)/2, boundingRect.origin.y+(maxIconSize.height-textSize.height)/2, textSize.width, textSize.height) withAttributes:attributes];
				[NSGraphicsContext restoreGraphicsState];
				NSImage *icon = [[[NSImage alloc] initWithData:[bitmap TIFFRepresentation]] autorelease];
				[object setIcon:icon];
				
				// release objects
				[textShadow release];
		
				return YES;
			}
		}
	}
	return NO;
}

@end
