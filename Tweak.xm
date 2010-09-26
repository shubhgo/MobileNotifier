/*

MobileNotifier, by Peter Hajas

Copyright 2010 Peter Hajas, Peter Hajas Software

This code is licensed under the GPL. The full text of which is available in the file "LICENSE"
which should have been included with this package. If not, please see:

http://www.gnu.org/licenses/gpl.txt


iOS Notifications. Done right. Like 2010 right.

This is an RCOS project for the Spring 2010 semester. The website for RCOS is at rcos.cs.rpi.edu/

Thanks to:

Mukkai Krishnamoorthy - cs.rpi.edu/~moorthy
Sean O' Sullivan

Dustin Howett - howett.net
Ryan Petrich - github.com/rpetrich
chpwn - chpwn.com
KennyTM - github.com/kennytm
Jay Freeman - saurik.com

for all your help and mega-useful tools.

To build this, use "make" in the directory. This project utilizes Theos as its makefile system and Logos as its hooking preprocessor.

You will need Theos installed:
http://github.com/DHowett/theos
With the decompiled headers in /theos/include/:
http://github.com/kennytm/iphone-private-frameworks

I hope you enjoy! Questions and comments to peterhajas (at) gmail (dot) com

And, as always, have fun!

*/

#import <SpringBoard/SpringBoard.h>
#import <ChatKit/ChatKit.h>

#import <libactivator/libactivator.h>

//Some class initialization:
//View initialization for a very very (VERY) basic view

@interface alertDisplayController : UIViewController
{
	UILabel *alertText;	
}

@property (readwrite, retain) UILabel *alertText;

- (void)config;
//- (void)dismiss;

@end

//Our alertController object, which will handle all event processing

@interface alertController : NSObject <LAListener>
{
    NSMutableDictionary *eventDict;

}

- (void)newAlert:(NSString *)title ofType:(NSString *)alertType;

//libactivator methods:
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event;

@property (readwrite, retain) NSMutableDictionary *eventDict;

@end


//Alert Controller:
alertController *controller;

//Our UIWindow:

static UIWindow *alertWindow;

//Mail class declaration. This was dumped with class dump z (by kennytm)
//and was generated with MobileMail.app

@protocol AFCVisibleMailboxFetch <NSObject>
-(void)setShouldCompact:(BOOL)compact;
-(void)setMessageCount:(unsigned)count;
-(void)setRemoteIDToPreserve:(id)preserve;
-(void)setDisplayErrors:(BOOL)errors;
-(id)mailbox;
@end

@interface AutoFetchRequestPrivate{
}
-(void)run;
-(BOOL)gotNewMessages;
-(int)messageCount;

@end

//Hook into Springboard init method to initialize our window

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)application
{
    
    %orig;
    
    NSLog(@"Initializing alertWindow and controller");

    controller = [[alertController alloc] init];

    alertWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	alertWindow.windowLevel = 99998; //Don't mess around with WindowPlaner if the user has it installed :)
	alertWindow.userInteractionEnabled = NO;
	alertWindow.hidden = NO;

    //libactivator initialization:

    [[LAActivator sharedInstance] registerListener:controller forName:@"com.peterhajassoftware.mobilenotifier"];
    
}

%end;


@implementation alertController

@synthesize eventDict;

- (void)newAlert:(NSString *)title ofType:(NSString *)alertType
{
    alertDisplayController *alert = [[alertDisplayController alloc] init];
    [alert config];
	
	alert.alertText.text = title;
		
	[alertWindow addSubview:alert.view];

    [[alert view] performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:5.0];
}


//libactivator methods:
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
   NSLog(@"We received an LAEvent!");
   
   //For now, when we receive the event, we'll dismiss all current notifications
/*
   for(unsigned int i = 0; i < [[alertWindow subviews] count]; i++)
   {
       [[[alertWindow subviews] objectAtIndex:i] removeFromSuperview];
   }
*/

   [event setHandled:YES];
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
   NSLog(@"We received an LAEvent abort!");
    
}
@end

@implementation alertDisplayController

