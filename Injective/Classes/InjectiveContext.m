//
//  InjectiveContext.m
//  Injective
//
//  Created by Vladimir Pouzanov on 1/21/12.
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

#import "InjectiveContext.h"
#import "InjectiveClassRegistration.h"
#import <objc/runtime.h>

@interface InjectiveContext ()

- (id)createClassInstanceFromRegistration:(InjectiveClassRegistration *)reg withProperties:(NSDictionary *)props;
- (NSDictionary *)createPropertiesMapForClass:(Class)klass;

@end

@implementation InjectiveContext
{
	NSMutableDictionary *_registeredClasses;
	NSMutableDictionary *_registeredClassesSingletonInstances;
	dispatch_queue_t _queue;
}

+ (InjectiveContext *)defaultContext
{
	static dispatch_once_t onceToken;
	static InjectiveContext *context;
	dispatch_once(&onceToken, ^{
		context = [[self alloc] init];
	});
	return context;
}

- (id)init
{
    if( (self = [super init]) ) {
		_registeredClasses = [[NSMutableDictionary alloc] init];
		_registeredClassesSingletonInstances = [[NSMutableDictionary alloc] init];
		NSString *queueName = [NSString stringWithFormat:@"net.farcaller.injective.%p.main", self];
		_queue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
	}
    return self;
}

- (void)dealloc
{
	[_registeredClasses release];
	[_registeredClassesSingletonInstances release];
	dispatch_release(_queue);
	[super dealloc];
}

- (void)registerClass:(Class)klass instantinationMode:(InjectiveContextInstantinationMode)mode
{
	NSString *klassName = NSStringFromClass(klass);
	dispatch_async(_queue, ^{
		if([_registeredClasses objectForKey:klassName]) {
			[NSException raise:NSInternalInconsistencyException format:@"Tired to register class %@ that is already registered in the injective context: %@", klass, self];
		}
		[_registeredClasses setObject:[InjectiveClassRegistration registrationWithClass:klass instantinationMode:mode] forKey:klassName];
	});
}

- (id)instantinateClass:(Class)klass withProperties:(NSDictionary *)props
{
	__block InjectiveClassRegistration *reg = nil;
	__block id instance = nil;
	NSString *klassName = NSStringFromClass(klass);
	
	dispatch_sync(_queue, ^{
		reg = [_registeredClasses objectForKey:klassName];
	});
	
	if(reg) {
		if(reg.mode == InjectiveContextInstantinationModeFactory) {
			instance = [self createClassInstanceFromRegistration:reg withProperties:props];
		} else {
			instance = [_registeredClassesSingletonInstances objectForKey:klassName];
			dispatch_sync(dispatch_get_main_queue(), ^{ 
				if(!instance) {
					instance = [self createClassInstanceFromRegistration:reg withProperties:nil];
					[_registeredClassesSingletonInstances setObject:instance forKey:klassName];
				}
			});
		}
	}
	return instance;
}

