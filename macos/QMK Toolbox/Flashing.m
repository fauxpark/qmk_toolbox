//
//  Flashing.m
//  qmk_toolbox
//
//  Created by Jack Humbert on 9/5/17.
//  Copyright © 2017 Jack Humbert. This code is licensed under MIT license (see LICENSE.md for details).
//

#import "Flashing.h"
#import "USB.h"

@interface Flashing ()

@property Printing * printer;

@end

@implementation Flashing
@synthesize serialPort;

- (id)initWithPrinter:(Printing *)p {
    if (self = [super init]) {
        _printer = p;
    }
    return self;
}

- (NSString *)runProcess:(NSString *)command withArgs:(NSArray<NSString *> *)args {

    [_printer print:[NSString stringWithFormat:@"%@ %@", command, [args componentsJoinedByString:@" "]] withType:MessageType_Command];
    //int pid = [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [[NSBundle mainBundle] pathForResource:command ofType:@""];
    task.currentDirectoryPath = [[NSBundle mainBundle] resourcePath];
    task.arguments = args;
    task.standardOutput = pipe;
    task.standardError = pipe;

    [task launch];

    NSData *data = [file readDataToEndOfFile];
    [file closeFile];

    NSString *grepOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    // NSLog (@"grep returned:\n%@", grepOutput);
    [_printer printResponse:grepOutput withType:MessageType_Command];
    return grepOutput;
}

- (void)flash:(NSString *)mcu withFile:(NSString *)file {
    if ([USB canFlash:AtmelDFU])
        [self flashAtmelDFU:mcu withFile:file];
    if ([USB canFlash:Caterina])
        [self flashCaterina:mcu withFile:file];
    if ([USB canFlash:Halfkay])
        [self flashHalfkay:mcu withFile:file];
    if ([USB canFlash:STM32DFU])
        [self flashSTM32DFUWithFile:file];
    if ([USB canFlash:APM32DFU])
        [self flashAPM32DFUWithFile:file];
    if ([USB canFlash:Kiibohd])
        [self flashKiibohdWithFile:file];
    if ([USB canFlash:STM32Duino])
        [self flashSTM32DuinoWithFile:file];
    if ([USB canFlash:AVRISP])
        [self flashAVRISP:mcu withFile:file];
    if ([USB canFlash:USBAsp])
        [self flashUSBAsp:mcu withFile:file];
    if ([USB canFlash:USBTiny])
        [self flashUSBTiny:mcu withFile:file];
    if ([USB canFlash:AtmelSAMBA])
        [self flashAtmelSAMBAwithFile:file];
    if ([USB canFlash:BootloadHID])
        [self flashBootloadHIDwithFile:file];
}

- (void)reset:(NSString *)mcu {
    if ([USB canFlash:AtmelDFU])
        [self resetAtmelDFU:mcu];
    if ([USB canFlash:Halfkay])
        [self resetHalfkay:mcu];
    if ([USB canFlash:AtmelSAMBA])
        [self resetAtmelSAMBA];
    if ([USB canFlash:BootloadHID])
        [self resetBootloadHID];
}

- (void)clearEEPROM:(NSString *)mcu {
    if ([USB canFlash:AtmelDFU])
        [self clearEEPROMAtmelDFU:mcu];
    if ([USB canFlash:Caterina])
        [self clearEEPROMCaterina:mcu];
    if ([USB canFlash:USBAsp])
        [self clearEEPROMUSBAsp:mcu];
}

- (BOOL)canFlash {
    return [USB areDevicesAvailable];
}

- (BOOL)canReset {
    NSArray<NSNumber *> *resettable = @[
        @(AtmelDFU),
        @(Halfkay),
        @(AtmelSAMBA),
        @(BootloadHID)
    ];
    for (NSNumber *chipset in resettable) {
        if ([USB canFlash:(Chipset)chipset.intValue])
            return YES;
    }
    return NO;
}

- (BOOL)canClearEEPROM {
    NSArray<NSNumber *> *clearable = @[
        @(AtmelDFU),
        @(Caterina),
        @(USBAsp)
    ];
    for (NSNumber *chipset in clearable) {
        if ([USB canFlash:(Chipset)chipset.intValue])
            return YES;
    }
    return NO;
}

- (void)flashAtmelDFU:(NSString *)mcu withFile:(NSString *)file {
    [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"erase", @"--force"]];
    NSString *result = [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"flash", @"--force", file]];
    if ([result containsString:@"Bootloader and code overlap."]) {
        [_printer print:@"File is too large for device" withType:MessageType_Error];
    } else {
        [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"reset"]];
    }
}

- (void)resetAtmelDFU:(NSString *)mcu {
    [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"reset"]];
}

- (void)clearEEPROMAtmelDFU:(NSString *)mcu {
    NSString * file = [[NSBundle mainBundle] pathForResource:@"reset" ofType:@"eep"];
    [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"erase", @"--force"]];
    [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"flash", @"--force", @"--eeprom", file]];
    [_printer print:@"Please reflash device with firmware now" withType:MessageType_Bootloader];
}

