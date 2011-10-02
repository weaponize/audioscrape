
//
//  main.m
//  audioscrape
//
//  Created by NPC on 9/26/11.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <getopt.h>
#include <stdio.h>

int process_args(int, const char **, int *, int*, int*);
void export_audio(NSURL *, NSURL *);

// Limit the number of total exporters
#define DEFAULT_EXPORTERS 32
int exportcounter = 0, exportfailed = 0; 

// global count of exporters
int exporter_limit = DEFAULT_EXPORTERS;

int main (int argc, const char ** argv)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    // options vars
    int batch = 0 ;
    int overwrite = 0;
    
    // iterating over argv
    int index;
    
    // create an options struct/class?
    if(process_args(argc, argv, &batch, &overwrite, &exporter_limit) != 0) {
        exit(-1);
    }
    
    // memory allocation handled by the pool (I guess?)
    NSURL *sourceURL;
    NSURL *destURL;
    
    // non batch mode assumes args are src and dest
    // and actually, I guess you can't spec e.g. -o except in batch mode
    // my getopt support sucks
    if(! batch) {

        // need else/error message
        if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithCString: argv[1] encoding:NSUTF8StringEncoding]]) { 
            sourceURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithCString: argv[1] encoding:NSUTF8StringEncoding]];

            // this overwrite clause doesn't take effect
            // need else/error message here
            if(!overwrite || ! [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithCString: argv[2] encoding:NSUTF8StringEncoding]]) { 
                destURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithCString: argv[2] encoding:NSUTF8StringEncoding]];
                export_audio(sourceURL, destURL);
            }
            
        }
        
    } else {
        
        for(index=1 ; index < argc ; index++) { 
            
            // error checking
            sourceURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithCString: argv[index] encoding:NSUTF8StringEncoding]];
            if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithCString: argv[index] encoding:NSUTF8StringEncoding]]) { 
    
                destURL = [[sourceURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"m4a"];
                export_audio(sourceURL, destURL);
                
            }
            
        }
    }
    
    /*
     block while the audio is exporting since this is a console app
     */
    while(exportcounter > 0 && ! exportfailed)
        ;

    [pool drain];
    return 0;
}

int process_args(int argc, const char ** argv, int *batch, int *overwrite, int *exporters)
{
    extern char *optarg;
    /*
        extern int optind;
        extern int optopt;
        extern int opterr;
        extern int optreset;
    */
    
    int ch; 
    
    static struct option longopts[] = {
        // limit the number of exporters
        { "exporters", required_argument,       NULL,           'e' },
        // consider args a long list of videos to rip, else src dst
        // batch mode creates a new file with m4a ext, copying basename of the src
        { "batch",      no_argument,            NULL,           'b' },
        // overwrite destination files - currently only works in batch mode
        { "overwrite",  no_argument,            NULL,           'o' },
        // quite mode
        { NULL,         0,                      NULL,           0 }
    };

    while ((ch = getopt_long(argc, argv, "be:o", longopts, NULL)) != -1) {
        switch(ch) { 
                case 'b':
                    *batch = 1;
                    break;
                case 'e':
                    *exporters=atoi(optarg) - 1; // account for zero-indexing
                    break;
                case 'o':
                    *overwrite = 1;
                    break;
        }
     }
    
    return(0);
}        

void export_audio(NSURL *sourceURL, NSURL *destURL)
{
    // decorator indicates this var from our context will be returned/modified
    // in the block in the call to exportAsynchronouslyWithCompletionHandler:
    __block NSString *sourcePath = [NSString stringWithString:[sourceURL absoluteString]];
    
    AVURLAsset *source = [[AVURLAsset alloc] initWithURL:sourceURL options:nil];
    
    AVAssetExportSession *export = nil;
    AVAssetTrack *audioTrack = nil;

    // find the audio track
    for(AVAssetTrack *track in source.tracks) {
        if([track.mediaType compare:AVMediaTypeAudio] == NSOrderedSame) { 
            audioTrack = track;
        }
    }
    
    // audio exporter
    export = [AVAssetExportSession exportSessionWithAsset:source presetName:AVAssetExportPresetAppleM4A];
    export.outputURL = destURL;
    
    /* only export the audio track */
    if(audioTrack) {
        printf("Exporting audio track from %s\n", [[sourceURL lastPathComponent] cStringUsingEncoding: NSASCIIStringEncoding]);

        exportcounter++; // treating this like a retain count
        
         // delaying adding an export block, limits the number of threads created by AVFoundation
        while(exportcounter > exporter_limit )
            ;
        
        [export exportAsynchronouslyWithCompletionHandler:^(void){
            exportcounter--;
            printf("Completed %s.\n",[sourcePath cStringUsingEncoding:NSASCIIStringEncoding]);
        }];
        
    } else { 
        printf("Unable to export audio for %s\n", [sourcePath cStringUsingEncoding:NSASCIIStringEncoding]);
        exportfailed = 1;
    }
}