//
//  main.m
//  tinyrabbit
//
//  Created by Josue Alonso Rodriguez on 7/21/25.
//
#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/ps/IOPowerSources.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>
#import <ApplicationServices/ApplicationServices.h>
#import <IOKit/pwr_mgt/IOPM.h>

BOOL isMonitorAwake = true;

BOOL isMouseConnected(void) {
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (CFGetTypeID(manager) != IOHIDManagerGetTypeID()) {
        return NO;
    }

    NSDictionary *matchingDict = @{
        @kIOHIDDeviceUsagePageKey: @(kHIDPage_GenericDesktop),
        @kIOHIDDeviceUsageKey: @(kHIDUsage_GD_Mouse)
    };
    IOHIDManagerSetDeviceMatching(manager, (__bridge CFDictionaryRef)matchingDict);

    CFSetRef deviceSet = IOHIDManagerCopyDevices(manager);
    if (!deviceSet) {
        CFRelease(manager);
        return NO;
    }

    CFIndex count = CFSetGetCount(deviceSet);
    CFRelease(deviceSet);
    CFRelease(manager);

    return count > 0;
}

void wakeDisplay(void) {
    IOPMAssertionID assertionID;
    IOPMAssertionDeclareUserActivity(CFSTR(""), kIOPMUserActiveLocal, &assertionID);
}

int get_percentage(void){
    CFTypeRef powerSourceInfo = IOPSCopyPowerSourcesInfo();
    CFArrayRef powerSources = IOPSCopyPowerSourcesList(powerSourceInfo);
    CFDictionaryRef powerSource = NULL;
    long numberOfSources = CFArrayGetCount(powerSources);
    if (numberOfSources == 0)
    {
        NSLog(@"Problem, no power sources detected");
    }
    else
    {
        if (numberOfSources == 1)
        {
            NSLog(@"One power source detected");
            powerSource = IOPSGetPowerSourceDescription(powerSourceInfo, CFArrayGetValueAtIndex(powerSources, 0));
        }
        else
        {
            NSLog(@"More than one power source detected, using first one available");
            powerSource = IOPSGetPowerSourceDescription(powerSourceInfo, CFArrayGetValueAtIndex(powerSources, 0));
        }
        
        const void *psValue;
        int curCapacity = 0;
        int maxCapacity = 0;
        int percentage;
        
        psValue = CFDictionaryGetValue(powerSource, CFSTR(kIOPSCurrentCapacityKey));
        CFNumberGetValue((CFNumberRef)psValue, kCFNumberSInt32Type, &curCapacity);
        psValue = CFDictionaryGetValue(powerSource, CFSTR(kIOPSMaxCapacityKey));
        CFNumberGetValue((CFNumberRef)psValue, kCFNumberSInt32Type, &maxCapacity);
        percentage = (int)((double)curCapacity/(double)maxCapacity * 100);
        return percentage;
    }
    return 101;
}


Float32 getSystemVolume(void) {
    AudioDeviceID deviceID = kAudioObjectUnknown;
    UInt32 dataSize = sizeof(deviceID);
    AudioObjectPropertyAddress defaultOutputDevicePropertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &defaultOutputDevicePropertyAddress,
                                                 0, NULL,
                                                 &dataSize,
                                                 &deviceID);
    if (status != noErr) {
        NSLog(@"Error getting default output device: %d", status);
        return -1.0;
    }

    Float32 volume;
    AudioObjectPropertyAddress volumePropertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMain
    };

    dataSize = sizeof(volume);
    status = AudioObjectGetPropertyData(deviceID,
                                        &volumePropertyAddress,
                                        0, NULL,
                                        &dataSize,
                                        &volume);
    if (status != noErr) {
        NSLog(@"Error getting system volume: %d", status);
        return -1.0;
    }

    return volume;
}

void setSystemVolume(Float32 volume) {
    AudioDeviceID deviceID = kAudioObjectUnknown;
    UInt32 dataSize = sizeof(deviceID);
    AudioObjectPropertyAddress defaultOutputDevicePropertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &defaultOutputDevicePropertyAddress,
                                                 0, NULL,
                                                 &dataSize,
                                                 &deviceID);
    if (status != noErr) {
        NSLog(@"Error getting default output device: %d", status);
        return;
    }

    AudioObjectPropertyAddress volumePropertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMain
    };

    status = AudioObjectSetPropertyData(deviceID,
                                        &volumePropertyAddress,
                                        0, NULL,
                                        sizeof(Float32),
                                        &volume);
    if (status != noErr) {
        NSLog(@"Error setting system volume: %d", status);
    }
}


NSString* getDefaultAudioOutputDeviceName(void) {
    AudioDeviceID outputDeviceID = 0;
    UInt32 size = sizeof(outputDeviceID);
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, &outputDeviceID);
    if (status != noErr) {
        NSLog(@"Error getting default output device: %d", status);
        return nil;
    }

    CFStringRef deviceName = NULL;
    size = sizeof(deviceName);
    AudioObjectPropertyAddress nameAddress = {
        kAudioObjectPropertyName,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    status = AudioObjectGetPropertyData(outputDeviceID, &nameAddress, 0, NULL, &size, &deviceName);
    if (status != noErr || deviceName == NULL) {
        NSLog(@"Error getting device name: %d", status);
        return nil;
    }

    return CFBridgingRelease(deviceName);
}

