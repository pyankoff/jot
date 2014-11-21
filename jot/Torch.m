//
//  Torch.m
//

#import "Torch.h"

@implementation Torch

static NSString *appPath;

/* Helper method for Lua script to be able to access app resources */
static int lua_getAppPath(lua_State *L) {
    lua_pushstring(L, [appPath UTF8String]);
    return 1; // number of results returnd to Lua
}

- (void)require:(NSString *)file
{
    NSString *modulePath = [appPath stringByAppendingString:file];
    NSLog(@"loading module: %@\n", modulePath);
    
    int ret = luaL_dofile(L, [modulePath UTF8String]);
    if (ret != 0) {
        NSLog(@"error: %s", lua_tostring(L, -1));
    }
}

- (void)initialize
{
    appPath = [[NSBundle mainBundle] resourcePath];
    
    // initialize Lua stack
    lua_executable_dir("./lua");
    L = lua_open();
    luaL_openlibs(L);
    
    // Update LUA_PATH in order for 'require' to work within lua scripts
    NSString* luaPackagePath = [NSString stringWithFormat:@"package.path='/?.lua;%@/framework/lua/?.lua;'.. package.path", appPath];
    if (luaL_dostring(L, [luaPackagePath UTF8String]) != 0) {
        NSLog(@"error (updating LUA_PATH): %s", lua_tostring(L, -1));
    }
    
    luaopen_libtorch(L);
    [self require:@"/framework/lua/torch/init.lua"];
    
    luaopen_libnn(L);
    [self require:@"/framework/lua/nn/init.lua"];
    
    luaopen_libimage(L);
    [self require:@"/framework/lua/image/init.lua"];
    
    
    
    // Make helpers available to Lua
    lua_pushcfunction(L, lua_getAppPath);
    lua_setglobal(L, "getAppPath");

    // Lua code that contains the neural network classifier
    [self require:@"/main.lua"];
    
    /* do the call (1 argument, 1 result)
    if (lua_pcall(L, 0, 0, 0) != 0)
        NSLog(@"error running function `f': %s", lua_tostring(L, -1));
    */
    
    // done
    return;
}


- (int) performClassification:(NSMutableArray *)binaryImage
                         rows:(int)rows
                         cols:(int)cols
                         type:(NSString *)type {
    
    /* push functions and arguments to be used in call */
    if ([type isEqualToString:@"digit"]) {
        lua_getglobal(L, "classify");
    } else if ([type isEqualToString:@"sign"]) {
        lua_getglobal(L, "classifySign");
    }
    
    lua_newtable(L);

    for(int i = 0;i < [binaryImage count]; i++) {
        lua_pushinteger(L, [[binaryImage objectAtIndex:i] intValue]);
        lua_rawseti(L,-2,i + 1);
    }
    
    lua_newtable(L);
    lua_pushinteger(L, rows);
    lua_rawseti(L, -2, 1);
    lua_pushinteger(L, cols);
    lua_rawseti(L, -2, 2);
    
    
    /* do the call (1 argument, 1 result) */
    if (lua_pcall(L, 2, 1, 0) != 0)
        NSLog(@"error running function `f': %s", lua_tostring(L, -1));
    
    /* retrieve result */
    if (!lua_isnumber(L, -1))
        NSLog(@"function `f' must return a number");
    
    int ret = lua_tonumber(L, -1);
    lua_pop(L, 1);  /* pop returned value */
    
    return ret;
}

@end
