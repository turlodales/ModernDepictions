#import <UIKit/UIKit.h>
#import <Headers/Headers.h>
#import "Tweak.h"

%group ModernDepictionsCore
%hook Database

- (void)reloadDataWithInvocation:(NSInvocation *)invocation {
	%orig;
	NSMutableArray *sourceList = MSHookIvar<id>(self, "sourceList_");
	if (!sourceList) return;
	for (Source *source in sourceList) {
		if (!source.didAttemptBefore) {
			source.didAttemptBefore = true;
			NSLog(@"Root URI: %@", source.rooturi);
			NSURL *paymentEndpointSource = [[NSURL URLWithString:source.rooturi] URLByAppendingPathComponent:@"payment_endpoint"];
			NSLog(@"Payment endpoint source: %@", paymentEndpointSource);
			if (paymentEndpointSource) {
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					NSData *rawData = [NSData dataWithContentsOfURL:paymentEndpointSource];
					NSString *stringURL = [[NSString alloc] initWithData:rawData encoding:NSUTF8StringEncoding];
					NSLog(@"Payment endpoint: %@", stringURL);
					if (!(source.paymentEndpoint = [NSURL URLWithString:stringURL])) return;
					NSURL *infoURL = [source.paymentEndpoint URLByAppendingPathComponent:@"info"];
					NSLog(@"Info URL: %@", infoURL);
					if (!infoURL || !(rawData = [NSData dataWithContentsOfURL:infoURL])) return;
					source.paymentProviderInfo = [NSJSONSerialization JSONObjectWithData:rawData options:0 error:nil];
					NSLog(@"Payment provider info: %@", source.paymentProviderInfo);
				});
			}
		}
	}
}

%new
- (NSOperationQueue *)iconDownloadQueue {
	NSOperationQueue *queue = objc_getAssociatedObject(self, _cmd);
	if (!queue) {
		queue = [NSOperationQueue new];
		objc_setAssociatedObject(self, _cmd, queue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return queue;
}

%end

%hook Cydia

- (void)applicationWillResignActive:(id)application {
	NSLog(@"Application will resign active");
	%orig;
}

%end

%hook Source
%property (nonatomic, assign) bool didAttemptBefore;
%property (nonatomic, strong) NSDictionary *paymentProviderInfo;
%property (nonatomic, strong) NSURL *paymentEndpoint;
%property (nonatomic, strong) NSOperationQueue *operationQueue;
%end

%hook Package
%property (nonatomic, strong) NSString *sileoDepiction;
%property (nonatomic, strong) NSDictionary *paymentInformation;

%new
- (void)retrievePaymentInformationWithCompletion:(void(^)(Package *, NSError *))completionHandler {
	if (!self.source.paymentEndpoint) return;
	if (self.paymentInformation) {
		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(self, nil);
		});
		return;
	}
	if (!self.source.operationQueue) self.source.operationQueue = [NSOperationQueue new];
	NSURL *url;
	if (!(url = [self.source.paymentEndpoint URLByAppendingPathComponent:[NSString stringWithFormat:@"package/%@/info", self.id]])) return;
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	request.HTTPMethod = @"POST";
	[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	Package *package = self;
	[NSURLConnection sendAsynchronousRequest:request
		queue:self.source.operationQueue
		completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
			NSError *finalError = error;
			if (data && !finalError) {
				NSLog(@"Data: %@", [[NSString alloc] initWithBytes:data.bytes length:65 encoding:NSUTF8StringEncoding]);
				package.paymentInformation = [NSJSONSerialization JSONObjectWithData:data options:0 error:&finalError];
				NSLog(@"Payment info for %@: %@", package, package.paymentInformation ?: finalError);
			}
			completionHandler(self, finalError);
		}
	];
}

- (void)parse {
	%orig;
	id value = [self getField:@"sileodepiction"];
	self.sileoDepiction = [value isKindOfClass:[NSNull class]] ? nil : value;
}

// A failed attempt to free the parsed package, not used anywhere
%new
- (void)freeParsedPackage {
	self.sileoDepiction = nil;
	void **parsedPackage = &MSHookIvar<void *>(self, "parsed_");
	if (*parsedPackage) free(*parsedPackage);
	*parsedPackage = nil;
}

%end

%hook UILabel

- (void)setTextAlignment:(NSTextAlignment)alignment {
	NSTextAlignment finalAlignment = alignment;
	if (alignment == NSTextAlignmentNaturalInverse) {
		finalAlignment = (
			UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ?
			NSTextAlignmentLeft :
			NSTextAlignmentRight
		);
	}
	%orig(finalAlignment);
}

%end
%end

void ModernDepictionsInitializeCore(void) {
	%init(ModernDepictionsCore);
	ModernDepictionsInitializeSharedFunctions();
}