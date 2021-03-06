#import "Tweak.h"
#import <Foundation/Foundation.h>

#define PLIST_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/org.h6nry.ncforward.prefs.plist"]

NSDictionary *preferences;
BOOL encryptedEnabled;
NSString *password;
NSString *ipp;
int needupdate = 0;

//Load preference from iOS Preference plist
void loadSettings2(void) {
  if (preferences) {
    preferences = nil;
  }
  preferences = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH];
  ipp = [preferences objectForKey:@"ip"] ? [preferences objectForKey:@"ip"] : @"255.255.255.255";
  encryptedEnabled = [preferences objectForKey:@"encrypt"] ? [[preferences objectForKey:@"encrypt"] boolValue] : FALSE;
  password = [preferences objectForKey:@"secretKey"] ? [preferences objectForKey:@"secretKey"] : @"khapota";
  //NSLog(@"ncforward - %@, %d, %@", ipp, encryptedEnabled, password);
}


%group main
//Some weird callback method...
static void socketCallback(CFSocketRef cfSocket, CFSocketCallBackType type, CFDataRef address, const void *data, void *userInfo) {
    NSLog(@"NCForward:WTF? socketCallback was called??");
}

//Some convenient stuff to make creating messages easier
@interface NSString (NCForwardCategory)
-(NSString *) addToNFString:(NSString *)string;
@end

@implementation NSString (NCForwardCategory)
-(NSString *) addToNFString:(NSString *)string {
	if (string == NULL) {
		self = [[self stringByAppendingString:@"%!"] stringByAppendingString:@"NULL"];
	} else {
		self = [[self stringByAppendingString:@"%!"] stringByAppendingString:string];
	}
	return self;
}
@end

//Encrypt data via RNCryptor library
@interface NSData (NCForwardCategory)
+(NSData *) doEncrypt: (NSData *)data withPassword: (NSString *)aPassword;
@end

//Encrypt data with RNCryptor
@implementation NSData (NCForwardCategory)
+(NSData *) doEncrypt: (NSData *) originData withPassword: (NSString *) aPassword {
  //NSString *aPassword = @"khanhpro";
  //NSData *data = [@"Data" dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  NSData *encryptedData = [RNEncryptor encryptData:originData
                                      withSettings:kRNCryptorAES256Settings
                                          password:aPassword
                                             error:&error];
  return encryptedData;
  //NSLog(@"%@", encryptedData);
}
@end

//The class for sending (and recieving) NCForward messages
@class NFSending;
static NFSending *_sharedInstance = nil;

@interface NFSending : NSObject <NSStreamDelegate>
+(id) sharedInstance;
-(BOOL) sendMessage:(NSString *)message;
@end

@implementation NFSending
+(id) sharedInstance {
	@synchronized(self) {
		if (!_sharedInstance) {
			_sharedInstance = [[self alloc] init];
		}
		return _sharedInstance;
	}
}

-(BOOL) sendMessage:(NSString *)message {
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
	dispatch_async(queue, ^{ //Dispatch asynchronous to not block everything
		CFSocketContext socketContext = {0, self, NULL, NULL, NULL};

		CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault, 0, SOCK_DGRAM, IPPROTO_UDP, kCFSocketNoCallBack, (CFSocketCallBack)socketCallback, &socketContext );

    const char* messagec = nil;
    if (needupdate) {
      loadSettings2();
    }
		if (socket) {
			//NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/org.h6nry.ncforward.prefs.plist"];
			//NSLog(@"-----prefs:%@         %s",prefs, (const char*)[[prefs objectForKey:@"ip"] cStringUsingEncoding:NSASCIIStringEncoding]);
			int yes = 1;
			int setSockResult = setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_BROADCAST, (void *)&yes, sizeof(yes));

			if(setSockResult < 0) NSLog(@"NCForward: Could not setsockopt for broadcast");
			//NSString* ipp = [prefs objectForKey:@"ip"];
      /*
			if (prefs == NULL || ipp == NULL || [ipp isEqualToString:@""]) {
				//NSLog(@"NCForward: No IP specified. Using 255.255.255.255");
				ipp = @"255.255.255.255";
			}
      */

			struct sockaddr_in addr; //create  structure of type sockaddr_in named addr
			memset(&addr, 0, sizeof(addr));
			addr.sin_len = sizeof(addr);
			addr.sin_family = AF_INET;
			addr.sin_port = htons(3156); //port
			inet_aton([ipp cStringUsingEncoding:NSASCIIStringEncoding], &addr.sin_addr); //ip adress vllt auch 255.255.255.255 ??? 192.168.0.255

			CFSocketConnectToAddress(socket, CFDataCreate(kCFAllocatorDefault, (const UInt8*)&addr, sizeof(addr)), 0.5);

      if (encryptedEnabled) {
        //NSLog(@"NCForward: %@", message);
        NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
        //NSString *password = @"khanhpro";
        NSData *encryptedData = [NSData doEncrypt: messageData withPassword: password];
        NSString *base64EncryptedData = [encryptedData base64EncodedStringWithOptions:0];
        //NSLog(@"NCForward: %@", encryptedData);
        //NSLog(@"NCForward: %@", base64EncryptedData);
        //const char* messagec = (const char*)[base64EncryptedData bytes];
        messagec = (const char*)[base64EncryptedData dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES].bytes;
      } else {
        messagec = (const char*)[message dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES].bytes;
      }
			CFDataRef Data = CFDataCreate(kCFAllocatorDefault, (const UInt8*)messagec, strlen(messagec));
			CFSocketError sendError = CFSocketSendData(socket, NULL, Data, 0.5);
			if (sendError == kCFSocketSuccess) {
				//NSLog(@"NCForward: Sent a notification.");
			} else {
				NSLog(@"NCForward: Some error occured while sending: %li", sendError);
			}
			CFRelease(Data);
			CFSocketInvalidate(socket);
			CFRelease(socket);
		} else {
				NSLog(@"NCForward: Creating socket failed!");
		}
	});
	return NO;
}
@end

