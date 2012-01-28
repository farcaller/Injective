//
//  IJClassRegistration.m
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

#import "IJClassRegistration.h"

@interface IJClassRegistration ()

- (IJClassRegistration *)initWithClass:(Class)klass instantinationMode:(IJContextInstantinationMode)mode instantinationBlock:(IJContextInstantinationBlock)block;

@end


@implementation IJClassRegistration

@synthesize klass = _klass, mode = _mode, registeredProperties = _registeredProperties, block = _block;

- (IJClassRegistration *)initWithClass:(Class)klass instantinationMode:(IJContextInstantinationMode)mode instantinationBlock:(IJContextInstantinationBlock)block
{
	if( (self = [super init]) ) {
		_klass = klass;
		_mode = mode;
		_block = [block copy];
	}
	return self;
}

- (void)dealloc
{
	[_block release];
	[_registeredProperties release];
	[super dealloc];
}

+ (IJClassRegistration *)registrationWithClass:(Class)klass instantinationMode:(IJContextInstantinationMode)mode instantinationBlock:(IJContextInstantinationBlock)block
{
	return [[[self alloc] initWithClass:klass instantinationMode:mode instantinationBlock:block] autorelease];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<InjectiveClassRegistration %@ %s%s>", _klass, _mode == 0 ? "F" : "S", _block == nil ? "" : " with block"];
}

@end
