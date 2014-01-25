//
//  main.m
//  ChapterExtract
//
//  Created by Maximilian Christ on 20/01/14.
//  Copyright (c) 2014 McZonk. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString * NSStringWithTimeInterval(NSTimeInterval t)
{
	NSTimeInterval milliseconds = remainder(t, 1.0);
	t = floor(t);
	
	NSTimeInterval seconds = fmod(t, 60.0);
	t = floor(t / 60.0);
	
	NSTimeInterval minutes = fmod(t, 60.0);
	t = floor(t / 60.0);
	
	NSTimeInterval hours = t;
	
	return [NSString stringWithFormat:@"%02.0f:%02.0f:%02.0f.%03.0f", hours, minutes, seconds, milliseconds];
}

static NSString * StartKey = @"start";
static NSString * DurationKey = @"duration";
static NSString * TitleKey = @"title";

int main(int argc, const char **argv)
{
	@autoreleasepool
	{
		if(argc < 2)
		{
			printf("Usage: %s inputfile outputfile\n", argv[0]);
			return -1;
		}
		
		const char *assetFile = argv[1];
		NSURL *assetURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s", assetFile]];
		
		NSURL *outputURL = nil;
		if(argc > 2)
		{
			const char *outputFile = argv[2];
			outputURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s", outputFile]];
		}
		else
		{
			outputURL = [assetURL.URLByDeletingPathExtension URLByAppendingPathExtension:@"txt"];
		}
		
		AVAsset *asset = [AVAsset assetWithURL:assetURL];
		
		// this is the alternative, but it sometimes returns nil
		//NSArray *preferredLanguages = NSLocale.preferredLanguages;
		//NSArray *chapters = [asset chapterMetadataGroupsBestMatchingPreferredLanguages:preferredLanguages];
		
		NSMutableArray *chapterInfos = [NSMutableArray array];
		
		NSArray *tracks = asset.tracks;
		for(AVAssetTrack *track in tracks)
		{
			if(!track.isEnabled)
			{
				continue;
			}
			
			NSArray *chapterTracks = [track associatedTracksOfType:AVTrackAssociationTypeChapterList];
			if(chapterTracks.count == 0)
			{
				continue;
			}
			
			for(AVAssetTrack *chapterTrack in chapterTracks)
			{
				AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
				AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:chapterTrack outputSettings:nil];
				[reader addOutput:output];
				
				[reader startReading];
				
				while(1)
				{
					CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
					if(sampleBuffer == NULL)
					{
						break;
					}
					
					CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
					if(dataBuffer == NULL)
					{
						CFRelease(sampleBuffer);
						continue;
					}
					
					CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
					
					CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);

					CMSampleTimingInfo sampleTiming;
					CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &sampleTiming);
					
					CMTime start = sampleTiming.presentationTimeStamp;
					CMTime duration = sampleTiming.duration;

					if(mediaType == kCMMediaType_Text)
					{
						NSString *text = CFBridgingRelease(CMPSampleBufferCopyText(NULL, sampleBuffer));
						if(text == nil)
						{
							text = @"";
						}
						
						NSDictionary *chapterInfo = @{
							StartKey: @(start.value / start.timescale),
							DurationKey: @(duration.value / duration.timescale),
							TitleKey: text,
						};
						
						[chapterInfos addObject:chapterInfo];
					}
					else if(mediaType == kCMMediaType_Video)
					{
						CGImageRef image = CMPSampleBufferCopyImage(NULL, sampleBuffer);

						// TODO: handle image
						//NSLog(@"%ld x %ld", CGImageGetWidth(image), CGImageGetHeight(image));
						
						if(image != NULL)
						{
							CFRelease(image);
						}
					}
					
					CFRelease(sampleBuffer);
				}
			}
			
			NSMutableString *output = [NSMutableString string];
			
			for(NSDictionary *chapterInfo in chapterInfos)
			{
				NSTimeInterval start = ((NSNumber *)chapterInfo[StartKey]).doubleValue;
				NSTimeInterval duration = ((NSNumber *)chapterInfo[DurationKey]).doubleValue;
				NSTimeInterval end = start + duration;
				
				NSString *title = chapterInfo[TitleKey];
				
				[output appendFormat:@"%@ --> %@ %@\n", NSStringWithTimeInterval(start), NSStringWithTimeInterval(end), title];
			}
			
			[NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
			[output writeToURL:outputURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
		}
	}
	return 0;
}
