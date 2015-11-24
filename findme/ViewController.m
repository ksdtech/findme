//
//  ViewController.m
//  findme
//
//  Created by Peter Zingg (Local) on 11/23/15.
//  Copyright (c) 2015 Kentfield School District. All rights reserved.
//

#import "ViewController.h"

NSString *studentFileName = @"students.txt";
// NSString *userDomainSuffix = @"@kentfieldschools.org";

@interface ViewController ()

// UI elements
@property IBOutlet NSSearchField *searchField;
@property IBOutlet NSTextField *copiedLabel;

// Properties
@property (nonatomic) NSMutableArray *allKeywords;
@property NSMutableDictionary *userDictionary;
@property BOOL completePosting;
@property BOOL commandHandling;

// Loaded from config file
@property NSString *userDomainSuffix;
@property NSString *updateURL;
@property NSString *updateApiKey;
@property NSString *updateAuthHeader;

@end

@implementation ViewController

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // Do any additional setup after loading the user interface.
    
    [self loadConfiguration];
    
    // Read list of user names from data file in bundle.
    [self buildUserDictionary];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.

    // Handle search field actions
    [_searchField setDelegate:self];

    // Prepare the "flash" label for fade-out animation.
    _copiedLabel.hidden = YES;
    _copiedLabel.alphaValue = 1.0f;
    
    // Use layer-based animation. Doesn't seem to work for me.
    // _copiedLabel.wantsLayer = YES;
    // _copiedLabel.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


// -------------------------------------------------------------------------------
//  bundleResourceDirectory
//
// -------------------------------------------------------------------------------
- (NSString *)bundleResourceDirectory {
    return [[NSBundle mainBundle] resourcePath];
}

// -------------------------------------------------------------------------------
//  applicationSupportDirectory
//
//  10.6 compatible version (10.7 and above use NSURLs).
// -------------------------------------------------------------------------------
- (NSString *)applicationSupportDirectory {

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dirPath = nil;
    
    // Find the application support directory in the home directory.
    NSArray *appSupportDir = [fm URLsForDirectory:NSApplicationSupportDirectory
                                        inDomains:NSUserDomainMask];
    if ([appSupportDir count] > 0) {
        
        // Append the bundle ID to the URL for the
        // Application Support directory
        NSString *appSupportPath = [[appSupportDir objectAtIndex:0] path];
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        dirPath = [appSupportPath stringByAppendingPathComponent:bundleID];
        
        // If the directory does not exist, this method creates it.
        // This method is only available in OS X v10.7 and iOS 5.0 or later.
        NSError *theError = nil;
        if (![fm createDirectoryAtPath:dirPath withIntermediateDirectories:YES
                           attributes:nil error:&theError]) {
            NSLog(@"Could create application support directory: %@", theError);
            // TODO: Handle the error.
            return nil;
        }
    }
    
    return dirPath;
}

// -------------------------------------------------------------------------------
//  readUserDictioary
//
//  Read a tab-delimited text file and build a dictionary. The first column
//  of the tab-delimited text file must contain the user names
//  (without the "userDomainSuffix").
// -------------------------------------------------------------------------------
- (BOOL)readUserDictionary:(NSString *)filePath {
    NSString *text = [NSString stringWithContentsOfFile:filePath encoding: NSUTF8StringEncoding error:nil];
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    
    // Read file and split on newlines
    _userDictionary = [[NSMutableDictionary alloc] init];
    for (NSString *line in lines) {
        NSArray *fields = [line componentsSeparatedByString:@"\t"];
        
        // First field on each line is the username (without domain)
        if ([fields count] >= 1) {
            NSString *username = [fields[0] stringByAppendingString:_userDomainSuffix];
            [_userDictionary setObject:fields forKey:username];
        }
    }
    return [_userDictionary count] > 0;
}

