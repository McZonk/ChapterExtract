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
		
		for(int i = 1; i < argc; ++i)
		{ @autoreleasepool {
			const char *assetFile = argv[i];
			NSURL *URL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s", assetFile]];
		
			NSData *data = [NSData dataWithContentsOfURL:URL];
			NSMutableData *outData = [NSMutableData dataWithCapacity:data.length];
			
			const void *buffer = data.bytes;
			size_t length = data.length;
		
			size_t atomStart = 0;
			size_t offset = 0;
			CMPAtom *atom = NULL;
			while(CMPAtomIterate(buffer, length, &offset, &atom))
			{
				size_t size = OSSwapBigToHostInt32(atom->size);
				FourCharCode type = OSSwapBigToHostInt32(atom->type);

				NSString *typeString = CFBridgingRelease(CMPAtomTypeCopyStringRef(NULL, type));
			
				NSData *atomData = nil;
				if(type == 'uuid')
				{
					NSLog(@"%@ %ld %ld SHORTEND", typeString, atomStart, size);
					atomData = [data subdataWithRange:NSMakeRange(atomStart, size - 163)];
				}
				else
				{
					NSLog(@"%@ %ld %ld", typeString, atomStart, size);
					atomData = [data subdataWithRange:NSMakeRange(atomStart, size)];
				}
				
				[outData appendData:atomData];
				
#if 0
				NSString *typeString = CFBridgingRelease(CMPAtomTypeCopyStringRef(NULL, type));
				NSURL *atomURL = [URL URLByAppendingPathExtension:typeString];
			
				[atomData writeToURL:atomURL atomically:YES];
			
				NSLog(@"%@ %ld %ld", typeString, atomStart, size);
				
#endif
				atomStart = offset;
			}
			
			NSString *ext = URL.pathExtension;
			NSURL *outURL = [[URL.URLByDeletingPathExtension URLByAppendingPathExtension:@"fix"] URLByAppendingPathExtension:ext];
			
			[outData writeToURL:outURL atomically:YES];
		}}
		
		
		
	}
	return 0;
}
