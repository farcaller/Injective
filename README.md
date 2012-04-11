# Injective framework

The purpose of this framework is to provide a simple dependency injection framework for iOS/Mac applications.

Injective provides facilities for automatic connection of class instances by resolving properties dependencies. Additionally, Injective verifies that all required data is passed to instance for it to function correctly.

Injective supports factory-like object creation and singleton object creation.

## Setup

### Git version

#### (For git users only) Add Injective as a submodule

If you're using git as your project's scm, add Injective as a submodue:

```bash
git submodule add https://github.com/farcaller/Injective
```

#### (For all others) Download Injective source

Download Injective source code from https://github.com/farcaller/Injective/zipball/master and unzip it to your project root directory.

#### Add Injective project to your workspace

Add Injective project to Project navigator (this will create a workspace if you don't have one). To do this, drag *Injective.xcodeproj* from the Finder to the very bottom of your project navigator panel.

If you don't have a workspace yet, you will be asked: "Do you want to save this project in a new workspace?". Save it.

#### Add public headers to search path

Open your project's build settings and add *Injective/Headers* to **Header Search paths**. If you followed step 0, it's as simple as adding `$(PROJECT_DIR)/Injective/Injective/Headers`

#### (optional) Add Injective as a global header

Add the following line to your project's precompiled header (pch file): `#import "InjectiveContext.h"`:

```objc
#import "IJContext.h"
```

This will allow you to use Injective without requiring you to #import it everywhere.

### Precompiled version

There is a target to build Injective.framework, however at the current point there is no stable release. Precompiled builds would be added later, for now it's suggested that you use a recent git checkout.

## Usage

### Configuring a default context

All the helpers require a global context to be set up. You can specify one with:

```objc
IJContext *defaultContext = [[IJContext alloc] init];
[IJContext setDefaultContext:defaultContext];
```

Where to do that? As soon as you can. You can use `-application:didFinishLaunchingWithOptions:` of the application delegate in the iOS projects.

### Registering a singleton class

To register a class you need to use `+registerClass:instantinationMode:` method of *IJContext* class:

```objc
IJContext *myContext = [[IJContext alloc] init];
[myContext registerClass:[MyAPIController class]
      instantinationMode:IJContextInstantinationModeSingleton];
```

Then, you can get an instance of the class with the following code:

```objc
MyAPIController *api = [myContext instantinateClass:[MyAPIController class]
                                     withProperties:nil];
```

*Note:* You can also use the `injective_register_singleton` macro in your class implementation:

```objc
@implementation MyAPIController

injective_register_singleton(MyAPIController)

...

@end
```

### Registering a common class

You can register a common class using **IJContextInstantinationModeFactory**. This way, Injective will create a new instance of the class each time you instantiate it:

```objc
IJContext *myContext = [[IJContext alloc] init];
[myContext
 registerClass:[MyDetailViewController class]
 instantinationMode:IJContextInstantinationModeFactory];
```

In this mode, you can pass additional properties that would be mapped by KVC:

```objectivec
NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                   items, @"items",
                   nil];
MyDetailViewController *viewController = [myContext
                                          instantinateClass:[MyDetailViewController class] 
                                          withProperties:d];
```

*Note:* You can also use the `injective_register` macro in your class implementation:

```objc
@implementation MyDetailViewController

injective_register(MyDetailViewController)

...

@end
```

### Specifying dependencies

To make Injective actually useful, you need to specify a set of properties, that your class requires. You can do this via `+injective_requredProperties` method:

```objc
@interface MyDetailViewController : UIViewController

@property (nonatomic, strong) MyAPIController *apiController;

@end


@implementation MyDetailViewController

injective_register(MyDetailViewController)

+ (NSSet *)injective_requredProperties
{
    return [NSSet setWithObject:@"apiController"];
}

@end
```

There's another handy macro for you -- `injective_requires`, that does the same job:

```objc
@implementation MyDetailViewController

injective_register(MyDetailViewController)
injective_requires(@"apiController")

@end
```

### Instantiation helpers

You can instantiate any object in default context using the following class method of NSObject's category:

```objc
MyDetailViewController *viewController = [MyDetailViewController injectiveInstantiate];
```

## Licensing

Injective is a MIT-licensed framework. See details in *LICENSE* file.

## Credits

[![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=farcaller&url=https://github.com/farcaller/Injective&title=Injective&language=&tags=github&category=software)

[![endorse](http://api.coderwall.com/farcaller/endorsecount.png)](http://coderwall.com/farcaller)

Injective framework is originally written by Vladimir "Farcaller" Pouzanov <<farcaller@gmail.com>>.

A few ideas are based on Objection framework (https://github.com/atomicobject/objection).

## Bugs / Suggestions

I'm always open to communication. Please file a ticket via github issues system at https://github.com/farcaller/Injective/issues/new.
