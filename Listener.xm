#import <libactivator/libactivator.h>
#import <UIKit/UIKit.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <time.h>

#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netdb.h>

char DEFAULT_IP[] = "192.168.0.255";
char DEFAULT_MAC[] = "00:00:00:00:00:00";
int DEFAULT_PORT = 9; // default port numbers: 7, 9

@interface NSUserDefaults (Tweak_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end
 
static NSString *nsDomainString = @"com.uroboro.activator.listener.wol";

static int sendMagicPacket(char *mac_addr, char *ip_addr, int port);
static unsigned char atohex(unsigned char a);
static unsigned char getMacByteAtIndex(const char *addr, int i);
static void makePacketFromMAC(char *mac_addr, unsigned char packet[102]);
static int sendPacket(char *ip_addr, int port_num, unsigned char packet[102]);

static int sendMagicPacket(char *mac_addr, char *ip_addr, int port) {
	// Load the Magic Packet pattern into the output buffer
	unsigned char packet[102];
	makePacketFromMAC(mac_addr, packet);
	return sendPacket(ip_addr, port, packet);
}

static unsigned char atohex(unsigned char a) {
	unsigned char r = 0xff;
	if (a >= '0' && a <= '9') {
		r = a - '0';
	}
	if (a >= 'A' && a <= 'F') {
		r = 10 + a - 'A';
	}
	if (a >= 'a' && a <= 'f') {
		r = 10 + a - 'a';
	}
	return r;
}

static unsigned char getMacByteAtIndex(const char *addr, int i) {
	if (!addr) {
		fprintf(stderr, "no mac address\n");
		exit(-1);
	}

	int len = strlen(addr);
	if (len < (2 * 6 + 5)) {
		fprintf(stderr, "bad mac address\n");
		exit(-1);
	}
	unsigned char high = atohex(addr[3*i]);
	unsigned char low = atohex(addr[3*i+1]);
	return 16 * high + low;
}

static void makePacketFromMAC(char *mac_addr, unsigned char packet[102]) {
	unsigned char mac_byte[6];

	for (int i = 0; i < 6; i++) {
		mac_byte[i] = getMacByteAtIndex(mac_addr, i);
		packet[i] = 0xff;
	}
	for (int i = 1; i < 17; i++) {
		memcpy(&(packet[6*i]), mac_byte, 6 * sizeof(unsigned char));
	}
}

static int sendPacket(char *ip_addr, int port_num, unsigned char packet[102]) {
	int csd; // Client socket descriptor
	struct sockaddr_in target_addr; // Target Internet address
	int r; // Return code

	// Create a client socket
	csd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (csd < 0) {
		fprintf(stderr, "#! socket() failed\n");
		return 1;
	}

	//configure socket
	int optval = 1;
	r = setsockopt(csd, SOL_SOCKET, SO_BROADCAST, &optval, sizeof(optval));
	if (r < 0) {
		fprintf(stderr, "#! sockopt() failed");
		return 1;
	}
	// Fill-in target address information
	target_addr.sin_family = AF_INET;
	target_addr.sin_addr.s_addr = inet_addr(ip_addr);
	target_addr.sin_port = htons(port_num);

	//send packet
	r = sendto(csd, packet, 102, 0, (struct sockaddr *)&target_addr, sizeof(target_addr));
	if (r < 0) {
		fprintf(stderr, "#! sendto() failed\n");
		return 1;
	}
#if 0
	// Wait for 0.5 seconds for the packet to be sent
	struct timespec tspec = (struct timespec){0, 500000000};
	r = nanosleep(&tspec, NULL);
	if (r < 0) {
		fprintf(stderr, "#! nanosleep() failed\n");
		return 1;
	}
#endif
	// Close client socket and clean-up
	r = close(csd);
	if (r < 0) {
		fprintf(stderr, "#! close() failed\n");
		return 1;
	}
	return 0;
}

@interface MagicPacketAction : NSObject <LAListener> {
}
@end

@implementation MagicPacketAction

+ (id)sharedInstance {
	static id sharedInstance = nil;
	static dispatch_once_t token = 0;
	dispatch_once(&token, ^{
		sharedInstance = [self new];
	});
	return sharedInstance;
}

+ (void)load {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Register our listener
	if (LASharedActivator.isRunningInsideSpringBoard) {
		[[LAActivator sharedInstance] registerListener:[self sharedInstance] forName:nsDomainString];
	}
	[pool release];
}

- (void)dealloc {
	// Since this object lives for the lifetime of SpringBoard, this will never be called
	// It's here for the sake of completeness
	if (LASharedActivator.runningInsideSpringBoard) {
		[LASharedActivator unregisterListenerWithName:nsDomainString];
	}
	[super dealloc];
}

- (BOOL)wakeUp {
	NSString *m = (NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"macAddress" inDomain:nsDomainString];
	char *mac_addr = (m)? strdup([m UTF8String]):DEFAULT_MAC;

	NSString *a = (NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ipAddress" inDomain:nsDomainString];
	char *ip_addr = (a)? strdup([a UTF8String]):DEFAULT_IP;

	NSNumber *n = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"port" inDomain:nsDomainString];
	int port = (n)? [n intValue]:DEFAULT_PORT;

#if 0
#define SHOWALERT(t, m) [[UIAlertView alloc] initWithTitle:(t) message:(m) delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil]
s = [NSString stringWithFormat:@"%s; %s:%d", mac_addr, ip_addr, port];
UIAlertView *a = SHOWALERT(nil, s); [a show]; [a release];
#endif
	int r = sendMagicPacket(mac_addr, ip_addr, port);

	return (!r)?YES:NO;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
	// Called when we recieve event
	if (![self wakeUp]) {
		[event setHandled:YES];
	}
}

// Metadata
// Group name
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
	return @"Network";
}
// Listener name
- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
	return @"Wake-On-LAN";
}
// Listener description
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
	return @"Sends a magic packet to target device.";
}
/* Group assignment filtering
- (NSArray *)activator:(LAActivator *)activator requiresExclusiveAssignmentGroupsForListenerName:(NSString *)listenerName {
	return [NSArray array];
}
*/
@end

