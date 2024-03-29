//
//  CalculatorAction.m
//  Quicksilver
//
// Created by Kevin Ballard, modified by Patrick Robertson
// Copyright QSApp.com 2011

#import <QSCore/QSLibrarian.h>
#import <QSCore/QSNotifyMediator.h>
#import <QSFoundation/QSGCD.h>
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
	
	QSObject *result = [self performCalculation:dObject fromAction:YES];
	[result setPrimaryType:QSFormulaType];
	[result setIcon:[self iconForObject:result]];
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
			QSGCDMainSync(^{
				QSShowLargeType(outString);
				[[QSReg preferredCommandInterface] selectObject:result];
			});
			result = nil;
			break;
		} case CalculatorDisplayNotification: {
			// Display result as notification
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [QSResourceManager imageNamed:@"com.apple.calculator"], QSNotifierIcon,
										@"Calculation Result", QSNotifierTitle,
										outString, QSNotifierText,
										@"QSCalculatorResultNotification", QSNotifierType, nil];
			QSGCDMainSync(^{
				QSShowNotifierWithAttributes(attributes);
				[[QSReg preferredCommandInterface] selectObject:result];
			});
			result = nil;
		}
	}
	
	return result;
}

- (QSObject *)performCalculation:(QSObject *)dObject fromAction:(BOOL)fromAction {
	
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

    NSString *ungrouped = [value stringByReplacingOccurrencesOfString:groupingSeparator
                                             withString:@""
                                                options:0
                                                  range:NSMakeRange(0, [value length])];
    
    // Check to see if the user used grouping in their expression. If they did, remember it and format the answer to use grouping as well.
    BOOL usedGrouping = FALSE;
    if (![ungrouped isEqualToString:value]) {
        usedGrouping = TRUE;
    }
    value = ungrouped;
    
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
            int success	= CalculatePerformExpression((char *)[value UTF8String], 20, 1, answer);
            if (!success) {
                // calculation failed
                if (fromAction) {
                    QSShowAppNotifWithAttributes(@"calculator", NSLocalizedStringFromTableInBundle(@"Calculation failed", nil, [NSBundle bundleForClass:[self class]], @"title of the calculation failed notif"), [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Unable to calculate %@", nil, [NSBundle bundleForClass:[self class]], @"title of the calculation failed notif"), value]);
                }
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
    
    
    if (![decimalSeparator isEqualToString:@"."]) {
        outString = [outString stringByReplacingOccurrencesOfString:@"." withString:decimalSeparator];
    }
    
    NSArray *components = [outString componentsSeparatedByString:decimalSeparator];
    NSArray *groupedComponents = components;
    // format to use the grouping separator if the user used it in their original expression
    if (usedGrouping && [[components objectAtIndex:0] length] > 3) {
        ungrouped = outString;
        unichar ans[1024];
        NSMutableString *formatted_ans = [NSMutableString string];
        [[components objectAtIndex:0] getCharacters:ans];
        NSInteger i;
        for (i  = [[components objectAtIndex:0] length] - 3; i > 0; i = i-3) {
            [formatted_ans prependFormat:@"%@%@", groupingSeparator, [[components objectAtIndex:0] substringWithRange:NSMakeRange(i, 3)]];
        }
        if (i != -3) {
            [formatted_ans prependString:[[components objectAtIndex:0] substringWithRange:NSMakeRange(0, i+3)]];
        }
        if ([components count] > 1) {
            [formatted_ans appendFormat:@"%@%@", decimalSeparator, [components lastObject]];
        }
        outString = [[formatted_ans copy] autorelease];
        groupedComponents = [outString componentsSeparatedByString:decimalSeparator];
    }
    
    // Format the outstring to a certain number of decimal places
    if ([components count] > 1) {
        
        NSInteger numberOfDecimalPlaces = 7 - ([[components objectAtIndex:0] length]);
        if (numberOfDecimalPlaces > 0) {
            NSUInteger decimalLength = numberOfDecimalPlaces > (NSInteger)[[components lastObject] length] ? [[components lastObject] length] : numberOfDecimalPlaces;
            NSRange powerQualifierRange = [[components lastObject] rangeOfString:@"e"];
            NSString *powerQualifierString = nil;
            if (powerQualifierRange.location != NSNotFound) {
                NSUInteger powerQualifierLength = [[components lastObject] length] - powerQualifierRange.location;
                decimalLength = decimalLength - powerQualifierLength;
                powerQualifierString = [[components lastObject] substringFromIndex:powerQualifierRange.location];
            }
            outString = [NSString stringWithFormat:@"%@%@%@%@", [groupedComponents objectAtIndex:0], decimalLength > 0 ? decimalSeparator : @"", decimalLength > 0 ? [[groupedComponents lastObject] substringWithRange:NSMakeRange(0, decimalLength)] : @"", powerQualifierString ? powerQualifierString : @""];
        } else {
            outString = [groupedComponents objectAtIndex:0];
        }
    }
    

    
	QSObject *result = [QSObject objectWithName:outString];
	[result setObject:outString forType:QSTextType];
	
	return result;
}

-(NSImage *)iconForObject:(QSObject *)object {
 	NSString *resultString = [object objectForType:QSTextType];
	// Max icon size for the current command interface
	NSSize maxIconSize = QSSize128;
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
        // Sort The text format
        NSData *data = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.QSAppearance1T"];
        NSColor *textColor = [NSUnarchiver unarchiveObjectWithData:data];
        
        // Text font size
        int size;
        NSSize textSize;
        NSFont *textFont;
        for (size = 10; size<300; size = size+2) {
            textFont = [NSFont systemFontOfSize:size+1];
            textSize = [resultString sizeWithAttributes:[NSDictionary dictionaryWithObject:textFont forKey:NSFontAttributeName]];
            if (textSize.width> maxIconSize.width - 10 || textSize.height > maxIconSize.height - 10) {
                break;
            }
        }
        
        // Text shadow
        
        NSShadow *textShadow = [[NSShadow alloc] init];
        int textShadowSize = (size > 20) ? size : 0;
        [textShadow setShadowOffset:NSMakeSize(textShadowSize/40, -textShadowSize/40)];
        [textShadow setShadowBlurRadius:textShadowSize/10];
        [textShadow setShadowColor:[NSColor colorWithDeviceWhite:0 alpha:0.64]];
        
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:size-2],NSFontAttributeName,
                                    textColor, NSForegroundColorAttributeName,
                                    textShadow, NSShadowAttributeName, nil];
        
        
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
        NSRect boundingRect = [resultString boundingRectWithSize:maxIconSize options:0 attributes:nil];
        [resultString drawInRect:NSMakeRect(boundingRect.origin.x+(maxIconSize.width-textSize.width)/2, boundingRect.origin.y+(maxIconSize.height-textSize.height)/2, textSize.width, textSize.height) withAttributes:attributes];
        [NSGraphicsContext restoreGraphicsState];
        NSImage *icon = [[NSImage alloc] initWithSize:[bitmap size]];
        [icon addRepresentation:bitmap];
        // release objects
        [textShadow release];
        return icon;
	}
	return nil;
}
- (void)setQuickIconForObject:(QSObject *)object {

	QSObject *result = [self performCalculation:object fromAction:NO];
	
	// Still a formula object (i.e. there was a problem with the syntax) Use a clip icon
	if ([[result primaryType] isEqualToString:QSFormulaType]) {
		[object setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:@"'clpt'"]];
		return;
	}
	// Use the result (a number) as the icon
	else {
		NSImage *icon = [self iconForObject:result];
		if (icon) {
			[object setIcon:icon];

			// Set the object's details to show the result
			NSString *resultString = [result objectForType:QSTextType];
			[object setDetails:resultString];
			
		}
		
	}
	return;
}

@end
