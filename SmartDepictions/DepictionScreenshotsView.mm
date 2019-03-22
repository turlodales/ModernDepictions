#import "DepictionScreenshotsView.h"
#import "SmartDepictionDelegate.h"

@implementation DepictionScreenshotsView

- (CGFloat)height {
	return _height;
}

- (void)setItemCornerRadius:(CGFloat)newRadius {
	if (_imageViews) for (UIImageView *view in _imageViews) {
		view.layer.cornerRadius = newRadius;
		view.layer.masksToBounds = YES;
	}
	_itemCornerRadius = newRadius;
}

- (void)layoutSubviews {
	[self resetConstraints];
	[super layoutSubviews];
}

- (instancetype)initWithDepictionDelegate:(SmartDepictionDelegate *)delegate reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithDepictionDelegate:delegate reuseIdentifier:reuseIdentifier];
	_screenshotsView = [[UIScrollView alloc] init];
	_screenshotsView.translatesAutoresizingMaskIntoConstraints = NO;
	[self.contentView addSubview:_screenshotsView];
	NSDictionary *views = @{ @"sssView" : _screenshotsView };
	[self.contentView addConstraints:[NSLayoutConstraint
		constraintsWithVisualFormat:@"H:|[sssView]|"
		options:0
		metrics:nil
		views:views
	]];
	[self.contentView addConstraints:[NSLayoutConstraint
		constraintsWithVisualFormat:@"V:|[sssView]|"
		options:0
		metrics:nil
		views:views
	]];
	_height = 32.0;
	return self;
}

- (void)setItemSize:(NSString *)itemSize {
	itemSizeStruct = CGSizeFromString(itemSize);
	_height = itemSizeStruct.height + 32;
	_itemSize = itemSize;
	_screenshotsView.contentSize = CGSizeMake(16 * (_imageViews.count + 1) + itemSizeStruct.width * _imageViews.count, 0);
}

- (void)resetConstraints {
	if (currentConstraints) {
		[_screenshotsView removeConstraints:currentConstraints];
	}
	currentConstraints = [[NSMutableArray alloc] init];
	for (int i = 0; i < 
	_imageViews.count; i++) {
		UIImageView *imageView = _imageViews[i];
		NSDictionary *views = @{
			@"curr" : imageView,
			@"prev" : (i ? _imageViews[i-1] : NSNull.null)
		};
		[currentConstraints addObjectsFromArray:[NSLayoutConstraint
			constraintsWithVisualFormat:[NSString stringWithFormat:@"H:%@-16-[curr(==%f)]", i ? @"[prev]" : @"|", itemSizeStruct.width]
			options:0
			metrics:nil
			views:views
		]];
		[currentConstraints addObjectsFromArray:[NSLayoutConstraint
			constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|-16-[curr(==%f)]", itemSizeStruct.height]
			options:0
			metrics:nil
			views:views
		]];
	}
	[_screenshotsView addConstraints:currentConstraints];
}

- (void)setScreenshots:(NSArray<NSDictionary<NSString *, id> *> *)newScreenshots {
	if (!newScreenshots) {
		_height = 32.0;
		return;
	}
	if (_imageViews) for (UIImageView *view in _imageViews) {
		[view removeFromSuperview];
	}
	_imageViews = [[NSMutableArray alloc] init];
	for (int i = 0; i < newScreenshots.count; i++) {
		UIImageView *newImage = [[UIImageView alloc] init];
		newImage.translatesAutoresizingMaskIntoConstraints = NO;
		newImage.contentMode = UIViewContentModeScaleToFill;
		NSDictionary<NSString *, id> *propertyDict = newScreenshots[i];
		for (NSString *key in propertyDict) {
			id value = propertyDict[key];
			if ([key isEqualToString:@"url"]) {
				NSURL *SSURL = [NSURL URLWithString:value];
				if (SSURL) {
					[self.depictionDelegate downloadDataFromURL:SSURL completion:^(NSData *data, NSError *error) {
						if (!error && data) {
							dispatch_sync(dispatch_get_main_queue(), ^{
								newImage.image = [UIImage imageWithData:data];
								[newImage setNeedsDisplay];
							});
						}
					}];
				}
			}
			else if ([newImage respondsToSelector:NSSelectorFromString(key)]) {
				[newImage setValue:value forKey:key];
			}
		}
		[_imageViews addObject:newImage];
		[_screenshotsView addSubview:newImage];
	}
	_screenshots = newScreenshots;
	self.itemCornerRadius = _itemCornerRadius;
}

@end