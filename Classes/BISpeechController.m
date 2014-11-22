/*
 
		File:			BISpeechController.m
		Program:		BIGeneric
		Author:			Michael Rossberg
						mick@binaervarianz.de
		Changes:        Vitalii Parovishnyk (Korich) 22.11.2014
						http://igrsoft.com
 
	Description:	This framework provides abstract Cocoa methods to quickly draw 2D sprites
 
 This file is part of BIGL.
 
 BIGL is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 BIGL is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with BIGL; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "BISpeechController.h"
#import "BINSExtensions.h"

@implementation BISpeechController

- (id)init
{
    self = [super init];
    if (!self) return nil;
    
    _speakThread = NO;
    _speakLock = [[NSLock alloc] init];
    _sentenceQueue = [NSMutableArray array];
    
    NewSpeechChannel(NULL, &_curSpeechChannel);
    NSAssert(_curSpeechChannel, @"Could not obtain speech channel!");

    return self;
}

//says a specific sentence
- (void)doSpeakSentence:(CFStringRef)cSentence withVoice:(int)voice
{
    VoiceSpec theVoiceSpec;
    
    NS_DURING
    if (voice == 1)
    {
        _selectedVoiceCreator = 0;
    }
    else
    {
        GetIndVoice((voice-2), &theVoiceSpec);
        
        _selectedVoiceCreator = theVoiceSpec.creator;
        _selectedVoiceID = theVoiceSpec.id;
        
        CFDictionaryRef voiceDict = (__bridge CFDictionaryRef)@{
                                                       (__bridge NSString *)kSpeechVoiceID : @(_selectedVoiceID),
                                                       (__bridge NSString *)kSpeechVoiceCreator : @(_selectedVoiceCreator)
                                                       };
        
        NSAssert(SetSpeechProperty(_curSpeechChannel, kSpeechCurrentVoiceProperty, voiceDict) != incompatibleVoice, @"Voice is not compatible");
    }
    
    SpeakCFString(_curSpeechChannel, cSentence, NULL);
    NS_HANDLER
        NSLog(@"Error raised while trying to speak");
    NS_ENDHANDLER
}

//tries every 0.1 seconds to speak something from the queue
- (void)speakThread:(id)obj
{
    NSString* s;
    int i;
    @autoreleasepool
    {
        _speakThread = YES;
        
        while(YES)
        {
            [_speakLock lock];
            
            if ([_sentenceQueue count] == 0) break;
            
            if (SpeechBusySystemWide() == 0)
            {
                s = _sentenceQueue[0];
                i = [_sentenceQueue[1] intValue];
                [self doSpeakSentence:(__bridge CFStringRef)s withVoice:i];
                [_sentenceQueue removeObjectAtIndex:1];
                [_sentenceQueue removeObjectAtIndex:0];
            }
            
            [_speakLock unlock];
            [NSThread sleep:0.2];
        }
        
        _speakThread = NO;
        [_speakLock unlock];
    }
}

//adds a sentence tp the speak queue
- (void)addSentenceToQueue:(CFStringRef)cSentence withVoice:(int)voice
{
    [_sentenceQueue addObject:(__bridge id)(cSentence)];
    [_sentenceQueue addObject:@(voice)];
    
    if (!_speakThread) [NSThread detachNewThreadSelector:@selector(speakThread:) toTarget:self withObject:nil];
}

//tries to speak something. if it does not work => put it to the queue
- (void)speakSentence:(CFStringRef)cSentence withVoice:(int)voice
{
    [_speakLock lock];

    if (SpeechBusySystemWide() || [_sentenceQueue count] != 0) [self addSentenceToQueue:cSentence withVoice:voice];
    else [self doSpeakSentence:cSentence withVoice:voice];

    [_speakLock unlock];
}

#pragma mark -

- (void) dealloc
{
    DisposeSpeechChannel(_curSpeechChannel);
    _curSpeechChannel = NULL;
}

@end