BOOL setDefaultOutputDevice(AudioDeviceID deviceID) {
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus status = AudioObjectSetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, sizeof(deviceID), &deviceID);
    if (status != noErr) {
        NSLog(@"Failed to set default output device: %d", status);
        return NO;
    }
    return YES;
}


AudioDeviceID getDeviceIDByName(NSString *deviceName) {
    UInt32 dataSize = 0;
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, NULL, &dataSize);
    if (status != noErr) {
        NSLog(@"Error getting device list size: %d", status);
        return kAudioObjectUnknown;
    }

    int deviceCount = (int)(dataSize / sizeof(AudioDeviceID));
    AudioDeviceID *deviceIDs = (AudioDeviceID *)malloc(dataSize);

    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &dataSize, deviceIDs);
    if (status != noErr) {
        NSLog(@"Error getting device list: %d", status);
        free(deviceIDs);
        return kAudioObjectUnknown;
    }

    AudioDeviceID foundDeviceID = kAudioObjectUnknown;

    for (int i = 0; i < deviceCount; i++) {
        AudioDeviceID deviceID = deviceIDs[i];

        // Get device name
        CFStringRef name = NULL;
        UInt32 nameSize = sizeof(name);
        AudioObjectPropertyAddress nameAddress = {
            kAudioObjectPropertyName,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };

        status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, NULL, &nameSize, &name);
        if (status == noErr && name) {
            NSString *deviceNameStr = (__bridge NSString *)name;
            if ([deviceNameStr isEqualToString:deviceName]) {
                foundDeviceID = deviceID;
                CFRelease(name);
                break;
            }
            CFRelease(name);
        }
    }

    free(deviceIDs);
    return foundDeviceID;
}


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSMutableDictionary* config;
        NSString* configPath = @"tinyrabbit.plist";
        NSFileManager* defaultManager = [NSFileManager defaultManager];
        if ([defaultManager fileExistsAtPath:configPath]) {
            config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];
        } else {
            NSLog(@"Creating configuration...");
            NSString* defaultAudioName = getDefaultAudioOutputDeviceName();
            if ([defaultAudioName containsString:@" (eqMac)"]) {
                defaultAudioName = [defaultAudioName stringByReplacingOccurrencesOfString:@" (eqMac)" withString:@""];
            }
            config = [[NSMutableDictionary alloc] init];
            config[@"kvm"] = @YES;
            config[@"batteryCut"] = @0;
            config[@"volume"] = @(getSystemVolume());
            config[@"interval"] = @2;
            config[@"audioManagement"] = @NO;
            config[@"audioDevice"] = defaultAudioName;
            config[@"warmDevice"] = @NO;
            config[@"sideComputer"] = @"";
            [config writeToFile:configPath atomically:YES];
        }
        while (true) {
            [NSThread sleepForTimeInterval:[config[@"interval"] doubleValue]];
            if ([config[@"kvm"] boolValue]){
                if (isMouseConnected() && !isMonitorAwake) {
                    //awake monitor
                    isMonitorAwake = YES;
                    wakeDisplay();
                    printf("waking monitor\n");
                } else if (!isMouseConnected() && isMonitorAwake) {
                    printf("mouse disconnected, turning off monitor\n");
                    if ([config[@"warmDevice"] boolValue]) {
                        NSString* wakeURL = [NSString stringWithFormat:@"http://%@:11812/wake", config[@"sideComputer"]];
                        NSLog(@"Sending wake request to %@", wakeURL);
                        [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:wakeURL]] resume];
                    }
                    isMonitorAwake = NO;
                    system("pmset displaysleepnow");
                }
            }
            if (config[@"audioManagement"] && isMonitorAwake) {
                NSString* deviceName = getDefaultAudioOutputDeviceName();
                NSString* eqDevice = [NSString stringWithFormat:@"%@ (eqMac)", config[@"audioDevice"]];
                float currentVolume = getSystemVolume();
                if (![deviceName containsString:config[@"audioDevice"]]) {
                    AudioDeviceID targetDevice = getDeviceIDByName(config[@"audioDevice"]);
                    setDefaultOutputDevice(targetDevice);
                    [NSThread sleepForTimeInterval:3];
                    setSystemVolume([config[@"volume"] floatValue]);
                } else if ([deviceName isEqualToString:eqDevice] && (currentVolume != [config[@"volume"] floatValue]) ) {
                    NSLog(@"Updating volume setting");
                    config[@"volume"] = @(getSystemVolume());
                    [config writeToFile:configPath atomically:NO];
                }
            }

            if ([config[@"batteryCut"] intValue] > 0){
                if (get_percentage() < [config[@"batteryCut"] intValue]){
                    NSLog(@"Battery level down, turning off...");
                    system("shutdown -h now");
                }
            }
             
            
        }
    }
    return 0;
}