@synthesize alertText; 

- (void)config
{
	alertText = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, [[UIScreen mainScreen] bounds].size.width , 40)];
    alertText.backgroundColor = [UIColor clearColor];
}
/*
- (void)dismiss
{
    [self.view removeFromSuperview];
}
*/
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{	
	NSLog(@"Alert touched!");
}

- (void)viewDidLoad
{	
	self.view = [[UIView alloc] initWithFrame:CGRectMake(0, ([[alertWindow subviews] count] * 60), [[UIScreen mainScreen] bounds].size.width, 60)];
    self.view.backgroundColor = [UIColor orangeColor];	

	[self.view addSubview:alertText];
	[alertText release];
}

@end

//Hook the display method for receiving an SMS message
%hook SBSMSAlertItem

-(void)willActivate
{	
	//Display our alert!	
	if([self alertImageData] == nil) //If we didn't get an MMS
	{
        [controller newAlert:[NSString stringWithFormat:@"New SMS from %@: %@", [self name], [self messageText]] ofType:@"SMS"];
    }
    else
    {
        [controller newAlert:[NSString stringWithFormat:@"New MMS from %@", [self name]] ofType:@"MMS"];
    }

    %orig;
}

-(void)reply
{
	NSLog(@"Reply called!");
	
	//Equivalent to pressing "View" with a long message
	%orig;
}

%end

//Hook SBAlertItem for doing push notifications

%hook SBAlertItem

-(BOOL)willActivate
{
    //Output lots of information on the alert item
    
    BOOL result = %orig;

    NSLog(@"SBAlertItem will activate!");
    
    NSLog(@"LockLabel: %@", [self lockLabel]);

    NSLog(@"AwayItem: %@", [self awayItem]);
 
    return result;
}

%end

//Hook SBAwayView for showing our lockscreen view.
//SBAwayView is released each time the phone is unlocked, and a new instance created when the phone is locked (thanks Limneos!)

%hook SBAwayView

-(void)viewDidLoad
{
    alertDisplayController *alert = [[alertDisplayController alloc] init];
    [alert config];
	
	alert.alertText.text = @"Test!";
 
    [self addSubview:alert.view];
    [self bringSubviewToFront:alert.view];

    %orig;
}

- (void)viewWillDisappear:(BOOL)animated
{
     
    %orig;
}

%end;

//Hook AutoFetchRequestPrivate for getting new mail

%hook AutoFetchRequestPrivate

-(void)run //This works! This is an appropriate way for us to display a new mail notification to the user
{
	%orig;
    %log;
	if([self gotNewMessages])
	{
		NSLog(@"Attempted fetch with %d new mail!", [self messageCount]); //Message count corresponds to maximum storage in an inbox (ie 200), not to the count of messages received...
    
        //Display our alert! 
        [controller newAlert:@"New mail!" ofType:@"Mail"];
	}
	else
	{
		NSLog(@"Attempted fetch with no new mail.");
	}
}

%end

//Information about Logos for future reference:

/* How to Hook with Logos
Hooks are written with syntax similar to that of an Objective-C @implementation.
You don't need to #include <substrate.h>, it will be done automatically, as will
the generation of a class list and an automatic constructor.

%hook ClassName

// Hooking a class method
+ (id)sharedInstance {
	return %orig;
}

// Hooking an instance method with an argument.
- (void)messageName:(int)argument {
	%log; // Write a message about this call, including its class, name and arguments, to the system log.

	%orig; // Call through to the original function with its original arguments.
	%orig(nil); // Call through to the original function with a custom argument.

	// If you use %orig(), you MUST supply all arguments (except for self and _cmd, the automatically generated ones.)
}

// Hooking an instance method with no arguments.
- (id)noArguments {
	%log;
	id awesome = %orig;
	[awesome doSomethingElse];

	return awesome;
}

// Always make sure you clean up after yourself; Not doing so could have grave conseqeuences!
%end
*/

	//How to hook ivars!
	//MSHookIvar<ObjectType *>(self, "OBJECTNAME");
