//
//  IJLocalContext.m
//  Injective
//
//  Created by Vladimir Pouzanov on 1/30/12.
//
//  Copyright (c) 2012 Vladimir Pouzanov.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to 
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.

#import "IJLocalContext.h"
#import "IJClassRegistration.h"
#import <objc/runtime.h>

static char IJLocalContextToken;

@interface IJContext ()

- (void)bindRegisteredPropertiesWithRegistration:(IJClassRegistration *)reg toInstance:(id)instance;

@end


@implementation IJLocalContext

+ (IJLocalContext *)localContextOfObject:(id)object
{
	IJLocalContext *localContext = objc_getAssociatedObject(object, &IJLocalContextToken);
	if(localContext == nil) {
		[NSException raise:NSInternalInconsistencyException format:@"No local context defined in object %@", object];
	}
	return localContext;
}

+ (id)instantinateClass:(Class)klass localToObject:(id)object withProperties:(NSDictionary *)props
{
	return [[self localContextOfObject:object] instantinateClass:klass withProperties:props];
}

#pragma mark -
- (id)createClassInstanceFromRegistration:(IJClassRegistration *)reg withProperties:(NSDictionary *)props
{
	// XXX: this could be an overriden method, but we want to have local context bound as early as possible for
	//      possible use in bound property setters
	id instance;
	if(reg.block) {
		instance = reg.block(props);
	} else {
		instance = [[[reg.klass alloc] init] autorelease];
	}
	
	objc_setAssociatedObject(instance, &IJLocalContextToken, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self bindRegisteredPropertiesWithRegistration:reg toInstance:instance];
	[instance setValuesForKeysWithDictionary:props];
	
	return instance;
}

@end

#pragma mark - InjectiveLocal
@implementation NSObject (InjectiveLocal)

// TODO: should this fallback to [IJContext defaultContext] if +[IJLocalContext localContextOfObject:object] fails?

+ (id)injectiveInstantiateFromLocalObjectWithProperties:(id)object, ...
{
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	NSString *key;
	va_list args;
	va_start(args, object);
	
	id value = va_arg(args, id);
	
	while(value) {
		key = va_arg(args, id);
		[d setObject:value forKey:key];
		value = va_arg(args, id);
	};
	va_end(args);
	
	return [IJLocalContext instantinateClass:self localToObject:object withProperties:d];
}

+ (id)injectiveInstantiateFromLocalObject:(id)object withPropertiesDictionary:(NSDictionary *)properties
{
	return [IJLocalContext instantinateClass:self localToObject:object withProperties:properties];
}

+ (id)injectiveInstantiateFromLocalObject:(id)object
{
	return [IJLocalContext instantinateClass:self localToObject:object withProperties:nil];
}

@end