// -------------------------------------------------------------------------------
//  loadConfiguration
//
//  Read plist information.  The AppConfig.plist file must have three config
//  items:
//    userDomainSuffix:  like "@example.com" (append this to user names)
//    updateURL:         "http://example.com/users"
//    updateApiKey:      "apikey" (sent to updateURL in Authorization header)
// -------------------------------------------------------------------------------
- (void)loadConfiguration {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"AppConfig" ofType:@"plist"];
    NSDictionary *config = [[NSDictionary alloc] initWithContentsOfFile:path];
   
    _userDomainSuffix = (NSString *)[config objectForKey:@"userDomainSuffix"];
    _updateURL = (NSString *)[config objectForKey:@"updateURL"];
    _updateApiKey = (NSString *)[config objectForKey:@"updateApiKey"];
    _updateAuthHeader = [[NSString alloc] initWithFormat:@"Bearer %@", _updateApiKey];
}

// -------------------------------------------------------------------------------
//  buildUserDictioary
//
//  Read a list of usernames from a text file in either the app support directory,
//  or the app bundle.  Copies the file to the app support directory if it
//  doesn't exist.
// -------------------------------------------------------------------------------
- (void)buildUserDictionary {

    NSString *appFilePath = [[self applicationSupportDirectory]
                             stringByAppendingPathComponent:studentFileName];
    if (![self readUserDictionary:appFilePath]) {
        NSString *resFilePath = [[self bundleResourceDirectory]
                             stringByAppendingPathComponent:studentFileName];
        if ([self readUserDictionary:resFilePath]) {
            NSError* theError = nil;
            NSFileManager *fm = [NSFileManager defaultManager];
            if (![fm copyItemAtPath:resFilePath toPath:appFilePath error:&theError]) {
                NSLog(@"Could not copy dictionary file: %@", theError);
                // TODO: Handle the error.
            }
        } else {
            NSLog(@"Could not read dictionary file");
            // TODO: Handle the error.
        }
    }
}

- (BOOL)saveUserList:(NSData *)contents {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *appFilePath = [[self applicationSupportDirectory]
                             stringByAppendingPathComponent:studentFileName];
    NSString *tempFilePath = [[self applicationSupportDirectory]
                             stringByAppendingPathComponent:@"tempfile.txt"];
    // Start clean
    [fm removeItemAtPath:tempFilePath error:nil];
    
    if (![fm createFileAtPath:tempFilePath contents:contents attributes:nil]) {
        NSLog(@"Failed to save temp file!");
        return false;
    }
    
    [fm removeItemAtPath:appFilePath error:nil];
    if (![fm moveItemAtPath:tempFilePath toPath:appFilePath error:nil]) {
        // Try to finish clean
        [fm removeItemAtPath:tempFilePath error:nil];
        NSLog(@"Failed to move temp file!");
        return false;
    }
    return true;
}

// -------------------------------------------------------------------------------
//  allKeywords
//
//  Return a sorted copy of the keywords for the search field to use
// -------------------------------------------------------------------------------
- (NSArray *)allKeywords {

    if (_allKeywords == nil) {
        _allKeywords = [[self.userDictionary allKeys] mutableCopy];
        [_allKeywords sortUsingComparator:^(NSString *a, NSString *b) {
            return [a localizedStandardCompare:b];
        }];
    }
    return _allKeywords;
}

// -------------------------------------------------------------------------------
//  showCopiedLabel
//
//  Animate the opacity of the label so it shows then fades out after 4 seconds.
// -------------------------------------------------------------------------------
- (void)showCopiedLabel {

    _copiedLabel.hidden = NO;
    _copiedLabel.alphaValue = 1.0f;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 4.0f;
        _copiedLabel.animator.alphaValue = 0.0f;
    } completionHandler:^ {
        _copiedLabel.hidden = YES;
        _copiedLabel.alphaValue = 1.0f;
    }];
}


// -------------------------------------------------------------------------------
//  Actions

// -------------------------------------------------------------------------------
//  updateUserList
//
//  Fetch and save an updated list of usernames.
// -------------------------------------------------------------------------------
- (IBAction)updateUserList:(id)sender {
    
    NSURL *url = [[NSURL alloc]initWithString:_updateURL];
    
    //type your URL u can use initWithFormat for placeholders
    NSURLSession *session = [NSURLSession sharedSession];  //use NSURLSession class
    NSURLRequest *request = [[NSURLRequest alloc]initWithURL:url];
    
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    [mutableRequest addValue:_updateAuthHeader forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionDataTask *task = [session
                            dataTaskWithRequest:mutableRequest
                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                if (error) {
                                    NSLog(@"Request error: %@", error);
                                } else {
                                    if ([self saveUserList:data]) {
                                        NSLog(@"User dictionary updated!");
                                    } else {
                                        NSLog(@"Failed to save user list");
                                    }
                                    [self buildUserDictionary];
                                }
    }];
    
    // Download the list
    [task resume];
}