%hook SBBulletinBannerController
-(void)observer:(id)observer addBulletin:(BBBulletin *)bulletin forFeed:(unsigned)feed playLightsAndSirens:(BOOL)sirens withReply:(id)reply {
        NSString *BulletinMessageToSend = @"NCFV1_PV1"; //NCF: magic. V1: ncforward version number. P:magic. V1: protocol version number.
        BulletinMessageToSend = [BulletinMessageToSend addToNFString:bulletin.sectionDisplayName];
        BulletinMessageToSend = [BulletinMessageToSend addToNFString:bulletin.topic];
        BulletinMessageToSend = [BulletinMessageToSend addToNFString:bulletin.sectionID];
        BulletinMessageToSend = [BulletinMessageToSend addToNFString:bulletin.content.title];
        BulletinMessageToSend = [BulletinMessageToSend addToNFString:bulletin.content.subtitle];
        BulletinMessageToSend = [BulletinMessageToSend addToNFString:bulletin.content.message];
        BulletinMessageToSend = [BulletinMessageToSend addToNFString:[bulletin.date description]];

        [[NFSending sharedInstance] sendMessage:BulletinMessageToSend];

        %orig;
}
%end

/*%hook SBVoiceControlController
-(BOOL)handleHomeButtonHeld {
	NSString *BulletinMessageToSend = @"NCFV1_PV1"; //NCF: magic. V1: ncforward version number. P:magic. V1: protocol version number.
	BulletinMessageToSend = [BulletinMessageToSend addToNFString:@"Test"];
	BulletinMessageToSend = [BulletinMessageToSend addToNFString:@"Test"];
	BulletinMessageToSend = [BulletinMessageToSend addToNFString:@"Test"];
	BulletinMessageToSend = [BulletinMessageToSend addToNFString:@"Test"];
	BulletinMessageToSend = [BulletinMessageToSend addToNFString:@"Test"];
	BulletinMessageToSend = [BulletinMessageToSend addToNFString:@"Test"];
	BulletinMessageToSend = [BulletinMessageToSend addToNFString:@"Test"];
	[[NFSending sharedInstance] sendMessage:BulletinMessageToSend];
	return nil;
}
%end*/ //test and debug stuff!

%end

void loadSettings(void) {
  needupdate = 1;
/*
  int64_t delayInSeconds = 2;
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    if (preferences) {
      preferences = nil;
    }
    preferences = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH];
    ipp = [preferences objectForKey:@"ip"] ? [preferences objectForKey:@"ip"] : @"255.255.255.255";
    encryptedEnabled = [preferences objectForKey:@"encrypt"] ? [[preferences objectForKey:@"encrypt"] boolValue] : FALSE;
    password = [preferences objectForKey:@"secretKey"] ? [preferences objectForKey:@"secretKey"] : @"khapota";
    NSLog(@"ncforward - %@, %d, %@", ipp, encryptedEnabled, password);
  });
*/
}

%ctor {
  //Add Notification listener for Preference and NotificationCallback
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                  NULL,
                                  (CFNotificationCallback)&loadSettings,
                                  CFSTR("org.h6nry.ncforward.prefs.settingschanged"),
                                  NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  /*
  CFNotificationCenterAddObserver(
    CFNotificationCenterGetDarwinNotifyCenter(), NULL,
    (CFNotificationCallback)&loadSettings,
    CFSTR("org.h6nry.ncforward.prefs.settingschanged"),
    NULL, CFNotificationSuspensionBehaviorCoalesce);
  */
  //Load current setting when reload this tweak
  loadSettings2();
	@autoreleasepool {
		%init(main);
	}
}

