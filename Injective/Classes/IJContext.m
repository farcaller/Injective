//
//  IJContext.m
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

#import "IJContext.h"
#import "IJClassRegistration.h"
#import <objc/runtime.h>

static IJContext *DefaultContext = nil;


@interface IJContext ()

- (id)createClassInstanceFromRegistration:(IJClassRegistration *)reg withProperties:(NSDictionary *)props;
- (NSDictionary *)createPropertiesMapForClass:(Class)klass;
- (void)registerClass:(Class)klass forClassName:(NSString *)klassName instantinationMode:(IJContextInstantinationMode)mode instantinationBlock:(IJContextInstantinationBlock)block;
- (NSSet *)gatherPropertiesForKlass:(Class)klass;
- (void)bindRegisteredPropertiesWithRegistration:(IJClassRegistration *)reg toInstance:(id)instance;

@end


@implementation IJContext
{
	NSMutableDictionary *_registeredClasses;
	NSMutableDictionary *_registeredClassesSingletonInstances;
	dispatch_queue_t _queue;
}

+ (IJContext *)defaultContext
{
	if(DefaultContext == nil)
		[NSException raise:NSInternalInconsistencyException format:@"Requested default Injective context, when none is available"];
	return DefaultContext;
}

+ (void)setDefaultContext:(IJContext *)context
{
	if(DefaultContext != context) {
		[DefaultContext release];
		DefaultContext = [context retain];
	}
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

- (void)registerClass:(Class)klass instantinationMode:(IJContextInstantinationMode)mode
{
	[self registerClass:klass instantinationMode:mode instantinationBlock:nil];
}

- (void)registerClass:(Class)klass instantinationMode:(IJContextInstantinationMode)mode instantinationBlock:(IJContextInstantinationBlock)block
{
	NSString *klassName = NSStringFromClass(klass);
	[self registerClass:klass forClassName:klassName instantinationMode:mode instantinationBlock:block];
}

- (void)registerClass:(Class)klass forClassName:(NSString *)klassName instantinationMode:(IJContextInstantinationMode)mode instantinationBlock:(IJContextInstantinationBlock)block
{
	dispatch_async(_queue, ^{
		if([_registeredClasses objectForKey:klassName]) {
			[NSException raise:NSInternalInconsistencyException format:@"Tired to register class %@ that is already registered in the injective context: %@", klass, self];
		}
		[_registeredClasses setObject:[IJClassRegistration registrationWithClass:klass instantinationMode:mode instantinationBlock:block] forKey:klassName];
	});
}

- (void)registerSingletonInstance:(id)obj forClass:(Class)klass
{
	NSString *klassName = NSStringFromClass(klass);
	@synchronized(klass) {
		[self
		 registerClass:klass
		 forClassName:klassName
		 instantinationMode:IJContextInstantinationModeSingleton
		 instantinationBlock:nil];
		
		id instance = [_registeredClassesSingletonInstances objectForKey:klassName];
		if(instance) {
			[NSException raise:NSInternalInconsistencyException format:@"Class %@ has the instance %@ registered, cannot register %@", klassName, instance, obj];
		}
		[_registeredClassesSingletonInstances setObject:obj forKey:klassName];
	}
}

- (id)instantinateClass:(Class)klass withProperties:(NSDictionary *)props
{
	__block IJClassRegistration *reg = nil;
	__block id instance = nil;
	NSString *klassName = NSStringFromClass(klass);
	
	dispatch_sync(_queue, ^{
		reg = [_registeredClasses objectForKey:klassName];
	});
	
	if(reg) {
		if(reg.mode == IJContextInstantinationModeFactory) {
			instance = [self createClassInstanceFromRegistration:reg withProperties:props];
		} else {
			@synchronized(klass) {
				instance = [_registeredClassesSingletonInstances objectForKey:klassName];
				if(!instance) {
					instance = [self createClassInstanceFromRegistration:reg withProperties:nil];
					[_registeredClassesSingletonInstances setObject:instance forKey:klassName];
				}
			};
		}
	}
	return instance;
}

#pragma mark -
- (void)bindRegisteredPropertiesWithRegistration:(IJClassRegistration *)reg toInstance:(id)instance
{
	Class klass = reg.klass;
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
			} else {
				[propKlass class];
			}
			id propInstance = [self instantinateClass:propKlass withProperties:nil];
			if(!propInstance) {
				[NSException raise:NSInternalInconsistencyException format:@"Injector %@ doesn't know how to instantinate %@", self, propKlassName];
			}
			[instance setValue:propInstance forKey:propName];
		}];
		