#pragma mark -
- (id)createClassInstanceFromRegistration:(InjectiveClassRegistration *)reg withProperties:(NSDictionary *)props
{
	Class klass = reg.klass;
	id instance = [[[klass alloc] init] autorelease];
	
	// check if the class requires pre-binding setup
	if([klass respondsToSelector:@selector(injective_requredProperties)]) {
		__block NSDictionary *registeredProperties;
		
		// check if there is known property-class map and generate one if required
		dispatch_sync(_queue, ^{
			registeredProperties = reg.registeredProperties;
			if(!registeredProperties) {
				reg.registeredProperties = [self createPropertiesMapForClass:klass];
				registeredProperties = reg.registeredProperties;
			}
		});
		
		// iterate over the properties and set up connections via KVC
		// TODO: this can cause deadlocks, that we must fix
		// TODO: check for assign/weak properties? Look for [C]opy, [&]retain or W[eak]
		[registeredProperties enumerateKeysAndObjectsUsingBlock:^(NSString *propName, NSString *propKlassName, BOOL *stop) {
			Class propKlass = objc_getClass([propKlassName cStringUsingEncoding:NSASCIIStringEncoding]);
			if(!propKlass) {
				[NSException raise:NSInternalInconsistencyException format:@"Class %@ is not registered in the runtime, but is required for %@.%@", propKlassName,
				 NSStringFromClass(klass), propName];
			}
			id propInstance = [self instantinateClass:propKlass withProperties:nil];
			if(!propInstance) {
				[NSException raise:NSInternalInconsistencyException format:@"Injector %@ doesn't know how to instantinate %@", self, propKlassName];
			}
			[instance setValue:propInstance forKey:propName];
		}];
		
		// check if we have all the required properties on hand
		NSMutableSet *registeredPropsSet = [NSMutableSet setWithArray:[registeredProperties allKeys]];
		[registeredPropsSet addObjectsFromArray:[props allKeys]];
		BOOL hasMissingProperties = [[klass injective_requredProperties] isSubsetOfSet:registeredPropsSet];
		if(hasMissingProperties) {
			[NSException raise:NSInternalInconsistencyException format:@"Class %@ instantinated with %@, but a set of %@ was requested.", NSStringFromClass(klass),
			 [klass injective_requredProperties], registeredPropsSet];
		}
	}
	
	[instance setValuesForKeysWithDictionary:props];
	return instance;
}

- (NSDictionary *)createPropertiesMapForClass:(Class)klass
{
	NSMutableDictionary *propsDict = [NSMutableDictionary dictionary];
	NSSet *requiredProperties = [klass injective_requredProperties];
	unsigned int outCount, i;
	objc_property_t *properties = class_copyPropertyList(klass, &outCount);
	for (i = 0; i < outCount; i++) {
		objc_property_t property = properties[i];
		
		const char *cPropName = property_getName(property);
		NSString *propName = [NSString stringWithCString:cPropName encoding:NSASCIIStringEncoding];
		// check if we really need this property
		if([requiredProperties containsObject:propName]) {
			const char *cPropAttrib = property_getAttributes(property);
			// the attributes string is always at least 2 chars long, and the 2nd char must be @ for us to proceed
			if(cPropAttrib[1] != '@') {
				[NSException raise:NSInternalInconsistencyException format:@"Cannot map required property '%s' of class %@ as it does not "
				 @"point to object. Attributes: '%s'", cPropName, NSStringFromClass(klass), cPropAttrib];
			}
			// the attributes string must be at least 5 chars long: T@"<one char here>"
			if(strlen(cPropAttrib) < 5) {
				[NSException raise:NSInternalInconsistencyException format:@"Cannot map required property '%s' of class %@ as it does not "
				 @"contain enough chars to parse class name. Attributes: '%s'", cPropName, NSStringFromClass(klass), cPropAttrib];
			}
			cPropAttrib = cPropAttrib + 3;
			// we don't support protocols yet
			if(cPropAttrib[0] == '<') {
				[NSException raise:NSInternalInconsistencyException format:@"Cannot map required property '%s' of class %@ as it "
				 @"maps to a Protocol, and we don't support them yet. Attributes: '%s'", cPropName, NSStringFromClass(klass), cPropAttrib];
			}
			char *cMappedKlassName = strdup(cPropAttrib);
			char *cMappedKlassNameEnd = strchr(cMappedKlassName, '"');
			if(cMappedKlassNameEnd == NULL) {
				[NSException raise:NSInternalInconsistencyException format:@"Cannot map required property '%s' of class %@ as it does not "
				 @"contain the ending '\"'. Attributes: '%s'", cPropName, NSStringFromClass(klass), cPropAttrib];
			}
			cMappedKlassNameEnd = '\0';
			NSString *mappedKlassName = [NSString stringWithCString:cMappedKlassName encoding:NSASCIIStringEncoding];
			free(cMappedKlassName);
			
			[propsDict setObject:mappedKlassName forKey:propName];
		}
	}
	return [[propsDict copy] autorelease];
}

@end