- (void)flashCaterina:(NSString *)mcu withFile:(NSString *)file {
    [self runProcess:@"avrdude" withArgs:@[@"-p", mcu, @"-c", @"avr109", @"-U", [NSString stringWithFormat:@"flash:w:%@:i", file], @"-P", serialPort, @"-C", @"avrdude.conf"]];
}

- (void)clearEEPROMCaterina:(NSString *)mcu {
    NSString * file = [[NSBundle mainBundle] pathForResource:@"reset" ofType:@"eep"];
    [self runProcess:@"avrdude" withArgs:@[@"-p", mcu, @"-c", @"avr109", @"-U", [NSString stringWithFormat:@"eeprom:w:%@:i", file], @"-P", serialPort, @"-C", @"avrdude.conf"]];
}

- (void)clearEEPROMUSBAsp:(NSString *)mcu {
    NSString * file = [[NSBundle mainBundle] pathForResource:@"reset" ofType:@"eep"];
    [self runProcess:@"avrdude" withArgs:@[@"-p", mcu, @"-c", @"usbasp", @"-U", [NSString stringWithFormat:@"eeprom:w:%@:i", file], @"-C", @"avrdude.conf"]];
}

- (void)flashHalfkay:(NSString *)mcu withFile:(NSString *)file {
    [self runProcess:@"teensy_loader_cli" withArgs:@[[@"-mmcu=" stringByAppendingString:mcu], file, @"-v"]];
}

- (void)resetHalfkay:(NSString *)mcu {
    [self runProcess:@"teensy_loader_cli" withArgs:@[[@"-mmcu=" stringByAppendingString:mcu], @"-bv"]];
}

- (void)flashSTM32DFUWithFile:(NSString *)file {
    if([[[file pathExtension] lowercaseString] isEqualToString:@"bin"]) {
        [self runProcess:@"dfu-util" withArgs:@[@"-a", @"0", @"-d", @"0483:DF11", @"-s", @"0x8000000:leave", @"-D", file]];
    } else {
        [_printer print:@"Only firmware files in .bin format can be flashed with dfu-util!" withType:MessageType_Error];
    }
}

- (void)flashAPM32DFUWithFile:(NSString *)file {
    if([[[file pathExtension] lowercaseString] isEqualToString:@"bin"]) {
        [self runProcess:@"dfu-util" withArgs:@[@"-a", @"0", @"-d", @"314B:0106", @"-s", @"0x8000000:leave", @"-D", file]];
    } else {
        [_printer print:@"Only firmware files in .bin format can be flashed with dfu-util!" withType:MessageType_Error];
    }
}

- (void)flashKiibohdWithFile:(NSString *)file {
    if([[[file pathExtension] lowercaseString] isEqualToString:@"bin"]) {
        [self runProcess:@"dfu-util" withArgs:@[@"-D", file]];
    } else {
        [_printer print:@"Only firmware files in .bin format can be flashed with dfu-util!" withType:MessageType_Error];
    }
}

- (void)flashSTM32DuinoWithFile:(NSString *)file {
    if([[[file pathExtension] lowercaseString] isEqualToString:@"bin"]) {
        [self runProcess:@"dfu-util" withArgs:@[@"-a", @"2", @"-d", @"1EAF:0003", @"-R", @"-D", file]];
    } else {
        [_printer print:@"Only firmware files in .bin format can be flashed with dfu-util!" withType:MessageType_Error];
    }
}

- (void)flashAVRISP:(NSString *)mcu withFile:(NSString *)file {
    [self runProcess:@"avrdude" withArgs:@[@"-p", mcu, @"-c", @"avrisp", @"-U", [NSString stringWithFormat:@"flash:w:%@:i", file], @"-P", serialPort, @"-C", @"avrdude.conf"]];
}

- (void)flashUSBTiny:(NSString *)mcu withFile:(NSString *)file {
    [self runProcess:@"avrdude" withArgs:@[@"-p", mcu, @"-c", @"usbtiny", @"-U", [NSString stringWithFormat:@"flash:w:%@:i", file], @"-C", @"avrdude.conf"]];
}

- (void)flashUSBAsp:(NSString *)mcu withFile:(NSString *)file {
    [self runProcess:@"avrdude" withArgs:@[@"-p", mcu, @"-c", @"usbasp", @"-U", [NSString stringWithFormat:@"flash:w:%@:i", file], @"-C", @"avrdude.conf"]];
}

- (void)flashAtmelSAMBAwithFile: (NSString *)file {
    [self runProcess:@"mdloader_mac" withArgs:@[@"-p", serialPort, @"-D", file, @"--restart"]];
}

- (void)resetAtmelSAMBA {
    [self runProcess:@"mdloader_mac" withArgs:@[@"-p", serialPort, @"--restart"]];
}

- (void)flashBootloadHIDwithFile: (NSString *)file {
    [self runProcess:@"bootloadHID" withArgs:@[@"-r", file]];
}

- (void)resetBootloadHID {
    [self runProcess:@"bootloadHID" withArgs:@[@"-r"]];
}

@end