#if 0
#error FIXME we mapped all registeredProperties, need to check only for props, requires additional validation?
		NSMutableSet *registeredPropsSet = [NSMutableSet setWithArray:[registeredProperties allKeys]];
		[registeredPropsSet addObjectsFromArray:[props allKeys]];
		NSMutableSet *requiredPropsSet = [NSMutableSet setWithSet:[klass injective_requredProperties]];
		[requiredPropsSet minusSet:registeredPropsSet];
		BOOL hasMissingProperties = [requiredPropsSet count] > 0;
		if(hasMissingProperties) {
			[NSException raise:NSInternalInconsistencyException format:@"Class %@ instantinated with %@, but a set of %@ was requested.", NSStringFromClass(klass),
			 [klass injective_requredProperties], registeredPropsSet];
		}
#endif
	}
}

- (id)createClassInstanceFromRegistration:(IJClassRegistration *)reg withProperties:(NSDictionary *)props
{
	id instance;
	if(reg.block) {
		instance = reg.block(props);
	} else {
		instance = [[[reg.klass alloc] init] autorelease];
	}
	
	[self bindRegisteredPropertiesWithRegistration:reg toInstance:instance];
	[instance setValuesForKeysWithDictionary:props];
	
	return instance;
}

- (NSDictionary *)createPropertiesMapForClass:(Class)klass
{
	NSMutableDictionary *propsDict = [NSMutableDictionary dictionary];
	NSSet *requiredProperties = [self gatherPropertiesForKlass:klass];
	
	for(NSString *propName in requiredProperties) {
		objc_property_t property = class_getProperty(klass, [propName cStringUsingEncoding:NSASCIIStringEncoding]);
		const char *cPropAttrib = property_getAttributes(property);
		// the attributes string is always at least 2 chars long, and the 2nd char must be @ for us to proceed
		if(cPropAttrib[1] != '@') {
			[NSException raise:NSInternalInconsistencyException format:@"Cannot map required property '%@' of class %@ as it does not "
			 @"point to object. Attributes: '%s'", propName, NSStringFromClass(klass), cPropAttrib];
		}
		// the attributes string must be at least 5 chars long: T@"<one char here>"
		if(strlen(cPropAttrib) < 5) {
			[NSException raise:NSInternalInconsistencyException format:@"Cannot map required property '%@' of class %@ as it does not "
			 @"contain enough chars to parse class name. Attributes: '%s'", propName, NSStringFromClass(klass), cPropAttrib];
		}
		cPropAttrib = cPropAttrib + 3;
		// we don't support protocols yet
		if(cPropAttrib[0] == '<') {
			[NSException raise:NSInternalInconsistencyException format:@"Cannot map required property '%@' of class %@ as it "
			 @"maps to a Protocol, and we don't support them yet. Attributes: '%s'", propName, NSStringFromClass(klass), cPropAttrib];
		}
		char *cMappedKlassName = strdup(cPropAttrib);
		char *cMappedKlassNameEnd = strchr(cMappedKlassName, '"');
		if(cMappedKlassNameEnd == NULL) {
			[NSException raise:NSInternalInconsistencyException format:@"Cannot map required property '%@' of class %@ as it does not "
			 @"contain the ending '\"'. Attributes: '%s'", propName, NSStringFromClass(klass), cPropAttrib];
		}
		*cMappedKlassNameEnd = '\0';
		NSString *mappedKlassName = [NSString stringWithCString:cMappedKlassName encoding:NSASCIIStringEncoding];
		free(cMappedKlassName);
		
		[propsDict setObject:mappedKlassName forKey:propName];
	}
	
	return [[propsDict copy] autorelease];
}

- (NSSet *)gatherPropertiesForKlass:(Class)klass
{
	NSMutableSet *ms = [NSMutableSet setWithSet:[klass injective_requredProperties]];
	Class superKlass = class_getSuperclass(klass);
	if([superKlass respondsToSelector:@selector(injective_requredProperties)]) {
		[ms unionSet:[self gatherPropertiesForKlass:superKlass]];
	}
	return ms;
}

@end

#pragma mark - Injective
@implementation NSObject (Injective)

+ (id)injectiveInstantiateWithProperties:(NSDictionary *)properties
{
	return [[IJContext defaultContext] instantinateClass:self withProperties:properties];
}

+ (id)injectiveInstantiate
{
	return [[IJContext defaultContext] instantinateClass:self withProperties:nil];
}

@end