// -------------------------------------------------------------------------------
//  NSTextView delegate method

// -------------------------------------------------------------------------------
//  control:textView:completions:forPartialWordRange:indexOfSelectedItem:
//
//  Use this method to override NSFieldEditor's default matches (which is a much bigger
//  list of keywords).  By not implementing this method, you will then get back
//  NSSearchField's default feature.
// -------------------------------------------------------------------------------
- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {

    NSMutableArray *matches = [[NSMutableArray alloc] init];
    
    // Start matching on 4 characters, like "20aa"
    if (charRange.length >= 4) {
        NSString *partialString  = [textView.string substringWithRange:charRange];
        
        NSUInteger rangeOptions = NSAnchoredSearch | NSCaseInsensitiveSearch;
        
        [self.allKeywords enumerateObjectsUsingBlock:^(NSString *keyword, NSUInteger idx, BOOL *stop) {
            
            NSRange searchRange = NSMakeRange(0, keyword.length);
            NSRange foundRange = [keyword rangeOfString:partialString options:rangeOptions range:searchRange];
            
            BOOL partialStringIsMatchForKeyword = YES;
            if (foundRange.location == NSNotFound)
            {
                partialStringIsMatchForKeyword = NO;
            }
            
            if (partialStringIsMatchForKeyword)
            {
                [matches addObject:keyword];
            }
        }];
        
        [matches sortUsingComparator:^(NSString *a, NSString *b) {
            return [a localizedStandardCompare:b];
        }];
    }
    
    return matches;
}

// -------------------------------------------------------------------------------
//  NSSearchField delegate methods

// -------------------------------------------------------------------------------
//  controlTextDidEndEditiong:notification:
//
//  The text in NSSearchField is done, copy it to the pasteboard and alert
//  user with an animated label.
// -------------------------------------------------------------------------------
- (void)controlTextDidEndEditing:(NSNotification *)notification {

    NSTextView *textView = notification.userInfo[@"NSFieldEditor"];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];

    NSString *text = [[textView textStorage] string];
    NSArray *textArray = [NSArray arrayWithObject:text];
    [pb writeObjects:textArray];
    
    [self showCopiedLabel];
}

// -------------------------------------------------------------------------------
//  controlTextDidChange:notification:
//
//  The text in NSSearchField has changed, try to attempt type completion.
// -------------------------------------------------------------------------------
- (void)controlTextDidChange:(NSNotification *)notification {

    NSTextView *textView = notification.userInfo[@"NSFieldEditor"];
    // NSLog(@"notification: %@", notification.name);
    
    // prevent calling "complete" too often
    if (!self.completePosting && !self.commandHandling)
    {
        _completePosting = YES;
        [textView complete:nil];
        _completePosting = NO;
    }
}

// -------------------------------------------------------------------------------
//  control:textView:commandSelector
//
//  Handle all commend selectors that we can handle here
// -------------------------------------------------------------------------------
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView
    doCommandBySelector:(SEL)commandSelector {
    
    
    BOOL didPerformRequestedSelectorOnTextView = NO;
    
    if ([textView respondsToSelector:commandSelector])
    {
        _commandHandling = YES;
        
        NSMethodSignature *textViewSelectorMethodSignature = [textView methodSignatureForSelector:commandSelector];
        
        NSInvocation *textViewInvocationForSelector = [NSInvocation invocationWithMethodSignature:textViewSelectorMethodSignature];
        
        [textViewInvocationForSelector setTarget:textView];
        [textViewInvocationForSelector setSelector:commandSelector];
        [textViewInvocationForSelector invoke];
        _commandHandling = NO;
        
        didPerformRequestedSelectorOnTextView = YES;
    }
    
    return didPerformRequestedSelectorOnTextView;
}

@end
